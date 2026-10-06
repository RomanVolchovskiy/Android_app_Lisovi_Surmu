import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/screens/breath_gym_exercise_screen.dart';
import 'package:hunting_signals/screens/breath_gym_program_screen.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

/// Маршрут екрана тренажера: тема тренажера (світла чи темна за системою)
/// діє тільки всередині нього.
Route<T> breathGymRoute<T>(WidgetBuilder builder) => MaterialPageRoute<T>(
      builder: (context) => Theme(
        data: HuntingTheme.breathGym(MediaQuery.platformBrightnessOf(context)),
        child: Builder(builder: builder),
      ),
    );

IconData breathGymModeIcon(ExerciseMode m) => switch (m) {
      ExerciseMode.guided => Icons.air,
      ExerciseMode.stopwatch => Icons.timer_outlined,
      ExerciseMode.freeTimer => Icons.hourglass_bottom,
    };

/// Фішка «Дихальний тренажер» у «Навчальних тренажерах»: вправи за блоками.
class BreathGymTab extends StatefulWidget {
  const BreathGymTab({super.key});

  @override
  State<BreathGymTab> createState() => _BreathGymTabState();
}

class _BreathGymTabState extends State<BreathGymTab> {
  static const _introKey = 'breath_gym_intro_seen';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  Future<void> _maybeShowIntro() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_introKey) == true || !mounted) return;
    await showBreathGymIntro(context);
    await prefs.setBool(_introKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final block in breathGymBlocks.entries) {
      final list = breathGymExercises.where((e) => e.block == block.key).toList();
      if (list.isEmpty) continue;
      children.add(_BlockHeader(number: block.key, title: block.value));
      children.addAll(list.map((e) => _ExerciseTile(exercise: e)));
    }
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text(BgStrings.programs, style: heading))),
              IconButton(
                tooltip: BgStrings.introTitle,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showBreathGymIntro(context),
              ),
            ],
          ),
        ),
        ...breathGymPrograms.map((p) => _ProgramCard(program: p)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Semantics(header: true, child: Text(BgStrings.exercises, style: heading)),
        ),
        ...children,
      ],
    );
  }
}

Future<void> showBreathGymIntro(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(BgStrings.introTitle),
        content: const Text(breathGymIntro),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(BgStrings.introOk))],
      ),
    );

class _BlockHeader extends StatelessWidget {
  final int number;
  final String title;
  const _BlockHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('${BgStrings.romans[number - 1]}. $title',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
        ),
      );
}

class _ProgramCard extends StatelessWidget {
  final Program program;
  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = program;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.playlist_play, color: scheme.onPrimaryContainer, size: 32),
        title: Text(p.title, style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
        subtitle: Text('${p.durationLabel} · ${BgStrings.exercisesCount(p.exerciseIds.length)}\n${p.description}',
            style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer)),
        isThreeLine: true,
        trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
        onTap: () => Navigator.push(context, breathGymRoute((_) => BreathGymProgramScreen(program: p))),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final meta = '${e.source} · ${BgStrings.approx(estimateSeconds(e))}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(breathGymModeIcon(e.mode), color: Theme.of(context).colorScheme.primary),
        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meta, style: const TextStyle(fontSize: 12)),
            if (e.needsItem.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.backpack_outlined, size: 14),
                  const SizedBox(width: 4),
                  Flexible(child: Text('${BgStrings.needs}: ${e.needsItem}', style: const TextStyle(fontSize: 12))),
                ]),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, breathGymRoute((_) => BreathGymExerciseScreen(exercise: e))),
      ),
    );
  }
}
