import 'package:flutter/foundation.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';

/// Крок розгорнутої вправи: одна фаза з абсолютним початком і тривалістю
/// в мікросекундах від старту сесії.
class BreathStep {
  final int index;
  final PhaseType type;

  /// Долі метронома; 0 — фаза в секундах (відпочинок між серіями).
  final int beats;
  final int startUs;
  final int durationUs;
  final String hint;
  final bool swell;
  final int series;
  final int seriesTotal;

  /// Номер проходу фаз у серії (наскрізно через усі групи) і їх кількість.
  final int repeat;
  final int repeatsTotal;

  /// Відпочинок між серіями (а не REST усередині проходу).
  final bool isSeriesRest;

  const BreathStep({
    required this.index,
    required this.type,
    required this.beats,
    required this.startUs,
    required this.durationUs,
    required this.hint,
    required this.swell,
    required this.series,
    required this.seriesTotal,
    required this.repeat,
    required this.repeatsTotal,
    required this.isSeriesRest,
  });

  int get endUs => startUs + durationUs;
}

/// Кількість проходів групи з урахуванням налаштувань і тривалості серії.
int _groupRepeats(Exercise ex, PhaseGroup g, ExerciseSettings s) {
  if (ex.isTimed) {
    final beats = g.beatsPerPass;
    if (beats == 0) return 1;
    final n = (ex.totalSeconds * s.bpm / 60 / beats).round();
    return n < 1 ? 1 : n;
  }
  if (ex.repeatsAdjustable && s.repeats != null) return s.repeats!;
  return g.repeats;
}

/// Розгортає GUIDED-вправу в послідовність кроків.
///
/// Початок кожного кроку рахується від загальної кількості долей і секунд
/// від старту, а не додаванням округлених тривалостей, — похибка не
/// накопичується.
List<BreathStep> buildTimeline(Exercise ex, ExerciseSettings settings) {
  if (ex.mode != ExerciseMode.guided) return const [];
  final s = settings.clampTo(ex);
  final beatUs = 60e6 / s.bpm;
  final seriesTotal = ex.seriesAdjustable ? s.series : ex.series;
  final reps = [for (final g in ex.groups) _groupRepeats(ex, g, s)];
  final repeatsTotal = reps.fold(0, (a, b) => a + b);

  final steps = <BreathStep>[];
  var beatsSoFar = 0;
  var secondsUs = 0;
  int now() => (beatsSoFar * beatUs).round() + secondsUs;

  void add(PhaseType type, {int beats = 0, int secUs = 0, String hint = '', bool swell = false,
      required int series, required int repeat, bool seriesRest = false}) {
    final start = now();
    beatsSoFar += beats;
    secondsUs += secUs;
    steps.add(BreathStep(
      index: steps.length,
      type: type,
      beats: beats,
      startUs: start,
      durationUs: now() - start,
      hint: hint,
      swell: swell,
      series: series,
      seriesTotal: seriesTotal,
      repeat: repeat,
      repeatsTotal: repeatsTotal,
      isSeriesRest: seriesRest,
    ));
  }

  for (var series = 1; series <= seriesTotal; series++) {
    if (series > 1 && ex.restBetweenSeriesSec > 0) {
      add(PhaseType.rest,
          secUs: (ex.restBetweenSeriesSec * 1e6).round(),
          hint: 'відпочинок перед серією $series',
          series: series,
          repeat: 0,
          seriesRest: true);
    }
    var repeat = 0;
    for (var gi = 0; gi < ex.groups.length; gi++) {
      for (var r = 0; r < reps[gi]; r++) {
        repeat++;
        for (final p in ex.groups[gi].phases) {
          final hint = ex.hasSyllable && p.type == PhaseType.action ? s.syllable : p.hint;
          add(p.type,
              beats: p.beats,
              secUs: p.isBeatBased ? 0 : (p.seconds * 1e6).round(),
              hint: hint,
              swell: p.swell,
              series: series,
              repeat: repeat);
        }
      }
    }
  }
  return steps;
}

