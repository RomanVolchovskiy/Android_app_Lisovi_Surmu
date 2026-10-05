import 'package:flutter/material.dart';

import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/models/pokit_models.dart';
import 'package:hunting_signals/screens/pokit_screen.dart' show pokitBadge;
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/media_storage_service.dart';
import 'package:hunting_signals/services/pokit_service.dart';

// Адмін-панель → «Покіт: розкладка здобичі» — паритет із сайтом
// (site/js/views/admin-pokit.js): налаштування раунду й довідник видів з
// pokitRank — порядком у правильному покоті, який задає викладач.

int _byRank(PokitSpecies a, PokitSpecies b) {
  final c = a.pokitRank.compareTo(b.pokitRank);
  return c != 0 ? c : a.name.compareTo(b.name);
}

String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

class AdminPokitScreen extends StatefulWidget {
  const AdminPokitScreen({super.key});

  @override
  State<AdminPokitScreen> createState() => _AdminPokitScreenState();
}

class _AdminPokitScreenState extends State<AdminPokitScreen> {
  List<PokitSpecies> _items = [];
  PokitConfig _cfg = const PokitConfig();
  bool _loading = true, _byRankMode = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([PokitService.getSpecies(), PokitService.getConfig()]);
      _items = r[0] as List<PokitSpecies>;
      _cfg = r[1] as PokitConfig;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String t, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), backgroundColor: error ? Colors.red : null));

  Future<void> _open(PokitSpecies? sp) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PokitSpeciesForm(existing: sp, all: _items)));
    if (saved == true) _load();
  }

  Future<void> _delete(PokitSpecies sp) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити вид?'),
        content: Text('Видалити «${sp.name}»? Старі результати студентів залишаться.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Видалити')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await PokitService.deleteSpecies(sp.id);
      _snack('Видалено');
      _load();
    } catch (e) {
      _snack('Помилка: $e', error: true);
    }
  }

  Future<void> _toggleHidden(PokitSpecies sp, bool hidden) async {
    try {
      await PokitService.setHidden(sp.id, hidden);
      _load();
    } catch (e) {
      _snack('Помилка: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(_items)..sort(_byRankMode ? _byRank : (a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Scaffold(
      appBar: AppBar(title: const Text('Покіт: розкладка здобичі')),
      floatingActionButton: FloatingActionButton(onPressed: () => _open(null), tooltip: 'Новий вид', child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Помилка завантаження: $_error'))
              : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
                  _ConfigCard(cfg: _cfg, onSaved: (c) => setState(() => _cfg = c)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Row(children: [
                      Expanded(child: Text('Види дичини (${_items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      ChoiceChip(label: const Text('За порядком'), selected: _byRankMode, onSelected: (_) => setState(() => _byRankMode = true)),
                      const SizedBox(width: 6),
                      ChoiceChip(label: const Text('За списком'), selected: !_byRankMode, onSelected: (_) => setState(() => _byRankMode = false)),
                    ]),
                  ),
                  if (_items.isEmpty)
                    const Padding(padding: EdgeInsets.all(24), child: Text('Довідник порожній — додайте щонайменше 4 види кнопкою «+»', textAlign: TextAlign.center)),
                  for (final sp in sorted)
                    Opacity(
                      opacity: sp.hidden ? 0.55 : 1,
                      child: Card(
                        child: ListTile(
                          leading: pokitBadge(sp, 36),
                          title: Text(sp.name),
                          subtitle: Text('Ранг у покоті: ${_fmt(sp.pokitRank)}${sp.hidden ? ' · прихований' : ''}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Tooltip(message: 'Прихований', child: Switch(value: sp.hidden, onChanged: (v) => _toggleHidden(sp, v))),
                            IconButton(icon: const Icon(Icons.edit), tooltip: 'Редагувати', onPressed: () => _open(sp)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Видалити', onPressed: () => _delete(sp)),
                          ]),
                        ),
                      ),
                    ),
                ]),
    );
  }
}

// ── Налаштування раунду ─────────────────────────────────────────────────────
class _ConfigCard extends StatefulWidget {
  final PokitConfig cfg;
  final ValueChanged<PokitConfig> onSaved;
  const _ConfigCard({required this.cfg, required this.onSaved});

  @override
  State<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<_ConfigCard> {
  late final _minS = TextEditingController(text: '${widget.cfg.minSpecies}');
  late final _maxS = TextEditingController(text: '${widget.cfg.maxSpecies}');
  late final _minC = TextEditingController(text: '${widget.cfg.minCountPerSpecies}');
  late final _maxC = TextEditingController(text: '${widget.cfg.maxCountPerSpecies}');
  late bool _grouping = widget.cfg.groupingRequired;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_minS, _maxS, _minC, _maxC]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String label, TextEditingController c) => Expanded(
        child: TextField(controller: c, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)),
      );

  Future<void> _save() async {
    final v = [_minS, _maxS, _minC, _maxC].map((c) => int.tryParse(c.text.trim())).toList();
    final messenger = ScaffoldMessenger.of(context);
    if (v.any((x) => x == null || x < 1)) {
      messenger.showSnackBar(const SnackBar(content: Text('Усі значення — цілі числа від 1'), backgroundColor: Colors.red));
      return;
    }
    if (v[1]! < v[0]! || v[3]! < v[2]!) {
      messenger.showSnackBar(const SnackBar(content: Text('«Макс» має бути не менше за «мін»'), backgroundColor: Colors.red));
      return;
    }
    final cfg = PokitConfig(minSpecies: v[0]!, maxSpecies: v[1]!, minCountPerSpecies: v[2]!, maxCountPerSpecies: v[3]!, groupingRequired: _grouping);
    setState(() => _saving = true);
    try {
      await PokitService.saveConfig(cfg);
      widget.onSaved(cfg);
      messenger.showSnackBar(const SnackBar(content: Text('Налаштування збережено')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cfg;
    return Card(
      child: ExpansionTile(
        title: const Text('Налаштування раунду', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('видів ${c.minSpecies}–${c.maxSpecies}, особин ${c.minCountPerSpecies}–${c.maxCountPerSpecies}${c.groupingRequired ? ', групування обов’язкове' : ''}',
            style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Row(children: [_field('Видів у раунді: від', _minS), const SizedBox(width: 8), _field('до', _maxS)]),
          const SizedBox(height: 10),
          Row(children: [_field('Особин виду: від', _minC), const SizedBox(width: 8), _field('до', _maxC)]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Групування однакових видів обов’язкове'),
            value: _grouping,
            onChanged: (v) => setState(() => _grouping = v),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Зберегти')),
          ),
        ],
      ),
    );
  }
}

// ── Форма виду ──────────────────────────────────────────────────────────────
class PokitSpeciesForm extends StatefulWidget {
  final PokitSpecies? existing;
  final List<PokitSpecies> all;
  const PokitSpeciesForm({super.key, this.existing, required this.all});

  @override
  State<PokitSpeciesForm> createState() => _PokitSpeciesFormState();
}

class _PokitSpeciesFormState extends State<PokitSpeciesForm> {
  late final PokitSpecies? _e = widget.existing;
  late final String _id = _e?.id ?? 'ps_${DateTime.now().millisecondsSinceEpoch}';
  late final _name = TextEditingController(text: _e?.name ?? '');
  late final _rank = TextEditingController(
      text: _fmt(_e?.pokitRank ?? (widget.all.isEmpty ? 10 : widget.all.map((s) => s.pokitRank).reduce((a, b) => a > b ? a : b) + 10)));
  late String _icon = _e?.icon ?? 'pets';
  late String? _imageUrl = _e?.imageUrl;
  late String? _signalId = _e?.signalId;
  late bool _hidden = _e?.hidden ?? false;
  List<HuntingSignal> _signals = [];
  bool _saving = false, _uploading = false;

  @override
  void initState() {
    super.initState();
    HuntingDataService.getAllSignals().then((s) { if (mounted) setState(() => _signals = s); });
  }

  @override
  void dispose() {
    _name.dispose();
    _rank.dispose();
    super.dispose();
  }

  double? get _rankValue => double.tryParse(_rank.text.trim().replaceAll(',', '.'));

  PokitSpecies _current() => PokitSpecies(
        id: _id,
        name: _name.text.trim(),
        icon: _icon,
        imageUrl: _imageUrl,
        pokitRank: _rankValue ?? 0,
        hidden: _hidden,
        sortOrder: _e?.sortOrder ?? widget.all.length,
        signalId: _signalId,
      );

  Future<void> _upload() async {
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final urls = await MediaStorageService.pickAndUpload(folder: 'pokitImage', allowedExtensions: MediaStorageService.imageExtensions);
      if (urls.isNotEmpty) {
        setState(() => _imageUrl = urls.first);
        messenger.showSnackBar(const SnackBar(content: Text('Зображення завантажено')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Помилка завантаження: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Введіть назву виду'), backgroundColor: Colors.red));
      return;
    }
    if (_rankValue == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Ранг у покоті — число'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await PokitService.saveSpecies(_current(), isNew: _e == null);
      messenger.showSnackBar(const SnackBar(content: Text('Вид збережено')));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Помилка збереження: $e'), backgroundColor: Colors.red));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _current();
    // Результуючий порядок покоту з урахуванням ще не збереженого рангу
    final order = [...widget.all.where((s) => s.id != me.id), me].where((s) => !s.hidden).toList()..sort(_byRank);
    final iconItems = {
      ...{for (final e in pokitIcons.entries) e.key: e.value.$2},
      if (!pokitIcons.containsKey(_icon)) _icon: 'Інша: $_icon (у застосунку — лапа)',
    };
    return Scaffold(
      appBar: AppBar(title: Text(_e == null ? 'Новий вид дичини' : 'Редагування виду')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Назва *', hintText: 'Напр. Кабан', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
          controller: _rank,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(
            labelText: 'Ранг у покоті *',
            helperText: 'Менше число — ближче до початку ряду покоту. Однаковий ранг — види рівнозначні.',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Порядок покоту (видимі види):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        for (var i = 0; i < order.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text('${i + 1}. ${order[i].id == me.id ? (me.name.isEmpty ? '(цей вид)' : me.name) : order[i].name} — ${_fmt(order[i].pokitRank)}',
                style: TextStyle(fontWeight: order[i].id == me.id ? FontWeight.bold : FontWeight.normal)),
          ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _icon,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Іконка', border: OutlineInputBorder()),
          items: [
            for (final e in iconItems.entries)
              DropdownMenuItem(value: e.key, child: Row(children: [Icon(pokitIconData(e.key), size: 20), const SizedBox(width: 8), Flexible(child: Text(e.value, overflow: TextOverflow.ellipsis))])),
          ],
          onChanged: (v) { if (v != null) setState(() => _icon = v); },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 56, height: 56, alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDDDDDD))),
            child: pokitBadge(me, 44),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image),
            label: Text(_imageUrl == null ? 'Завантажити зображення' : 'Замінити'),
          ),
          if (_imageUrl != null)
            TextButton(onPressed: () => setState(() => _imageUrl = null), child: const Text('Прибрати', style: TextStyle(color: Colors.red))),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey(_signals.length), // перебудувати, коли завантажаться сигнали
          initialValue: _signals.any((s) => s.id == _signalId) ? _signalId : null,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Сигнал вшанування (необов’язково)', helperText: 'Звучить після правильно викладеного покоту', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('— без сигналу —')),
            for (final s in _signals) DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _signalId = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Прихований (не з’являється в раундах)'),
          value: _hidden,
          onChanged: (v) => setState(() => _hidden = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_e == null ? 'Додати вид' : 'Зберегти зміни', style: const TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }
}
