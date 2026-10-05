import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/models/pokit_models.dart';
import 'package:hunting_signals/services/access_service.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/pokit_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

// Тренажер «Покіт: розкладка здобичі» — паритет із сайтом
// (site/js/views/trainer-pokit.js): випадковий улов, викладання ряду тапами,
// перевірка за pokitRank і групуванням, журнал у pokit_sessions.

const _ok = Color(0xFF2E7D32);
const _bad = Color(0xFFC62828);
const _brown = Color(0xFF5D4037);
const _hintKey = 'pokit_hint_hidden';

Color _percentColor(int p) => p == 100 ? _ok : p >= 50 ? const Color(0xFFEF6C00) : _bad;

/// Іконка виду: власне зображення або Material-іконка.
Widget pokitBadge(PokitSpecies sp, double size) {
  final fallback = Icon(pokitIconData(sp.icon), size: size * 0.8, color: _brown);
  final url = sp.imageUrl;
  if (url == null) return SizedBox(width: size, height: size, child: Center(child: fallback));
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.contain, errorWidget: (_, __, ___) => fallback),
  );
}

// ── Фішка в «Навчальних тренажерах» ─────────────────────────────────────────
class PokitTrainerTab extends StatelessWidget {
  const PokitTrainerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Text('Після полювання здобич викладають у ряд у визначеному порядку. Викладіть «улов» так, як це робиться за традицією.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: ListTile(
          leading: Container(
            width: 44, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(color: _brown.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.pets, color: _brown),
          ),
          title: const Text('Почати тренування', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Випадковий улов — викладіть ряд тапами', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.play_arrow_rounded, color: HuntingTheme.primaryColor),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PokitGameScreen())),
        ),
      ),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: ListTile(
          leading: const Icon(Icons.history, color: HuntingTheme.primaryColor),
          title: const Text('Мої результати', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Останні 50 спроб', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PokitResultsScreen())),
        ),
      ),
    ]);
  }
}

// ── Гра ─────────────────────────────────────────────────────────────────────
class PokitGameScreen extends StatefulWidget {
  const PokitGameScreen({super.key});

  @override
  State<PokitGameScreen> createState() => _PokitGameScreenState();
}