/// Орієнтовна тривалість вправи, с.
int estimateSeconds(Exercise ex, [ExerciseSettings? settings]) {
  switch (ex.mode) {
    case ExerciseMode.guided:
      final t = buildTimeline(ex, settings ?? ex.defaults);
      return t.isEmpty ? 0 : (t.last.endUs / 1e6).round();
    case ExerciseMode.stopwatch:
      return 60; // кілька спроб з відліком і вдихом
    case ExerciseMode.freeTimer:
      return ex.totalSeconds;
  }
}

/// Монотонний час у мікросекундах. У тестах підміняється.
abstract class BreathClock {
  int get nowUs;
}

class MonotonicClock implements BreathClock {
  final _sw = Stopwatch()..start();
  @override
  int get nowUs => _sw.elapsedMicroseconds;
}

enum EngineStatus { ready, running, paused, finished }

/// Стан-машина виконання GUIDED-вправи, окрема від UI.
///
/// Позиція рахується лише з монотонного годинника, тому затримки кадрів
/// і таймерів не зсувають ритм: [tick] можна викликати як завгодно часто,
/// він лише визначає, де ми зараз, і повідомляє про нові фази й долі.
class BreathEngine extends ChangeNotifier {
  BreathEngine(this.steps, {BreathClock? clock}) : _clock = clock ?? MonotonicClock();

  final List<BreathStep> steps;
  final BreathClock _clock;

  /// Початок фази (разом із першою долею).
  void Function(BreathStep step)? onPhaseStart;

  /// Кожна доля фази, [beat] від 0. Для першої долі — одразу після [onPhaseStart].
  void Function(BreathStep step, int beat)? onBeat;
  void Function(bool completed)? onFinished;

  EngineStatus _status = EngineStatus.ready;
  EngineStatus get status => _status;

  /// Вправу пройдено до кінця (а не зупинено кнопкою «Стоп»).
  bool completed = false;

  int _baseUs = 0;
  int _resumedAtUs = 0;
  int _stepIndex = -1;
  int _beat = -1;

  int get stepIndex => _stepIndex;
  int get beat => _beat;
  BreathStep? get current => _stepIndex >= 0 && _stepIndex < steps.length ? steps[_stepIndex] : null;

  int get totalUs => steps.isEmpty ? 0 : steps.last.endUs;

  int get elapsedUs {
    final e = _status == EngineStatus.running ? _baseUs + _clock.nowUs - _resumedAtUs : _baseUs;
    return e > totalUs ? totalUs : e;
  }

  /// Частка поточної фази 0..1.
  double get stepProgress {
    final s = current;
    if (s == null || s.durationUs == 0) return 0;
    return ((elapsedUs - s.startUs) / s.durationUs).clamp(0.0, 1.0);
  }

  double get progress => totalUs == 0 ? 0 : elapsedUs / totalUs;

  int get remainingInStepUs {
    final s = current;
    return s == null ? 0 : (s.endUs - elapsedUs).clamp(0, s.durationUs);
  }

  /// Час до наступної долі чи межі фази — для точного таймера звуку.
  int get usUntilNextEvent {
    final s = current;
    if (s == null || _status != EngineStatus.running) return 0;
    final e = elapsedUs;
    if (s.beats > 0) {
      final next = s.startUs + ((_beat + 1) * s.durationUs / s.beats).round();
      return (next < s.endUs ? next : s.endUs) - e;
    }
    return s.endUs - e;
  }

  void start() {
    if (_status != EngineStatus.ready) return;
    if (steps.isEmpty) {
      _finish(true);
      return;
    }
    _baseUs = 0;
    _resumedAtUs = _clock.nowUs;
    _status = EngineStatus.running;
    _update();
  }

