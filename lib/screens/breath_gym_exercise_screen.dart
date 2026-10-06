import 'package:flutter/material.dart';

import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/screens/breath_gym_guided_screen.dart';
import 'package:hunting_signals/screens/breath_gym_home_screen.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';

/// Картка вправи: опис, джерело, попередження, налаштування, «Почати».
class BreathGymExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  const BreathGymExerciseScreen({super.key, required this.exercise});

  @override
  State<BreathGymExerciseScreen> createState() => _BreathGymExerciseScreenState();
}

class _BreathGymExerciseScreenState extends State<BreathGymExerciseScreen> {
  late ExerciseSettings _s = widget.exercise.defaults;

  Exercise get _e => widget.exercise;

  void _start() {
    switch (_e.mode) {
      case ExerciseMode.guided:
        Navigator.push(context, breathGymRoute((_) => BreathGymGuidedScreen(exercise: _e, settings: _s)));
      case ExerciseMode.stopwatch || ExerciseMode.freeTimer:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(BgStrings.notYet)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_e.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(avatar: Icon(breathGymModeIcon(_e.mode), size: 18), label: Text(BgStrings.mode(_e.mode))),
            Chip(avatar: const Icon(Icons.schedule, size: 18), label: Text(BgStrings.approx(estimateSeconds(_e, _s)))),
            Chip(label: Text('${BgStrings.romans[_e.block - 1]}. ${breathGymBlocks[_e.block]}')),
          ]),
          const SizedBox(height: 12),
          Text(_e.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('${BgStrings.source}: ${_e.source}', style: theme.textTheme.bodySmall),
          if (_e.needsItem.isNotEmpty)
            _InfoBox(icon: Icons.backpack_outlined, title: BgStrings.needs, text: _e.needsItem, color: scheme.secondaryContainer),
          if (_e.warning.isNotEmpty)
            _InfoBox(icon: Icons.warning_amber_rounded, title: BgStrings.warning, text: _e.warning, color: scheme.errorContainer),
          if (_e.benchmark.isNotEmpty)
            _InfoBox(icon: Icons.emoji_events_outlined, title: '', text: _e.benchmark, color: scheme.surfaceContainerHighest),
          if (_e.tips.isNotEmpty)
            _InfoBox(
                icon: Icons.lightbulb_outline,
                title: BgStrings.tips,
                text: _e.tips.map((t) => '• $t').join('\n'),
                color: scheme.surfaceContainerHighest),
          if (_e.mode == ExerciseMode.guided) ..._settings(theme),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text(BgStrings.start, style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  List<Widget> _settings(ThemeData theme) {
    final rows = <Widget>[];
    if (_e.bpmAdjustable) {
      rows.add(Row(children: [
        const SizedBox(width: 90, child: Text(BgStrings.tempo)),
        Expanded(
          child: Slider(
            value: _s.bpm.toDouble(),
            min: _e.bpmMin.toDouble(),
            max: _e.bpmMax.toDouble(),
            divisions: _e.bpmMax - _e.bpmMin,
            label: BgStrings.bpm(_s.bpm),
            semanticFormatterCallback: (v) => BgStrings.bpm(v.round()),
            onChanged: (v) => setState(() => _s = _s.copyWith(bpm: v.round())),
          ),
        ),
        SizedBox(width: 72, child: Text(BgStrings.bpm(_s.bpm), textAlign: TextAlign.end)),
      ]));
    }
    if (_e.seriesAdjustable) {
      rows.add(_Stepper(
        label: BgStrings.series,
        value: _s.series,
        min: _e.seriesMin,
        max: _e.seriesMax,
        onChanged: (v) => setState(() => _s = _s.copyWith(series: v)),
      ));
    }
    if (_e.repeatsAdjustable) {
      rows.add(_Stepper(
        label: BgStrings.repeats,
        value: _s.repeats ?? _e.repeats,
        min: 1,
        max: 20,
        onChanged: (v) => setState(() => _s = _s.copyWith(repeats: v)),
      ));
    }
    if (_e.hasSyllable) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          const SizedBox(width: 90, child: Text(BgStrings.syllable)),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ту', label: Text(BgStrings.syllableTu)),
                ButtonSegment(value: 'ху', label: Text(BgStrings.syllableHu)),
              ],
              selected: {_s.syllable},
              onSelectionChanged: (v) => setState(() => _s = _s.copyWith(syllable: v.first)),
            ),
          ),
        ]),
      ));
    }
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      Text(BgStrings.settings, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      ...rows,
    ];
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  const _InfoBox({required this.icon, required this.title, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              if (title.isNotEmpty) TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: text),
            ])),
          ),
        ]),
      );
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 90, child: Text(label)),
        IconButton(
          tooltip: '$label: менше',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 36,
          child: Text('$value',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          tooltip: '$label: більше',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ]);
}
