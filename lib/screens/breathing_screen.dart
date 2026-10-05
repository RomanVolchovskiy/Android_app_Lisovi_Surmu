import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hunting_signals/models/breathing_models.dart';
import 'package:hunting_signals/services/access_service.dart';
import 'package:hunting_signals/services/breathing_service.dart';
import 'package:hunting_signals/services/horn_synth.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

// Тренажер «Дихальна гімнастика» — паритет із сайтом
// (site/js/views/trainer-breathing.js): cycle-блоки ведуть фази самі,
// endurance-блоки — студент засікає видих; журнал у breathing_sessions.

const _base = Color(0xFF1C3A1C);
const _ok = Color(0xFF2E7D32);
const _warn = Color(0xFFEF6C00);
const _minScale = 0.45;

/// Нота сурми для сигналу зміни фази (індекс у HornSynth.frequencies).
const _phaseLane = {'inhale': 2, 'hold': 1, 'exhale': 0, 'pause': 1};

String _subtitle(BreathingExercise ex) => [
      breathingCategories[ex.category],
      breathingLevels[ex.level],
      '~${fmtDuration(ex.estimateSeconds)}',
    ].whereType<String>().join(' · ');

// ── Фішка в «Навчальних тренажерах» ─────────────────────────────────────────
class BreathingTrainerTab extends StatefulWidget {
  const BreathingTrainerTab({super.key});

  @override
  State<BreathingTrainerTab> createState() => _BreathingTrainerTabState();
}

class _BreathingTrainerTabState extends State<BreathingTrainerTab> {
  late Future<List<BreathingExercise>> _future;

  @override
  void initState() {
    super.initState();
    _future = BreathingService.getExercises();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BreathingExercise>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final visible = (snap.data ?? []).where((e) => !e.hidden).toList();
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = BreathingService.getExercises());
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text('Діафрагмальне дихання, рівномірний видих і витривалість — розминка перед грою на ріжку.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
              if (snap.hasError)
                _message(Icons.error_outline, 'Помилка завантаження', '${snap.error}')
              else if (visible.isEmpty)
                _message(Icons.air, 'Вправ ще немає', 'Адміністратор додає їх в адмін-панелі → «Дихальні вправи»')
              else
                for (final ex in visible)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: ListTile(
                      leading: Container(
                        width: 44, height: 44, alignment: Alignment.center,
                        decoration: BoxDecoration(color: HuntingTheme.primaryColor.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.air, color: HuntingTheme.primaryColor),
                      ),
                      title: Text(ex.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(_subtitle(ex), style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BreathingIntroScreen(exercise: ex))),
                    ),
                  ),
              Card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 5),
                child: ListTile(
                  leading: const Icon(Icons.history, color: HuntingTheme.primaryColor),
                  title: const Text('Мої результати', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Останні 50 виконаних вправ', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingResultsScreen())),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _message(IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ]),
      );
}

// ── Екран перед стартом ─────────────────────────────────────────────────────
class BreathingIntroScreen extends StatelessWidget {
  final BreathingExercise exercise;
  const BreathingIntroScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    return Scaffold(
      appBar: AppBar(title: Text(ex.title, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (ex.description.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(ex.description, style: const TextStyle(fontSize: 15, height: 1.4))),
        Text(_subtitle(ex), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 16),
        const Text('Блоки вправи', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        for (var i = 0; i < ex.blocks.length; i++)
          Card(child: ListTile(leading: Text('${i + 1})', style: const TextStyle(fontWeight: FontWeight.bold)), title: Text(ex.blocks[i].describe()))),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BreathingRunScreen(exercise: ex))),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Почати', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ]),
    );
  }
}

// ── Виконання вправи ────────────────────────────────────────────────────────
enum _Ctl { cycle, rest, enduranceReady, enduranceRun, enduranceDone, separator, result }

class BreathingRunScreen extends StatefulWidget {
  final BreathingExercise exercise;
  const BreathingRunScreen({super.key, required this.exercise});

  @override
  State<BreathingRunScreen> createState() => _BreathingRunScreenState();
}

class _BreathingRunScreenState extends State<BreathingRunScreen> {
  final _synth = HornSynth();
  final _startedAt = DateTime.now();
  final List<EnduranceResult> _results = [];
  late final List<BreathingBlock> _blocks = widget.exercise.blocks.where((b) => b.phases.isNotEmpty).toList();

