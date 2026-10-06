import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/breath_gym_sound.dart';
import 'package:hunting_signals/services/breath_gym_storage.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

/// STOPWATCH: відлік, вдих 3 с, секундомір видиху, результат, рекорд,
/// 10 останніх спроб. Повертає `true`, якщо була хоч одна спроба.
class BreathGymStopwatchScreen extends StatefulWidget {
  final Exercise exercise;
  const BreathGymStopwatchScreen({super.key, required this.exercise});

  @override
  State<BreathGymStopwatchScreen> createState() => _BreathGymStopwatchScreenState();
}

class _BreathGymStopwatchScreenState extends State<BreathGymStopwatchScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _session = StopwatchSession();
  final _sound = BreathGymSound();
  late final Ticker _ticker;
  final _openedAt = DateTime.now();

  List<BreathAttempt> _attempts = [];
  double _record = 0;

  /// Рекорд до останньої спроби — щоб показати «Новий рекорд!».
  double _prevRecord = 0;
  int _attemptsThisRun = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _sound.ensureReady();
    _session.onCountdown = (left) => _sound.countdown(left == 1);
    _session.onPhase = _onPhase;
    _ticker = createTicker((_) => _session.tick())..start();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _ticker.dispose();
    _session.dispose();
    _sound.dispose();
    if (_attemptsThisRun > 0) {
      BreathGymStorage.addSession(BreathSessionLog(
          widget.exercise.id, _openedAt, DateTime.now().difference(_openedAt).inSeconds, true));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Спроба без нагляду не рахується: згорнули — скасовуємо.
    if (state != AppLifecycleState.resumed && _session.phase != StopwatchPhase.done) _session.cancel();
  }

  Future<void> _load() async {
    final list = await BreathGymStorage.attempts(widget.exercise.id);
    if (!mounted) return;
    setState(() {
      _attempts = list;
      _record = bestOf(list);
    });
  }

  void _onPhase(StopwatchPhase p) {
    switch (p) {
      case StopwatchPhase.inhale:
        _sound.cue(PhaseType.inhale);
      case StopwatchPhase.exhale:
        _sound.cue(PhaseType.exhale);
      case StopwatchPhase.done:
        _save(_session.result);
      case StopwatchPhase.ready || StopwatchPhase.countdown:
        break;
    }
  }

  Future<void> _save(double seconds) async {
    _attemptsThisRun++;
    _prevRecord = _record;
    final a = BreathAttempt(widget.exercise.id, seconds, DateTime.now());
    setState(() {
      _attempts = [a, ..._attempts];
      if (seconds > _record) _record = seconds;
    });
    await BreathGymStorage.addAttempt(a);
  }

  @override
  Widget build(BuildContext context) {
    final running = _session.phase != StopwatchPhase.ready && _session.phase != StopwatchPhase.done;
    return PopScope(
      canPop: !running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _session.cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exercise.title),
          leading: BackButton(onPressed: () => Navigator.maybePop(context, _attemptsThisRun > 0)),
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _session,
            builder: (context, _) => switch (_session.phase) {
              StopwatchPhase.ready => _idleView(context, null),
              StopwatchPhase.done => _idleView(context, _session.result),
              _ => _activeView(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _recordLine(ThemeData theme) => Row(children: [
        const Icon(Icons.emoji_events_outlined, size: 20),
        const SizedBox(width: 6),
        Text(_record > 0 ? '${BgStrings.record}: ${BgStrings.sec(_record)}' : BgStrings.noRecord,
            style: theme.textTheme.titleMedium),
      ]);

  /// Перед першою спробою або після результату.
  Widget _idleView(BuildContext context, double? result) {
    final theme = Theme.of(context);
    final e = widget.exercise;
    final isRecord = result != null && result >= _record && result > _prevRecord;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _recordLine(theme),
        if (e.benchmark.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.benchmark, style: theme.textTheme.bodySmall)),
        const SizedBox(height: 16),
        if (result == null)
          Text(e.description, style: theme.textTheme.bodyLarge)
        else
          Semantics(
            liveRegion: true,
            child: Column(children: [
              Text(BgStrings.result, style: theme.textTheme.titleMedium),
              Text(BgStrings.sec(result),
                  style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
              if (isRecord)
                Chip(
                  avatar: const Icon(Icons.emoji_events, size: 18),
                  label: Text(_prevRecord > 0 ? BgStrings.newRecord : BgStrings.firstResult),
                ),
            ]),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _session.start,
          icon: Icon(result == null ? Icons.play_arrow : Icons.replay),
          label: Text(result == null ? BgStrings.startAttempt : BgStrings.anotherAttempt, style: const TextStyle(fontSize: 18)),
        ),
        if (result != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.done),
            label: const Text(BgStrings.done),
          ),
        ],
        if (_attempts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(BgStrings.lastAttempts, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ..._attempts.take(10).map((a) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(a.seconds >= _record ? Icons.emoji_events : Icons.timer_outlined, size: 20),
                title: Text(BgStrings.sec(a.seconds), style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(BgStrings.dateTime(a.at)),
              )),
        ],
      ],
    );
  }

  /// Відлік, вдих, видих.
  Widget _activeView(BuildContext context) {
    final theme = Theme.of(context);
    final palette = BreathGymPalette.of(context);
    final phase = _session.phase;
    final (label, color) = switch (phase) {
      StopwatchPhase.countdown => (BgStrings.getReady, palette.rest),
      StopwatchPhase.inhale => (BgStrings.phase(PhaseType.inhale), palette.inhale),
      _ => (BgStrings.phase(PhaseType.exhale), palette.exhale),
    };
    final exhaling = phase == StopwatchPhase.exhale;
    final big = exhaling ? BgStrings.secNumber(_session.exhaleSeconds) : '${_session.secondsLeft}';
    final scale = switch (phase) {
      StopwatchPhase.inhale => 0.45 + 0.55 * Curves.easeInOut.transform(_session.inhaleProgress),
      StopwatchPhase.exhale => 1.0,
      _ => 0.45,
    };

    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: _recordLine(theme)),
      Expanded(
        child: Center(
          child: Semantics(
            label: '$label $big',
            liveRegion: !exhaling,
            excludeSemantics: true,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 260,
                height: 260,
                child: Center(
                  child: Container(
                    width: 260 * scale,
                    height: 260 * scale,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(big,
                            style: TextStyle(
                                fontSize: exhaling ? 64 : 56,
                                fontWeight: FontWeight.bold,
                                color: palette.onPhase,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(label, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2, color: color)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(
                  switch (phase) {
                    StopwatchPhase.countdown => BgStrings.inhaleSoon,
                    StopwatchPhase.inhale => BgStrings.inhaleDeep,
                    _ => BgStrings.exhaleEvenly,
                  },
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(96),
            backgroundColor: exhaling ? theme.colorScheme.error : null,
            foregroundColor: exhaling ? theme.colorScheme.onError : null,
          ),
          onPressed: _session.stop,
          icon: Icon(exhaling ? Icons.stop : Icons.close, size: 32),
          label: Text(exhaling ? BgStrings.stop : BgStrings.cancel, style: const TextStyle(fontSize: 24)),
        ),
      ),
    ]);
  }
}
