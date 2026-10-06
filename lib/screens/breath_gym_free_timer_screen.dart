import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/breath_gym_sound.dart';
import 'package:hunting_signals/services/breath_gym_storage.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

/// FREE_TIMER: інструкція, зворотний відлік, «Готово».
/// Повертає `true`, якщо вправу завершено.
class BreathGymFreeTimerScreen extends StatefulWidget {
  final Exercise exercise;
  const BreathGymFreeTimerScreen({super.key, required this.exercise});

  @override
  State<BreathGymFreeTimerScreen> createState() => _BreathGymFreeTimerScreenState();
}

class _BreathGymFreeTimerScreenState extends State<BreathGymFreeTimerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _timer = FreeTimerSession(widget.exercise.totalSeconds);
  final _sound = BreathGymSound();
  late final Ticker _ticker;
  final _openedAt = DateTime.now();
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _sound.ensureReady();
    _timer.onTimeUp = _sound.timeUp;
    _timer.addListener(_logWhenDone);
    _ticker = createTicker((_) => _timer.tick())..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _ticker.dispose();
    _timer.dispose();
    _sound.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _timer.pause();
  }

  void _logWhenDone() {
    if (_timer.status != TimerStatus.done || _logged) return;
    _logged = true;
    BreathGymStorage.addSession(BreathSessionLog(
        widget.exercise.id, _openedAt, (_timer.elapsedUs / 1e6).round(), true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _timer,
          builder: (context, _) {
            final status = _timer.status;
            final done = status == TimerStatus.done;
            final running = status == TimerStatus.running;
            final color = BreathGymPalette.of(context).exhale;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(e.description, style: theme.textTheme.bodyLarge),
                if (e.needsItem.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.backpack_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${BgStrings.needs}: ${e.needsItem}')),
                    ]),
                  ),
                if (e.warning.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.warning)),
                    ]),
                  ),
                const SizedBox(height: 32),
                Center(
                  child: Semantics(
                    label: done ? BgStrings.finishedEarly : BgStrings.remaining(_timer.remainingSeconds),
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(fit: StackFit.expand, children: [
                        CircularProgressIndicator(
                          value: 1 - _timer.progress,
                          strokeWidth: 12,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.2),
                        ),
                        Center(
                          child: done
                              ? Icon(Icons.check_circle_outline, size: 96, color: color)
                              : Text(BgStrings.clock(_timer.remainingSeconds),
                                  style: const TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [FontFeature.tabularFigures()])),
                        ),
                      ]),
                    ),
                  ),
                ),
                if (done)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_timer.timeUp ? BgStrings.timeUp : BgStrings.finishedEarly,
                        textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  ),
                const SizedBox(height: 32),
                if (!done)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: _timer.toggle,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(
                        running
                            ? BgStrings.pause
                            : status == TimerStatus.paused
                                ? BgStrings.resume
                                : BgStrings.start,
                        style: const TextStyle(fontSize: 18)),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: done
                      ? () => Navigator.pop(context, true)
                      : status == TimerStatus.ready
                          ? null
                          : _timer.finish,
                  icon: const Icon(Icons.done),
                  label: const Text(BgStrings.done, style: TextStyle(fontSize: 18)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
