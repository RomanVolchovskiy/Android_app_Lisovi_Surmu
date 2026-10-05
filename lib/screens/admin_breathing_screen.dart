import 'package:flutter/material.dart';

import 'package:hunting_signals/models/breathing_models.dart';
import 'package:hunting_signals/services/breathing_service.dart';

// Адмін-панель → «Дихальні вправи» — паритет із сайтом
// (site/js/views/admin-breathing.js): список, приховування, форма з
// редактором блоків (cycle — фази з секундами, endurance — ціль видиху).

class AdminBreathingScreen extends StatefulWidget {
  const AdminBreathingScreen({super.key});

  @override
  State<AdminBreathingScreen> createState() => _AdminBreathingScreenState();
}

class _AdminBreathingScreenState extends State<AdminBreathingScreen> {
  List<BreathingExercise> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _items = await BreathingService.getExercises();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String text, {bool error = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null));

  Future<void> _open(BreathingExercise? ex) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => BreathingExerciseForm(existing: ex, nextSortOrder: _items.length),
    ));
    if (saved == true) _load();
  }

  Future<void> _delete(BreathingExercise ex) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити вправу?'),
        content: Text('Видалити «${ex.title}»? Історія виконань студентів залишиться.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Видалити')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await BreathingService.deleteExercise(ex.id);
      _snack('Видалено');
      _load();
    } catch (e) {
      _snack('Помилка: $e', error: true);
    }
  }

  Future<void> _toggleHidden(BreathingExercise ex, bool hidden) async {
    try {
      await BreathingService.setHidden(ex.id, hidden);
      setState(() => ex.hidden = hidden);
    } catch (e) {
      _snack('Помилка: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Дихальні вправи')),
      floatingActionButton: FloatingActionButton(onPressed: () => _open(null), tooltip: 'Нова вправа', child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Помилка завантаження: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Вправ ще немає — натисніть «+»'))
                  : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
                      for (final ex in _items)
                        Opacity(
                          opacity: ex.hidden ? 0.6 : 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.air),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(ex.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                                  if (ex.hidden) const Chip(label: Text('прихована'), visualDensity: VisualDensity.compact),
                                ]),
                                const SizedBox(height: 4),
                                Text([
                                  breathingCategories[ex.category],
                                  breathingLevels[ex.level],
                                  'блоків: ${ex.blocks.length}',
                                  '~${fmtDuration(ex.estimateSeconds)}',
                                ].whereType<String>().join(' · '), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                Row(children: [
                                  Switch(value: ex.hidden, onChanged: (v) => _toggleHidden(ex, v)),
                                  const Text('Прихована', style: TextStyle(fontSize: 13)),
                                  const Spacer(),
                                  IconButton(icon: const Icon(Icons.edit), tooltip: 'Редагувати', onPressed: () => _open(ex)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Видалити', onPressed: () => _delete(ex)),
                                ]),
                              ]),
                            ),
                          ),
                        ),
                    ]),
    );
  }
}

// ── Форма вправи ────────────────────────────────────────────────────────────
class BreathingExerciseForm extends StatefulWidget {
  final BreathingExercise? existing;
  final int nextSortOrder;
  const BreathingExerciseForm({super.key, this.existing, required this.nextSortOrder});

  @override
  State<BreathingExerciseForm> createState() => _BreathingExerciseFormState();
}