  Timer? _timer;
  Completer<void>? _waiter;
  _Ctl _ctl = _Ctl.cycle;
  bool _paused = false, _finished = false, _skipBlock = false, _saving = false;
  int _completed = 0;

  String _blockLabel = '', _phaseLabel = '', _sub = '', _big = '';
  Color _phaseColor = _base, _ring = _base;
  double _scale = _minScale;

  @override
  void initState() {
    super.initState();
    _synth.ensureReady();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _finished = true;
    _release();
    _synth.dispose();
    super.dispose();
  }

  // ── Таймер і очікування ───────────────────────────────────────────────────
  /// Тікає кожні 100 мс до [dur] секунд (без паузи); завершується раніше,
  /// якщо викликати [_release] (пропуск, «Стоп», вихід).
  Future<void> _tickFor(double dur, void Function(double t) onTick) {
    final c = Completer<void>();
    _waiter = c;
    var elapsed = 0.0;
    var last = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final now = DateTime.now();
      if (!_paused) elapsed += now.difference(last).inMicroseconds / 1e6;
      last = now;
      if (!mounted || _finished) { t.cancel(); if (!c.isCompleted) c.complete(); return; }
      setState(() => onTick(elapsed));
      if (elapsed >= dur) { t.cancel(); if (!c.isCompleted) c.complete(); }
    });
    return c.future;
  }

  /// Чекає натискання кнопки на екрані [ctl].
  Future<void> _waitUser(_Ctl ctl) {
    final c = Completer<void>();
    _waiter = c;
    if (mounted) setState(() => _ctl = ctl);
    return c.future;
  }

  void _release() {
    _timer?.cancel();
    final c = _waiter;
    if (c != null && !c.isCompleted) c.complete();
  }

  void _feedback(String type) {
    _synth.play(_phaseLane[type] ?? 1, volume: 0.35);
    HapticFeedback.lightImpact();
  }

  // ── Сценарій ──────────────────────────────────────────────────────────────
  Future<void> _run() async {
    for (var bi = 0; bi < _blocks.length && !_finished; bi++) {
      _skipBlock = false;
      final b = _blocks[bi];
      final ok = b.isEndurance ? await _endurance(b, bi) : await _cycle(b, bi);
      if (_finished) return;
      if (ok) _completed++;
      if (bi < _blocks.length - 1) {
        final next = _blocks[bi + 1];
        setState(() {
          _phaseLabel = 'Блок ${bi + 1} завершено';
          _sub = 'Наступний: ${next.label.isEmpty ? next.describe() : next.label}';
        });
        await _waitUser(_Ctl.separator);
      }
    }
    if (_finished || !mounted) return;
    setState(() { _finished = true; _ctl = _Ctl.result; });
  }

  String _blockHeader(BreathingBlock b, int bi, int r, String fallback) =>
      'Блок ${bi + 1} з ${_blocks.length}: ${b.label.isEmpty ? fallback : b.label} · Повтор ${r + 1} з ${b.repeats}';

  Future<bool> _cycle(BreathingBlock b, int bi) async {
    for (var r = 0; r < b.repeats && !_skipBlock && !_finished; r++) {
      for (final p in b.phases) {
        if (_skipBlock || _finished) break;
        final dur = max(0.5, p.seconds);
        final from = _scale;
        final to = p.type == 'inhale' ? 1.0 : p.type == 'exhale' ? _minScale : from;
        setState(() {
          _ctl = _Ctl.cycle;
          _blockLabel = _blockHeader(b, bi, r, 'Цикл');
          _phaseLabel = p.label.isEmpty ? (breathingPhaseTypes[p.type] ?? '') : p.label;
          _phaseColor = _base;
          _sub = p.type == 'exhale' && p.sound.isNotEmpty ? 'на звук «${p.sound}-${p.sound}-${p.sound}»' : '';
          _ring = _base;
        });
        _feedback(p.type);
        await _tickFor(dur, (t) {
          _big = '${max(0, (dur - t).ceil())}';
          _scale = from + (to - from) * min(1.0, t / dur);
        });
      }
      if (!_skipBlock && !_finished && r < b.repeats - 1) await _rest(b.restBetweenReps, 'Далі: повтор ${r + 2} з ${b.repeats}');
    }
    return !_skipBlock;
  }

  Future<void> _rest(double seconds, String next) async {
    if (seconds <= 0 || _finished) return;
    setState(() {
      _ctl = _Ctl.rest;
      _phaseLabel = 'Відпочинок';
      _phaseColor = _base;
      _sub = next;
      _scale = _minScale;
      _ring = _base;
    });
    await _tickFor(seconds, (t) => _big = '${max(0, (seconds - t).ceil())}');
  }

  Future<bool> _endurance(BreathingBlock b, int bi) async {
    final p = b.phases.first;
    final lo = p.targetMin, hi = max(p.targetMin, p.targetMax);
    for (var r = 0; r < b.repeats && !_skipBlock && !_finished; r++) {
      setState(() {
        _blockLabel = _blockHeader(b, bi, r, 'Витривалість видиху');
        _phaseLabel = 'Глибокий вдих — і починайте';
        _phaseColor = _base;
        _sub = 'Ціль: ${fmtSec(lo)}–${fmtSec(hi)} с${p.sound.isNotEmpty ? ' · на звук «${p.sound}-${p.sound}-${p.sound}»' : ''}';
        _big = '0';
        _scale = 1;
        _ring = _base;
      });
      await _waitUser(_Ctl.enduranceReady);
      if (_skipBlock || _finished) break;
      _feedback('exhale');
      var achieved = 0.0;
      setState(() { _ctl = _Ctl.enduranceRun; _phaseLabel = p.label.isEmpty ? 'Рівномірний видих' : p.label; });
      await _tickFor(double.infinity, (t) {
        achieved = t;
        _big = t.toStringAsFixed(1);
        _ring = t < lo ? _base : t <= hi ? _ok : _warn;
        _scale = max(_minScale, 1 - (t / max(hi, 1)) * (1 - _minScale));
      });
      if (_finished) break;
      final sec = (achieved * 10).round() / 10;
      final inTarget = sec >= lo && sec <= hi;
      _results.add(EnduranceResult(b.label.isEmpty ? 'Витривалість видиху' : b.label, r, sec, inTarget));
      _feedback('hold');
      setState(() {
        _phaseLabel = inTarget ? '✓ У межах цілі' : sec < lo ? 'Коротше за ціль' : 'Довше за ціль';
        _phaseColor = inTarget ? _ok : _warn;
        _big = sec.toStringAsFixed(1);
        _sub = r < b.repeats - 1 ? '' : 'Останній повтор блоку';
      });
      await _waitUser(_Ctl.enduranceDone);
      if (!_finished && r < b.repeats - 1) await _rest(b.restBetweenReps, 'Далі: повтор ${r + 2} з ${b.repeats}');
    }
    return !_skipBlock;
  }

  void _skip() { _skipBlock = true; _release(); }

  Future<void> _confirmExit() async {
    final wasPaused = _paused;
    setState(() => _paused = true);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вийти з вправи?'),
        content: const Text('Прогрес цієї вправи не буде збережено.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Продовжити')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Вийти'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (yes == true) {
      _finished = true;
      _release();
      Navigator.pop(context);
    } else {
      setState(() => _paused = wasPaused);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BreathingService.saveSession(
        ex: widget.exercise,
        blocksCompleted: _completed,
        blocksTotal: _blocks.length,
        results: _results,
        totalSeconds: DateTime.now().difference(_startedAt).inSeconds,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Результат збережено'), backgroundColor: _ok));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не вдалося зберегти: $e'), backgroundColor: Colors.red));
    }
    if (mounted) Navigator.pop(context);
  }

  // ── Інтерфейс ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _ctl == _Ctl.result,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _confirmExit(); },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.exercise.title, overflow: TextOverflow.ellipsis)),
        body: SafeArea(child: _ctl == _Ctl.result ? _resultView() : _ctl == _Ctl.separator ? _separatorView() : _runView()),
      ),
    );
  }

  Widget _runView() {
    final size = min(MediaQuery.of(context).size.width * 0.72, MediaQuery.of(context).size.height * 0.42);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(_blockLabel, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
      const SizedBox(height: 6),
      Text(_phaseLabel, textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _phaseColor)),
      const SizedBox(height: 12),
      SizedBox(
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.linear,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(center: const Alignment(0, -0.2), colors: [const Color(0x59D4A017), _base.withValues(alpha: .13)]),
                border: Border.all(color: _ring, width: 6),
              ),
            ),
          ),
          Text(_big, style: TextStyle(fontSize: size * 0.28, fontWeight: FontWeight.bold, color: _base)),
        ]),
      ),
      const SizedBox(height: 12),
      Text(_sub, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 15)),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: _controls()),
    ]);
  }

  List<Widget> _controls() {
    Widget text(IconData i, String l, VoidCallback f) => TextButton.icon(onPressed: f, icon: Icon(i), label: Text(l, style: const TextStyle(fontSize: 16)));
    Widget big(IconData i, String l, VoidCallback f, Color c) => ElevatedButton.icon(
          onPressed: f, icon: Icon(i, size: 26), label: Text(l, style: const TextStyle(fontSize: 20)),
          style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)));
    switch (_ctl) {
      case _Ctl.cycle:
        return [
          text(_paused ? Icons.play_arrow : Icons.pause, _paused ? 'Продовжити' : 'Пауза', () => setState(() => _paused = !_paused)),
          text(Icons.skip_next, 'Пропустити блок', _skip),
          text(Icons.close, 'Вийти', _confirmExit),
        ];
      case _Ctl.rest:
        return [text(Icons.skip_next, 'Пропустити паузу', _release)];
      case _Ctl.enduranceReady:
        return [big(Icons.play_arrow, 'Почати видих', _release, _base), text(Icons.skip_next, 'Пропустити блок', _skip), text(Icons.close, 'Вийти', _confirmExit)];
      case _Ctl.enduranceRun:
        return [big(Icons.stop, 'Стоп', _release, Colors.red.shade700)];
      case _Ctl.enduranceDone:
        return [big(Icons.arrow_forward, 'Далі', _release, _base)];
      default:
        return [];
    }
  }

  Widget _separatorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, size: 72, color: _ok),
            const SizedBox(height: 8),
            Text(_phaseLabel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _release,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Продовжити', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
            ),
          ]),
        ),
      );

  Widget _resultView() {
    final total = DateTime.now().difference(_startedAt).inSeconds;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Icon(Icons.self_improvement, size: 72, color: _ok),
      const Text('Вправу завершено', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Виконано блоків: $_completed з ${_blocks.length} · ${fmtDuration(total)}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 15)),
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Витривалість видиху', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        for (final r in _results)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: r.inTarget ? _ok : _warn, width: 1.5)),
            child: ListTile(
              title: Text(r.blockLabel, style: const TextStyle(fontSize: 14)),
              subtitle: Text('Повтор ${r.repeatIndex + 1}'),
              trailing: Text('${r.achievedSeconds.toStringAsFixed(1)} с ${r.inTarget ? '✓' : '—'}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: r.inTarget ? _ok : _warn)),
            ),
          ),
      ],
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        ElevatedButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Зберегти й вийти')),
        TextButton.icon(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BreathingRunScreen(exercise: widget.exercise))),
          icon: const Icon(Icons.replay), label: const Text('Повторити')),
        TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.home), label: const Text('На головну')),
      ]),
    ]);
  }
}