class _PokitGameScreenState extends State<PokitGameScreen> {
  bool _loading = true, _showHint = false, _saving = false, _saved = false, _stopQueue = false;
  String? _error;
  int _need = 2;
  List<PokitSpecies> _species = [];
  Map<String, HuntingSignal> _signals = {};
  PokitConfig _cfg = const PokitConfig();
  List<PokitRoundItem> _round = [];
  List<PokitSpecies> _pool = [], _row = [];
  PokitCheck? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stopQueue = true;
    AudioService().stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        PokitService.getSpecies(),
        PokitService.getConfig(),
        HuntingDataService.getAllSignals(),
        SharedPreferences.getInstance(),
      ]);
      _species = (results[0] as List<PokitSpecies>).where((s) => !s.hidden && s.name.trim().isNotEmpty).toList();
      _cfg = results[1] as PokitConfig;
      _signals = {for (final s in results[2] as List<HuntingSignal>) s.id: s};
      _showHint = (results[3] as SharedPreferences).getBool(_hintKey) != true;
      _need = _cfg.minSpecies < 1 ? 1 : _cfg.minSpecies;
      if (_species.length >= _need) _newRound();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _newRound() {
    _stopQueue = true;
    AudioService().stop();
    _round = generatePokitRound(_species, _cfg);
    _pool = pokitShuffle([for (final r in _round) for (var i = 0; i < r.count; i++) r.species]);
    _row = [];
    _result = null;
    _saved = false;
  }

  void _place(int i) => setState(() => _row.add(_pool.removeAt(i)));
  void _undo() { if (_row.isNotEmpty) setState(() => _pool.add(_row.removeLast())); }

  Future<void> _hideHint() async {
    setState(() => _showHint = false);
    (await SharedPreferences.getInstance()).setBool(_hintKey, true);
  }

  Future<void> _save() async {
    final res = _result;
    if (res == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PokitService.saveSession(_round, _row, res);
      _saved = true;
      messenger.showSnackBar(const SnackBar(content: Text('Результат збережено'), backgroundColor: _ok));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не вдалося зберегти: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _saving = false);
  }

  /// Сигнали вшанування по черзі: наступний — коли попередній дограв.
  Future<void> _playHonour(List<String> urls) async {
    final audio = AudioService();
    _stopQueue = false;
    for (final url in urls) {
      if (_stopQueue || !mounted) return;
      final done = Completer<void>();
      void listener() { if (audio.currentSignalId != url.trim() && !done.isCompleted) done.complete(); }
      try {
        await audio.play(url);
        audio.addListener(listener);
        await done.future;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка відтворення: $e')));
        return;
      } finally {
        audio.removeListener(listener);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Покіт: розкладка здобичі')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Помилка завантаження: $_error')))
              : _species.length < _need
                  ? _emptyCatalog()
                  : SafeArea(child: _result == null ? _playView() : _resultView()),
    );
  }

  Widget _emptyCatalog() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.pets, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 10),
            const Text('Адміністратор ще не наповнив довідник видів', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Для раунду потрібно щонайменше $_need види (зараз — ${_species.length}).', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ]),
        ),
      );

  Widget _card(PokitSpecies sp, {VoidCallback? onTap, PokitMark? mark, bool small = false}) {
    final w = small ? 64.0 : 76.0;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: mark == null ? const Color(0xFFDDDDDD) : (mark.ok ? _ok : _bad), width: mark == null ? 1 : 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: w,
          height: small ? 76 : 90,
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                pokitBadge(sp, small ? 30 : 38),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(sp.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.1)),
                ),
              ]),
            ),
            if (mark != null)
              Positioned(top: 2, right: 5, child: Text(mark.ok ? '✓' : '✗', style: TextStyle(fontWeight: FontWeight.bold, color: mark.ok ? _ok : _bad))),
          ]),
        ),
      ),
    );
  }

  Widget _strip(List<Widget> children, double minHeight) => Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _brown.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _brown.withValues(alpha: .35)),
        ),
        child: Wrap(spacing: 6, runSpacing: 6, children: children),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      );

  Widget _playView() {
    final total = _row.length + _pool.length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_showHint)
        Card(
          color: const Color(0xFFFFF8E1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Викладіть здобич у ряд у правильному порядку покоту. Однакові види мають стояти поряд.'),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _hideHint, child: const Text('Зрозуміло, більше не показувати'))),
            ]),
          ),
        ),
      Card(
        child: ListTile(
          title: const Text('Улов цього раунду', style: TextStyle(fontSize: 12)),
          subtitle: Text(_round.map((r) => '${r.count}× ${r.species.name}').join(', '), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
      ),
      _section('Покіт (${_row.length} з $total)'),
      Text('Початок ряду — ліворуч. Остання покладена тварина повертається в пул дотиком або кнопкою.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      const SizedBox(height: 6),
      _strip([
        for (var i = 0; i < _row.length; i++) _card(_row[i], small: true, onTap: i == _row.length - 1 ? _undo : null),
        for (var i = 0; i < _pool.length; i++)
          Container(width: 64, height: 76, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBBBBB)))),
      ], 92),
      _section('Здобич — торкніться, щоб покласти в ряд'),
      _strip(
        _pool.isEmpty
            ? [const Padding(padding: EdgeInsets.all(8), child: Text('Усю здобич викладено'))]
            : [for (var i = 0; i < _pool.length; i++) _card(_pool[i], onTap: () => _place(i))],
        106,
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton.icon(onPressed: _row.isEmpty ? null : _undo, icon: const Icon(Icons.undo), label: const Text('Прибрати останню')),
        TextButton.icon(onPressed: () => setState(_newRound), icon: const Icon(Icons.casino), label: const Text('Новий раунд')),
        if (_pool.isEmpty)
          ElevatedButton.icon(
            onPressed: () => setState(() => _result = checkPokitRow(_row, _round, _cfg.groupingRequired)),
            icon: const Icon(Icons.fact_check), label: const Text('Перевірити')),
      ]),
    ]);
  }

  Widget _resultView() {
    final res = _result!;
    final right = pokitCorrectOrder(_round);
    final honour = <String>[
      for (final sp in {for (final s in right) s.id: s}.values)
        if (sp.signalId != null && (_signals[sp.signalId]?.audioUrl?.isNotEmpty ?? false)) _signals[sp.signalId]!.audioUrl!,
    ];
    final reasons = [
      if (res.marks.any((m) => !m.rankOk)) 'порушено порядок покоту',
      if (res.marks.any((m) => !m.groupOk)) 'однакові види мають лежати поряд',
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${res.percent}%', textAlign: TextAlign.center, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _percentColor(res.percent))),
      Text('${res.correct} з ${res.total} тварин на правильному місці', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 15)),
      const SizedBox(height: 4),
      Text(reasons.isEmpty ? 'Покіт викладено правильно!' : reasons.join('; '),
          textAlign: TextAlign.center, style: TextStyle(color: reasons.isEmpty ? _ok : _bad, fontWeight: reasons.isEmpty ? FontWeight.w600 : FontWeight.normal)),
      _section('Ваш ряд'),
      _strip([for (var i = 0; i < _row.length; i++) _card(_row[i], small: true, mark: res.marks[i])], 84),
      _section('Правильний ряд'),
      _strip([for (final sp in right) _card(sp, small: true)], 84),
      if (honour.isNotEmpty && res.percent == 100)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton.icon(onPressed: () => _playHonour(honour), icon: const Icon(Icons.campaign), label: const Text('Сигнали вшанування здобичі')),
        ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ElevatedButton.icon(onPressed: _saving || _saved ? null : _save, icon: const Icon(Icons.save), label: Text(_saved ? 'Збережено' : 'Зберегти результат')),
        TextButton.icon(onPressed: () => setState(_newRound), icon: const Icon(Icons.casino), label: const Text('Новий раунд')),
        TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.home), label: const Text('На головну')),
      ]),
    ]);
  }
}