class _BreathingExerciseFormState extends State<BreathingExerciseForm> {
  late final BreathingExercise _ex = widget.existing?.copy() ??
      BreathingExercise(id: 'breath_${DateTime.now().millisecondsSinceEpoch}', sortOrder: widget.nextSortOrder, blocks: [BreathingBlock.cycle()]);
  // Стабільні ключі для блоків і фаз — поля не «стрибають» при перестановці
  final _keys = Expando<Key>();
  Key _key(Object o) => _keys[o] ??= UniqueKey();
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  String? _validate() {
    if (_ex.title.trim().isEmpty) return 'Введіть назву вправи';
    if (_ex.blocks.isEmpty) return 'Додайте хоча б один блок';
    for (var i = 0; i < _ex.blocks.length; i++) {
      final b = _ex.blocks[i], n = 'Блок ${i + 1}: ';
      if (b.repeats < 1) return '$nкількість повторів — щонайменше 1';
      if (b.isEndurance) {
        final p = b.phases.first;
        if (p.targetMin <= 0 || p.targetMax < p.targetMin) return '$nціль має бути додатною, «до» ≥ «від»';
      } else if (b.phases.isEmpty || b.phases.any((p) => p.seconds <= 0)) {
        return '$nкожна фаза має тривати більше 0 с';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BreathingService.saveExercise(_ex, isNew: _isNew);
      messenger.showSnackBar(const SnackBar(content: Text('Вправу збережено')));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Помилка збереження: $e'), backgroundColor: Colors.red));
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _text(String label, String value, ValueChanged<String> onChanged, {Key? key, int maxLines = 1, int? maxLength}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: key,
          initialValue: value,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, counterText: ''),
          onChanged: onChanged,
        ),
      );

  Widget _number(String label, double value, ValueChanged<double> onChanged, {Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: key,
          initialValue: fmtSec(value),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => onChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0)),
        ),
      );

  Widget _dropdown(String label, String value, Map<String, String> items, ValueChanged<String> onChanged, {Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          key: key,
          initialValue: items.containsKey(value) ? value : items.keys.first,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
          onChanged: (v) { if (v != null) setState(() => onChanged(v)); },
        ),
      );

  Widget _blockCard(int bi) {
    final b = _ex.blocks[bi];
    final k = _key(b);
    return Card(
      key: k,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFD4A017))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Блок ${bi + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.arrow_upward), tooltip: 'Вище',
                onPressed: bi == 0 ? null : () => setState(() { _ex.blocks.insert(bi - 1, _ex.blocks.removeAt(bi)); })),
            IconButton(icon: const Icon(Icons.arrow_downward), tooltip: 'Нижче',
                onPressed: bi == _ex.blocks.length - 1 ? null : () => setState(() { _ex.blocks.insert(bi + 1, _ex.blocks.removeAt(bi)); })),
            IconButton(icon: const Icon(Icons.delete), tooltip: 'Видалити блок',
                onPressed: _ex.blocks.length < 2 ? null : () => setState(() => _ex.blocks.removeAt(bi))),
          ]),
          _text('Назва блоку', b.label, (v) => b.label = v, key: ValueKey((k, 'label'))),
          _dropdown('Тип', b.kind, const {'cycle': 'Цикл (фази за таймером)', 'endurance': 'Витривалість видиху (студент засікає сам)'}, (v) {
            if (v == b.kind) return;
            final fresh = v == 'cycle' ? BreathingBlock.cycle() : BreathingBlock.endurance();
            _ex.blocks[bi] = fresh..label = b.label;
          }, key: ValueKey((k, 'kind'))),
          Row(children: [
            Expanded(child: _number('Повторів', b.repeats.toDouble(), (v) => b.repeats = v.round(), key: ValueKey((k, 'rep')))),
            const SizedBox(width: 8),
            Expanded(child: _number('Пауза між повторами, с', b.restBetweenReps, (v) => b.restBetweenReps = v, key: ValueKey((k, 'rest')))),
          ]),
          if (b.isEndurance) ..._endurancePhase(b) else ..._cyclePhases(b),
        ]),
      ),
    );
  }

  List<Widget> _endurancePhase(BreathingBlock b) {
    if (b.phases.isEmpty) b.phases.add(BreathingPhase(type: 'exhale'));
    final p = b.phases.first, k = _key(p);
    return [
      Row(children: [
        Expanded(child: _number('Ціль від, с', p.targetMin, (v) => p.targetMin = v, key: ValueKey((k, 'min')))),
        const SizedBox(width: 8),
        Expanded(child: _number('до, с', p.targetMax, (v) => p.targetMax = v, key: ValueKey((k, 'max')))),
      ]),
      Row(children: [
        Expanded(flex: 2, child: _text('Підпис фази', p.label, (v) => p.label = v, key: ValueKey((k, 'label')))),
        const SizedBox(width: 8),
        Expanded(child: _text('Звук', p.sound, (v) => p.sound = v, key: ValueKey((k, 'sound')), maxLength: 3)),
      ]),
    ];
  }

  List<Widget> _cyclePhases(BreathingBlock b) => [
        for (var pi = 0; pi < b.phases.length; pi++)
          Container(
            key: _key(b.phases[pi]),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE0E0E0)))),
            child: Builder(builder: (_) {
              final p = b.phases[pi], k = _key(p);
              return Column(children: [
                Row(children: [
                  Expanded(child: _dropdown('Фаза', p.type, breathingPhaseTypes, (v) => p.type = v, key: ValueKey((k, 'type')))),
                  const SizedBox(width: 8),
                  SizedBox(width: 96, child: _number('Секунд', p.seconds, (v) => p.seconds = v, key: ValueKey((k, 'sec')))),
                  IconButton(icon: const Icon(Icons.close), tooltip: 'Видалити фазу',
                      onPressed: b.phases.length < 2 ? null : () => setState(() => b.phases.removeAt(pi))),
                ]),
                Row(children: [
                  Expanded(flex: 2, child: _text('Підпис', p.label, (v) => p.label = v, key: ValueKey((k, 'label')))),
                  if (p.type == 'exhale') ...[
                    const SizedBox(width: 8),
                    Expanded(child: _text('Звук', p.sound, (v) => p.sound = v, key: ValueKey((k, 'sound')), maxLength: 3)),
                  ],
                ]),
              ]);
            }),
          ),
        TextButton.icon(
          onPressed: () => setState(() => b.phases.add(BreathingPhase(type: 'exhale', seconds: 4, label: 'Видих'))),
          icon: const Icon(Icons.add), label: const Text('Додати фазу'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Нова вправа' : 'Редагування вправи')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Основне', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        _text('Назва *', _ex.title, (v) => _ex.title = v),
        _text('Опис', _ex.description, (v) => _ex.description = v, maxLines: 3),
        _dropdown('Категорія', _ex.category, breathingCategories, (v) => _ex.category = v),
        _dropdown('Рівень', _ex.level, breathingLevels, (v) => _ex.level = v),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Прихована (студенти не бачать)'),
          value: _ex.hidden,
          onChanged: (v) => setState(() => _ex.hidden = v),
        ),
        const SizedBox(height: 8),
        const Text('Блоки', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        for (var i = 0; i < _ex.blocks.length; i++) _blockCard(i),
        Wrap(spacing: 8, children: [
          TextButton.icon(onPressed: () => setState(() => _ex.blocks.add(BreathingBlock.cycle())), icon: const Icon(Icons.add), label: const Text('Блок «Цикл»')),
          TextButton.icon(onPressed: () => setState(() => _ex.blocks.add(BreathingBlock.endurance())), icon: const Icon(Icons.add), label: const Text('Блок «Витривалість»')),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Орієнтовна тривалість: ~${fmtDuration(_ex.estimateSeconds)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_isNew ? 'Створити вправу' : 'Зберегти зміни', style: const TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }
}