// ── Мої результати ──────────────────────────────────────────────────────────
class BreathingResultsScreen extends StatefulWidget {
  const BreathingResultsScreen({super.key});

  @override
  State<BreathingResultsScreen> createState() => _BreathingResultsScreenState();
}

class _BreathingResultsScreenState extends State<BreathingResultsScreen> {
  late Future<List<BreathingSession>> _future = BreathingService.getMySessions();
  // Видаляти записи дозволено лише адміністратору (правила breathing_sessions)
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
      await BreathingService.deleteSessions(ids);
      messenger.showSnackBar(const SnackBar(content: Text('Видалено')));
      setState(() => _future = BreathingService.getMySessions());
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
      appBar: AppBar(title: const Text('Мої результати: дихання')),
      body: FutureBuilder<List<BreathingSession>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Помилка завантаження: ${snap.error}'));
          final all = snap.data ?? [];
          if (all.isEmpty) return const Center(child: Text('Ще немає виконаних вправ'));
          final rows = all.take(50).toList();
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
            for (final s in rows)
              Card(
                child: ListTile(
                  leading: Icon(s.blocksCompleted >= s.blocksTotal ? Icons.check_circle : Icons.timelapse, color: HuntingTheme.primaryColor),
                  title: Text(s.exerciseTitle),
                  subtitle: Text([
                    _date(s.createdAt),
                    'блоків ${s.blocksCompleted}/${s.blocksTotal}',
                    if (s.enduranceTotal > 0) 'видих у цілі ${s.enduranceInTarget}/${s.enduranceTotal}',
                  ].where((x) => x.isNotEmpty).join(' · ')),
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
