import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/screens/breath_gym_home_screen.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/breath_gym_sound.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

const _minL = 0.45, _midL = 0.68, _maxL = 1.0;

/// Виконання GUIDED-вправи: коло, метроном, вібрація.
/// Повертає через Navigator.pop `true`, якщо вправу пройдено до кінця.
class BreathGymGuidedScreen extends StatefulWidget {
  final Exercise exercise;
  final ExerciseSettings settings;
  const BreathGymGuidedScreen({super.key, required this.exercise, required this.settings});

  @override
  State<BreathGymGuidedScreen> createState() => _BreathGymGuidedScreenState();
}

class _BreathGymGuidedScreenState extends State<BreathGymGuidedScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final List<BreathStep> _steps = buildTimeline(widget.exercise, widget.settings);
  late final BreathEngine _engine = BreathEngine(_steps);
  final _sound = BreathGymSound();
  late final Ticker _ticker;
  Timer? _beatTimer, _countTimer;

  /// Відлік 3-2-1 перед стартом; null — відлік не йде.
  int? _count = 3;

  // Попередньо пораховані для кожного кроку: рівень кола на початку,
  // ціль вдиху, «короткий вдих» Стрельникової, номер у серії.
  late final List<double> _startLevel, _inhaleTarget;
  late final List<bool> _sniff;
  late final List<String> _countLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _precompute();
    _engine
      ..onPhaseStart = _sound.phaseStarted
      ..onBeat = _sound.beat
      ..onFinished = (_) {
        _beatTimer?.cancel();
        if (mounted) setState(() {});
      };
    _ticker = createTicker((_) => _engine.tick())..start();
    _sound.ensureReady().whenComplete(() {
      if (mounted) _startCountdown();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _ticker.dispose();
    _beatTimer?.cancel();
    _countTimer?.cancel();
    _engine.dispose();
    _sound.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (_count != null) {
      _countTimer?.cancel();
      setState(() => _count = null);
    }
    if (_engine.status == EngineStatus.running) {
      _engine.pause();
      _beatTimer?.cancel();
    }
  }

  void _precompute() {
    final n = _steps.length;
    _startLevel = List.filled(n, _minL);
    _inhaleTarget = List.filled(n, _maxL);
    _sniff = List.filled(n, false);
    _countLabel = List.filled(n, '');
    var level = n > 0 && _steps.first.type != PhaseType.inhale ? _maxL : _minL;
    final strelnikova = widget.exercise.block == 2;
    final inhalesPerSeries = _steps.where((s) => s.series == 1 && s.type == PhaseType.inhale).length;
    var inhaleNo = 0;
    for (var i = 0; i < n; i++) {
      final s = _steps[i];
      final next = i + 1 < n ? _steps[i + 1] : null;
      _startLevel[i] = level;
      if (s.type == PhaseType.inhale) {
        _sniff[i] = next == null || next.type == PhaseType.inhale || next.isSeriesRest;
        _inhaleTarget[i] = next != null && next.swell ? _midL : _maxL;
      }
      level = switch (s.type) {
        PhaseType.inhale => _sniff[i] ? _midL : _inhaleTarget[i],
        PhaseType.exhale => _minL,
        PhaseType.rest => _midL,
        PhaseType.hold || PhaseType.action => level,
      };
      if (s.isSeriesRest) {
        inhaleNo = 0;
      } else if (strelnikova) {
        if (s.type == PhaseType.inhale) inhaleNo++;
        _countLabel[i] = BgStrings.inhaleOf(inhaleNo, inhalesPerSeries);
      } else {
        _countLabel[i] = BgStrings.repeatOf(s.repeat, s.repeatsTotal);
      }
    }
  }

  void _startCountdown() {
    _countTimer?.cancel();
    setState(() => _count = 3);
    _sound.countdown(false);
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final c = (_count ?? 1) - 1;
      if (c <= 0) {
        t.cancel();
        setState(() => _count = null);
        _engine.start();
        _schedule();
      } else {
        setState(() => _count = c);
        _sound.countdown(c == 1);
      }
    });
  }

  /// Таймер на точний момент наступної долі; кадри [Ticker] лише
  /// перемальовують коло.
  void _schedule() {
    _beatTimer?.cancel();
    if (_engine.status != EngineStatus.running) return;
    final us = max(0, _engine.usUntilNextEvent) + 300;
    _beatTimer = Timer(Duration(microseconds: us), () {
      _engine.tick();
      _schedule();
    });
  }

  void _togglePause() {
    if (_engine.status == EngineStatus.ready) {
      _startCountdown();
      return;
    }
    _engine.togglePause();
    _schedule();
  }

  void _skip() {
    _engine.skip();
    _schedule();
  }

  Future<void> _confirmStop() async {
    final wasRunning = _engine.status == EngineStatus.running;
    if (wasRunning) _engine.pause();
    _countTimer?.cancel();
    if (_count != null) setState(() => _count = null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(BgStrings.stopTitle),
        content: const Text(BgStrings.stopBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(BgStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(BgStrings.stop)),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      _engine.stop();
      Navigator.pop(context, false);
    } else {
      setState(() {}); // лишається на паузі — «Продовжити»
    }
  }

  Color _color(BreathGymPalette p, PhaseType t) => switch (t) {
        PhaseType.inhale => p.inhale,
        PhaseType.exhale => p.exhale,
        PhaseType.hold => p.hold,
        PhaseType.action => p.action,
        PhaseType.rest => p.rest,
      };

  static double _ease(double t) => Curves.easeInOut.transform(t.clamp(0.0, 1.0));

  double _scale(BreathStep s) {
    final p = _engine.stepProgress;
    final start = _startLevel[s.index];
    switch (s.type) {
      case PhaseType.inhale:
        if (_sniff[s.index]) {
          return p < 0.4 ? start + (_maxL - start) * _ease(p / 0.4) : _maxL + (_midL - _maxL) * _ease((p - 0.4) / 0.6);
        }
        return start + (_inhaleTarget[s.index] - start) * _ease(p);
      case PhaseType.exhale:
        if (s.swell) {
          return p < 0.5 ? start + (_maxL - start) * _ease(p / 0.5) : _maxL + (_minL - _maxL) * _ease((p - 0.5) / 0.5);
        }
        return start + (_minL - start) * _ease(p);
      case PhaseType.rest:
        return start + (_midL - start) * _ease(p);
      case PhaseType.hold:
        return start;
      case PhaseType.action:
        final beatFrac = (p * s.beats) % 1.0;
        return start * (1 + 0.14 * pow(1 - beatFrac, 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _engine.status == EngineStatus.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.exercise.title)),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _engine,
            builder: (context, _) =>
                _engine.status == EngineStatus.finished ? _finishedView(context) : _runView(context),
          ),
        ),
      ),
    );
  }

  Widget _runView(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BreathGymPalette.of(context);
    final step = _engine.current;
    final waiting = step == null; // відлік або очікування старту
    final first = _steps.isNotEmpty ? _steps.first : null;
    final shown = step ?? first;
    final color = waiting ? palette.rest : _color(palette, step.type);
    final paused = _engine.status == EngineStatus.paused || (waiting && _count == null);

    final label = waiting ? BgStrings.getReady : BgStrings.phase(step.type);
    final hint = shown?.hint ?? '';
    final inCircle = waiting
        ? (_count?.toString() ?? '')
        : step.beats > 0
            ? '${_engine.beat + 1}'
            : '${(_engine.remainingInStepUs / 1e6).ceil()}';
    final remainingSec = ((_engine.totalUs - _engine.elapsedUs) / 1e6).ceil();

    return LayoutBuilder(builder: (context, box) {
      final diameter = min(box.maxWidth - 48, box.maxHeight * 0.42).clamp(140.0, 340.0);
      final scale = waiting ? _minL : _scale(step);
      final semantic = waiting
          ? '$label ${_count ?? ''}'
          : '$label. $hint. ${step.beats > 0 ? BgStrings.beatOf(_engine.beat + 1, step.beats) : ''}';
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              if (shown != null && shown.seriesTotal > 1)
                Text(BgStrings.seriesOf(shown.series, shown.seriesTotal), style: theme.textTheme.titleSmall),
              const Spacer(),
              if (shown != null && !waiting && _countLabel[shown.index].isNotEmpty)
                Text(_countLabel[shown.index], style: theme.textTheme.titleSmall),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Semantics(
              label: BgStrings.remaining(remainingSec),
              child: LinearProgressIndicator(value: _engine.progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(BgStrings.remaining(remainingSec), style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Center(
              child: Semantics(
                label: semantic,
                liveRegion: true,
                excludeSemantics: true,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: diameter,
                    height: diameter,
                    child: Center(
                      child: Container(
                        width: diameter * scale,
                        height: diameter * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: paused ? 0.5 : 1),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4)],
                        ),
                        alignment: Alignment.center,
                        child: Text(inCircle,
                            style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: palette.onPhase)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2, color: color)),
                    ),
                  ),
                  if (hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                      child: Text(hint, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                    ),
                  if (!waiting && step.beats > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(BgStrings.beatOf(_engine.beat + 1, step.beats), style: theme.textTheme.titleMedium),
                    ),
                  if (paused)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(BgStrings.pausedHint, style: theme.textTheme.bodyMedium),
                    ),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                child: _ControlButton(
                  icon: paused ? Icons.play_arrow : Icons.pause,
                  label: paused ? BgStrings.resume : BgStrings.pause,
                  onPressed: _count != null ? null : _togglePause,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _ControlButton(icon: Icons.stop, label: BgStrings.stop, onPressed: _confirmStop)),
              const SizedBox(width: 8),
              Expanded(
                child: _ControlButton(
                    icon: Icons.skip_next, label: BgStrings.skip, onPressed: waiting ? null : _skip),
              ),
            ]),
          ),
        ],
      );
    });
  }

  Widget _finishedView(BuildContext context) {
    final theme = Theme.of(context);
    final sec = (_engine.elapsedUs / 1e6).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(_engine.completed ? BgStrings.finished : BgStrings.stopped,
              style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(BgStrings.duration(sec), style: theme.textTheme.titleMedium),
          const SizedBox(height: 24),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                  context,
                  breathGymRoute(
                      (_) => BreathGymGuidedScreen(exercise: widget.exercise, settings: widget.settings))),
              icon: const Icon(Icons.replay),
              label: const Text(BgStrings.again),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _engine.completed),
              icon: const Icon(Icons.done),
              label: const Text(BgStrings.done),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  const _ControlButton({required this.icon, required this.label, required this.onPressed, this.filled = false});

  @override
  Widget build(BuildContext context) {
    const size = Size.fromHeight(56);
    const padding = EdgeInsets.symmetric(horizontal: 4);
    final child = Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon), Text(label, maxLines: 1)]);
    return filled
        ? FilledButton(
            style: FilledButton.styleFrom(minimumSize: size, padding: padding), onPressed: onPressed, child: child)
        : OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: size, padding: padding), onPressed: onPressed, child: child);
  }
}