  void pause() {
    if (_status != EngineStatus.running) return;
    _baseUs = elapsedUs;
    _status = EngineStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (_status != EngineStatus.paused) return;
    _resumedAtUs = _clock.nowUs;
    _status = EngineStatus.running;
    _update();
  }

  void togglePause() => _status == EngineStatus.running ? pause() : resume();

  /// Стоп: вправа вважається незавершеною.
  void stop() {
    if (_status == EngineStatus.finished) return;
    _baseUs = elapsedUs;
    _finish(false);
  }

  /// Перехід на початок наступної фази (працює й на паузі).
  void skip() {
    if (_status != EngineStatus.running && _status != EngineStatus.paused) return;
    final next = _stepIndex + 1;
    if (next >= steps.length) {
      _baseUs = totalUs;
      _finish(true);
      return;
    }
    _baseUs = steps[next].startUs;
    _resumedAtUs = _clock.nowUs;
    _update();
  }

  void tick() {
    if (_status == EngineStatus.running) _update();
  }

  void _update() {
    final e = elapsedUs;
    if (e >= totalUs) {
      _baseUs = totalUs;
      _finish(true);
      return;
    }
    var i = _stepIndex < 0 ? 0 : _stepIndex;
    while (i < steps.length - 1 && e >= steps[i].endUs) {
      i++;
    }
    final s = steps[i];
    final b = s.beats > 0 ? ((e - s.startUs) * s.beats ~/ s.durationUs).clamp(0, s.beats - 1) : -1;
    if (i != _stepIndex) {
      _stepIndex = i;
      _beat = b;
      onPhaseStart?.call(s);
      if (b >= 0) onBeat?.call(s, b);
    } else if (b != _beat) {
      _beat = b;
      onBeat?.call(s, b);
    }
    notifyListeners();
  }

  void _finish(bool done) {
    _status = EngineStatus.finished;
    completed = done;
    onFinished?.call(done);
    notifyListeners();
  }
}

enum StopwatchPhase { ready, countdown, inhale, exhale, done }

/// Спроба STOPWATCH: відлік → вдих → секундомір видиху → «Стоп».
class StopwatchSession extends ChangeNotifier {
  StopwatchSession({BreathClock? clock, this.countdownSec = 3, this.inhaleSec = 3})
      : _clock = clock ?? MonotonicClock();

  final BreathClock _clock;
  final int countdownSec;
  final int inhaleSec;

  /// Нова фаза спроби.
  void Function(StopwatchPhase phase)? onPhase;

  /// Секунда відліку: 3, 2, 1.
  void Function(int secondsLeft)? onCountdown;

  StopwatchPhase _phase = StopwatchPhase.ready;
  StopwatchPhase get phase => _phase;
  int _phaseStartUs = 0;
  int _lastCount = 0;

  /// Результат останньої спроби, с.
  double result = 0;

  int get _inPhaseUs => _clock.nowUs - _phaseStartUs;

  /// Скільки цілих секунд лишилось у відліку чи на вдиху (3, 2, 1).
  int get secondsLeft {
    final total = switch (_phase) {
      StopwatchPhase.countdown => countdownSec,
      StopwatchPhase.inhale => inhaleSec,
      _ => 0,
    };
    final left = total - _inPhaseUs / 1e6;
    return left <= 0 ? 0 : left.ceil();
  }

  /// Частка вдиху 0..1 (для кола).
  double get inhaleProgress =>
      _phase == StopwatchPhase.inhale ? (_inPhaseUs / (inhaleSec * 1e6)).clamp(0.0, 1.0) : 0;

  /// Поточний час видиху (або результат після «Стоп»), с.
  double get exhaleSeconds => switch (_phase) {
        StopwatchPhase.exhale => _inPhaseUs / 1e6,
        StopwatchPhase.done => result,
        _ => 0,
      };

