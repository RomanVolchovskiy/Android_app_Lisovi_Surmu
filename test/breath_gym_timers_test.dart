import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/breath_gym_storage.dart';

class FakeClock implements BreathClock {
  int t = 0;
  @override
  int get nowUs => t;
  void advanceMs(num ms) => t += (ms * 1000).round();
}

void main() {
  group('секундомір', () {
    late FakeClock clock;
    late StopwatchSession s;
    late List<String> events;

    setUp(() {
      clock = FakeClock();
      s = StopwatchSession(clock: clock);
      events = [];
      s.onPhase = (p) => events.add(p.name);
      s.onCountdown = (n) => events.add('$n');
    });

    test('відлік 3-2-1 → вдих 3 с → видих → стоп', () {
      s.start();
      expect(s.phase, StopwatchPhase.countdown);
      for (var i = 0; i < 30; i++) {
        clock.advanceMs(100);
        s.tick();
      }
      expect(s.phase, StopwatchPhase.inhale);
      expect(events, ['countdown', '3', '2', '1', 'inhale']);
      expect(s.secondsLeft, 3);
      clock.advanceMs(1500);
      s.tick();
      expect(s.inhaleProgress, closeTo(0.5, 1e-9));
      clock.advanceMs(1500);
      s.tick();
      expect(s.phase, StopwatchPhase.exhale);
      clock.advanceMs(21400);
      expect(s.exhaleSeconds, closeTo(21.4, 1e-9));
      s.stop();
      expect(s.phase, StopwatchPhase.done);
      expect(s.result, closeTo(21.4, 1e-9));
      expect(events.last, 'done');
    });

    test('запізнілий кадр не з\'їдає час видиху', () {
      s.start();
      clock.advanceMs(6500); // один кадр через 3 с відліку + 3 с вдиху + 0,5 с
      s.tick();
      expect(s.phase, StopwatchPhase.exhale);
      expect(s.exhaleSeconds, closeTo(0.5, 1e-9));
    });

    test('стоп до видиху скасовує спробу без результату', () {
      s.start();
      clock.advanceMs(1000);
      s.tick();
      s.stop();
      expect(s.phase, StopwatchPhase.ready);
      expect(s.result, 0);
    });

    test('скасування під час видиху (застосунок згорнули)', () {
      s.start();
      clock.advanceMs(8000);
      s.tick();
      s.cancel();
      expect(s.phase, StopwatchPhase.ready);
      expect(s.result, 0);
    });

    test('нова спроба після результату', () {
      s.start();
      clock.advanceMs(7000);
      s.tick();
      s.stop();
      s.start();
      expect(s.phase, StopwatchPhase.countdown);
      expect(s.result, 0);
    });
  });

  group('таймер', () {
    test('відлік, пауза, кінець часу', () {
      final clock = FakeClock();
      final t = FreeTimerSession(120, clock: clock);
      var up = 0;
      t.onTimeUp = () => up++;
      t.start();
      clock.advanceMs(30000);
      t.tick();
      expect(t.remainingSeconds, 90);
      t.pause();
      clock.advanceMs(600000);
      t.tick();
      expect(t.remainingSeconds, 90);
      t.start();
      clock.advanceMs(90000);
      t.tick();
      expect(t.status, TimerStatus.done);
      expect(t.timeUp, isTrue);
      expect(up, 1);
      expect(t.remainingSeconds, 0);
    });

    test('«Готово» раніше часу', () {
      final clock = FakeClock();
      final t = FreeTimerSession(120, clock: clock)..start();
      clock.advanceMs(45000);
      t.finish();
      expect(t.status, TimerStatus.done);
      expect(t.timeUp, isFalse);
      expect(t.elapsedUs, 45000000);
    });
  });

  group('журнал', () {
    test('рекорд — найкраща спроба', () {
      final now = DateTime(2026, 10, 6);
      expect(bestOf([]), 0);
      expect(
          bestOf([BreathAttempt('candle', 12.5, now), BreathAttempt('candle', 31.2, now), BreathAttempt('candle', 20, now)]),
          31.2);
    });

    test('JSON спроби й сесії туди-назад; биті записи пропускаються', () {
      final a = BreathAttempt('hiss_exhale', 42.3, DateTime(2026, 10, 6, 7, 41));
      final back = BreathAttempt.fromJson(a.toJson())!;
      expect((back.exerciseId, back.seconds, back.at), (a.exerciseId, a.seconds, a.at));
      expect(BreathAttempt.fromJson({'e': 1}), isNull);
      expect(BreathAttempt.fromJson('сміття'), isNull);

      final s = BreathSessionLog('long_tones', DateTime(2026, 10, 6), 96, true);
      final sb = BreathSessionLog.fromJson(s.toJson())!;
      expect((sb.exerciseId, sb.at, sb.seconds, sb.completed), (s.exerciseId, s.at, s.seconds, s.completed));
    });
  });
}
