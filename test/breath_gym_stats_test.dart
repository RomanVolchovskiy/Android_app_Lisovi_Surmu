import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/services/breath_gym_stats.dart';
import 'package:hunting_signals/services/breath_gym_storage.dart';

BreathSessionLog s(DateTime at, {bool done = true}) => BreathSessionLog('x', at, 60, done);

void main() {
  // Вівторок, 6 жовтня 2026, вечір.
  final now = DateTime(2026, 10, 6, 20);

  test('тиждень з понеділка; незавершені й минулий тиждень не рахуються', () {
    expect(weekStart(now), DateTime(2026, 10, 5));
    final counts = weekCounts([
      s(DateTime(2026, 10, 5, 8)),
      s(DateTime(2026, 10, 5, 9)),
      s(DateTime(2026, 10, 6, 7)),
      s(DateTime(2026, 10, 6, 8), done: false),
      s(DateTime(2026, 10, 4, 23)), // неділя минулого тижня
    ], now);
    expect(counts, [2, 1, 0, 0, 0, 0, 0]);
  });

  test('неділя — останній день тижня', () {
    final sunday = DateTime(2026, 10, 11, 10);
    expect(weekCounts([s(sunday)], sunday), [0, 0, 0, 0, 0, 0, 1]);
  });

  test('серія: сьогодні ще без тренування — рахуємо від учора', () {
    final log = [s(DateTime(2026, 10, 3)), s(DateTime(2026, 10, 4)), s(DateTime(2026, 10, 5))];
    expect(currentStreak(log, now), 3);
    expect(currentStreak([...log, s(DateTime(2026, 10, 6, 7))], now), 4);
  });

  test('серія обривається пропущеним днем', () {
    expect(currentStreak([s(DateTime(2026, 10, 2)), s(DateTime(2026, 10, 4))], now), 0);
    expect(currentStreak([s(DateTime(2026, 10, 6, 7), done: false)], now), 0);
    expect(currentStreak([], now), 0);
  });

  test('серія через зміну місяця', () {
    final log = [s(DateTime(2026, 9, 30)), s(DateTime(2026, 10, 1))];
    expect(currentStreak(log, DateTime(2026, 10, 1, 12)), 2);
  });

  test('найдовша серія', () {
    final log = [
      s(DateTime(2026, 9, 1)), s(DateTime(2026, 9, 2)), s(DateTime(2026, 9, 3)),
      s(DateTime(2026, 9, 3, 18)), // той самий день двічі
      s(DateTime(2026, 9, 10)), s(DateTime(2026, 9, 11)),
    ];
    expect(longestStreak(log), 3);
    expect(longestStreak([]), 0);
  });

  test('точки графіка — за часом, останні N, лише потрібна вправа', () {
    final a = [
      for (var i = 0; i < 40; i++) BreathAttempt('candle', i.toDouble(), DateTime(2026, 9, 1).add(Duration(hours: i))),
      BreathAttempt('paper_wall', 99, DateTime(2026, 9, 5)),
    ]..shuffle();
    final pts = chartPoints(a, 'candle');
    expect(pts, hasLength(30));
    expect(pts.first.seconds, 10);
    expect(pts.last.seconds, 39);
  });
}