  void start() {
    if (_phase != StopwatchPhase.ready && _phase != StopwatchPhase.done) return;
    result = 0;
    _enter(countdownSec > 0 ? StopwatchPhase.countdown : StopwatchPhase.inhale);
    if (_phase == StopwatchPhase.countdown) {
      _lastCount = countdownSec;
      onCountdown?.call(countdownSec);
    }
  }

  /// «Стоп» на видиху фіксує результат; раніше — скасовує спробу.
  void stop() {
    if (_phase == StopwatchPhase.exhale) {
      result = _inPhaseUs / 1e6;
      _enter(StopwatchPhase.done);
    } else if (_phase == StopwatchPhase.countdown || _phase == StopwatchPhase.inhale) {
      cancel();
    }
  }

  /// Скасування без результату (наприклад, застосунок згорнули).
  void cancel() {
    if (_phase == StopwatchPhase.ready) return;
    result = 0;
    _enter(StopwatchPhase.ready);
  }

  void tick() {
    switch (_phase) {
      case StopwatchPhase.countdown:
        if (_inPhaseUs >= countdownSec * 1000000) {
          _enter(StopwatchPhase.inhale, at: _phaseStartUs + countdownSec * 1000000);
          tick();
          return;
        }
        final left = secondsLeft;
        if (left != _lastCount) {
          _lastCount = left;
          onCountdown?.call(left);
        }
      case StopwatchPhase.inhale:
        if (_inPhaseUs >= inhaleSec * 1000000) {
          _enter(StopwatchPhase.exhale, at: _phaseStartUs + inhaleSec * 1000000);
          return;
        }
      case StopwatchPhase.ready || StopwatchPhase.exhale || StopwatchPhase.done:
        break;
    }
    notifyListeners();
  }

  /// [at] — точний момент межі фази, щоб запізнілий кадр не з'їдав час.
  void _enter(StopwatchPhase p, {int? at}) {
    _phase = p;
    _phaseStartUs = at ?? _clock.nowUs;
    onPhase?.call(p);
    notifyListeners();
  }
}

enum TimerStatus { ready, running, paused, done }

/// FREE_TIMER: зворотний відлік з паузою; «Готово» — у будь-який момент.
class FreeTimerSession extends ChangeNotifier {
  FreeTimerSession(this.totalSeconds, {BreathClock? clock}) : _clock = clock ?? MonotonicClock();

  final int totalSeconds;
  final BreathClock _clock;
  void Function()? onTimeUp;

  TimerStatus _status = TimerStatus.ready;
  TimerStatus get status => _status;
  int _baseUs = 0, _resumedAtUs = 0;

  /// Час вичерпано (а не натиснуто «Готово» раніше).
  bool timeUp = false;

  int get totalUs => totalSeconds * 1000000;
  int get elapsedUs {
    final e = _status == TimerStatus.running ? _baseUs + _clock.nowUs - _resumedAtUs : _baseUs;
    return e > totalUs ? totalUs : e;
  }

  int get remainingSeconds => ((totalUs - elapsedUs) / 1e6).ceil();
  double get progress => totalUs == 0 ? 1 : elapsedUs / totalUs;

  void start() {
    if (_status == TimerStatus.ready || _status == TimerStatus.paused) {
      _resumedAtUs = _clock.nowUs;
      _status = TimerStatus.running;
      notifyListeners();
    }
  }

  void pause() {
    if (_status != TimerStatus.running) return;
    _baseUs = elapsedUs;
    _status = TimerStatus.paused;
    notifyListeners();
  }

  void toggle() => _status == TimerStatus.running ? pause() : start();

  void finish() {
    if (_status == TimerStatus.done) return;
    _baseUs = elapsedUs;
    _status = TimerStatus.done;
    notifyListeners();
  }

  void tick() {
    if (_status != TimerStatus.running) return;
    if (elapsedUs >= totalUs) {
      _baseUs = totalUs;
      timeUp = true;
      _status = TimerStatus.done;
      onTimeUp?.call();
    }
    notifyListeners();
  }
}