// ── Мої результати ──────────────────────────────────────────────────────────
class PokitResultsScreen extends StatefulWidget {
  const PokitResultsScreen({super.key});

  @override
  State<PokitResultsScreen> createState() => _PokitResultsScreenState();
}

class _PokitResultsScreenState extends State<PokitResultsScreen> {
  late Future<List<PokitSession>> _future = PokitService.getMySessions();
  // Видаляти записи правила дозволяють лише адміністратору
  final bool _admin = AccessService.isAdminUser;

  Future<void> _delete(List<String> ids, String what) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити?'),
        content: Text('Видалити $what? Цю дію не можна скасувати.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Видалити')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PokitService.deleteSessions(ids);
      messenger.showSnackBar(const SnackBar(content: Text('Видалено')));
      setState(() => _future = PokitService.getMySessions());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не вдалося видалити: $e'), backgroundColor: Colors.red));
    }
  }

  String _date(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мої результати: покіт')),
      body: FutureBuilder<List<PokitSession>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Помилка завантаження: ${snap.error}'));
          final all = snap.data ?? [];
          if (all.isEmpty) return const Center(child: Text('Ще немає збережених спроб'));
          return ListView(padding: const EdgeInsets.all(12), children: [
            if (_admin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _delete(all.map((s) => s.docId).toList(), 'усі свої результати (${all.length})'),
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  label: const Text('Видалити всі мої результати', style: TextStyle(color: Colors.red)),
                ),
              ),
            for (final s in all.take(50))
              Card(
                child: ListTile(
                  leading: SizedBox(
                    width: 48,
                    child: Center(child: Text('${s.percent}%', style: TextStyle(fontWeight: FontWeight.bold, color: _percentColor(s.percent)))),
                  ),
                  title: Text(s.roundText, style: const TextStyle(fontSize: 14)),
                  subtitle: Text([_date(s.createdAt), '${s.correct}/${s.total}'].where((x) => x.isNotEmpty).join(' · ')),
                  trailing: _admin
                      ? IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Видалити', onPressed: () => _delete([s.docId], 'цей результат'))
                      : null,
                ),
              ),
          ]);
        },
      ),
    );
  }
}
