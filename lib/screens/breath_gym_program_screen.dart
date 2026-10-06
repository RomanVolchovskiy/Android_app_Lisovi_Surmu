import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/screens/breath_gym_free_timer_screen.dart';
import 'package:hunting_signals/screens/breath_gym_guided_screen.dart';
import 'package:hunting_signals/screens/breath_gym_home_screen.dart';
import 'package:hunting_signals/screens/breath_gym_stopwatch_screen.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/breath_gym_program.dart';

/// Програма: огляд → (пауза 5 с з «Далі» → вправа) × N → підсумок.
class BreathGymProgramScreen extends StatefulWidget {
  final Program program;
  const BreathGymProgramScreen({super.key, required this.program});

  @override
  State<BreathGymProgramScreen> createState() => _BreathGymProgramScreenState();
}

class _BreathGymProgramScreenState extends State<BreathGymProgramScreen> with WidgetsBindingObserver {
  static const _transitionSec = 5;

  late final _run = ProgramRun(widget.program);
  bool _started = false;
  Timer? _countdown;

  /// Секунд до автостарту; null — автостарт вимкнено (згорнули застосунок
  /// або чекаємо на підтвердження попередження).
  int? _left;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _countdown != null) {
      _countdown?.cancel();
      _countdown = null;
      setState(() => _left = null);
    }
  }

  void _start() {
    setState(() => _started = true);
    _beginTransition();
  }

  Future<void> _beginTransition() async {
    _countdown?.cancel();
    if (_run.finished) {
      setState(() => _left = null);
      return;
    }
    if (_run.needsStrelnikovaWarning) {
      setState(() => _left = null);
      await _showStrelnikovaWarning();
      if (!mounted) return;
      _run.markStrelnikovaWarned();
    }
    setState(() => _left = _transitionSec);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (_left ?? 1) - 1;
      if (left <= 0) {
        t.cancel();
        _countdown = null;
        _openCurrent();
      } else {
        setState(() => _left = left);
      }
    });
  }

  Future<void> _showStrelnikovaWarning() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(breathGymBlocks[2]!),
      content: const Text(strelnikovaWarning),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text(BgStrings.introOk))],
    ),
  );

  bool _opening = false;

  Future<void> _openCurrent() async {
    _countdown?.cancel();
    _countdown = null;
    final e = _run.current;
    if (e == null || _opening) return;
    _opening = true;
    setState(() => _left = null);
    final done = await Navigator.push<bool>(
      context,
      breathGymRoute(
        (_) => switch (e.mode) {
          ExerciseMode.guided => BreathGymGuidedScreen(exercise: e, settings: e.defaults, allowRepeat: false),
          ExerciseMode.stopwatch => BreathGymStopwatchScreen(exercise: e),
          ExerciseMode.freeTimer => BreathGymFreeTimerScreen(exercise: e),
        },
      ),
    );
    _opening = false;
    if (!mounted) return;
    _run.complete(done == true);
    _beginTransition();
  }

  void _skip() {
    _run.skip();
    _beginTransition();
  }

  Future<bool> _confirmEnd() async {
    _countdown?.cancel();
    _countdown = null;
    setState(() => _left = null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(BgStrings.endProgramTitle),
        content: const Text(BgStrings.endProgramBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(BgStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(BgStrings.endProgram)),
        ],
      ),
    );
    if (!mounted) return false;
    if (ok == true) {
      _run.abort();
      setState(() {});
    } else {
      _beginTransition(); // автостарт знову з 5 с
    }
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = _started && !_run.finished;
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.program.title)),
        body: SafeArea(
          child: !_started
              ? _overview(context)
              : _run.finished
              ? _summary(context)
              : _transition(context),
        ),
      ),
    );
  }

  Widget _overview(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.program;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                '${BgStrings.exercisesCount(_run.exercises.length)} · ${p.durationLabel} · '
                '${BgStrings.approx(estimateProgramSeconds(p, transitionSec: _transitionSec))}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _run.exercises.length; i++) _exerciseRow(context, i),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _run.exercises.isEmpty ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text(BgStrings.startProgram, style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _exerciseRow(BuildContext context, int i) {
    final e = _run.exercises[i];
    final status = _run.statuses[i];
    final (icon, label) = switch (status) {
      ProgramItemStatus.done => (Icons.check_circle, BgStrings.statusDone),
      ProgramItemStatus.stopped => (Icons.stop_circle_outlined, BgStrings.statusStopped),
      ProgramItemStatus.skipped => (Icons.skip_next, BgStrings.statusSkipped),
      ProgramItemStatus.pending => (breathGymModeIcon(e.mode), ''),
    };
    final current = _started && i == _run.index;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      selected: current,
      leading: Icon(icon),
      title: Text('${i + 1}. ${e.title}', style: TextStyle(fontWeight: current ? FontWeight.bold : FontWeight.w500)),
      subtitle: Text(
        [
          BgStrings.approx(estimateSeconds(e)),
          if (e.needsItem.isNotEmpty) '${BgStrings.needs}: ${e.needsItem}',
          if (label.isNotEmpty) label,
        ].join(' · '),
      ),
    );
  }

  Widget _transition(BuildContext context) {
    final theme = Theme.of(context);
    final e = _run.current!;
    final n = _run.exercises.length;
    return Column(
      children: [
        LinearProgressIndicator(value: _run.index / n),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(BgStrings.exerciseOf(_run.index + 1, n), style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(BgStrings.upNext, style: theme.textTheme.bodyMedium),
              Text(e.title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(avatar: Icon(breathGymModeIcon(e.mode), size: 18), label: Text(BgStrings.mode(e.mode))),
                  Chip(avatar: const Icon(Icons.schedule, size: 18), label: Text(BgStrings.approx(estimateSeconds(e)))),
                  if (e.needsItem.isNotEmpty)
                    Chip(avatar: const Icon(Icons.backpack_outlined, size: 18), label: Text(e.needsItem)),
                ],
              ),
              const SizedBox(height: 12),
              Text(e.description, style: theme.textTheme.bodyLarge),
              if (e.tips.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...e.tips.map((t) => Text('• $t', style: theme.textTheme.bodyMedium)),
              ],
              if (e.warning.isNotEmpty && e.block != 2) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e.warning)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (_left != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    BgStrings.autoStartIn(_left!),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _openCurrent,
                icon: const Icon(Icons.play_arrow),
                label: const Text(BgStrings.next, style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: _skip,
                      icon: const Icon(Icons.skip_next),
                      label: const Text(BgStrings.skipExercise),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: _confirmEnd,
                      icon: const Icon(Icons.close),
                      label: const Text(BgStrings.endProgram),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Icon(Icons.emoji_events_outlined, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(BgStrings.programDone, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                BgStrings.summary(
                  _run.count(ProgramItemStatus.done),
                  _run.count(ProgramItemStatus.stopped),
                  _run.count(ProgramItemStatus.skipped),
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _run.exercises.length; i++) _exerciseRow(context, i),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.done),
            label: const Text(BgStrings.done, style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
