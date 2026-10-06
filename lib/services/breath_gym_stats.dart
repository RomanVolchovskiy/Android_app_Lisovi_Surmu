import 'package:hunting_signals/services/breath_gym_storage.dart';

// Статистика прогресу з локального журналу. Чисті функції — `now`
// передається явно, щоб тестувати.

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Понеділок поточного тижня.
DateTime weekStart(DateTime now) => dayOf(now).subtract(Duration(days: now.weekday - 1));

/// Виконані вправи по днях поточного тижня: [пн, вт, …, нд].
List<int> weekCounts(Iterable<BreathSessionLog> sessions, DateTime now) {
  final start = weekStart(now);
  final counts = List.filled(7, 0);
  for (final s in sessions) {
    if (!s.completed) continue;
    final d = dayOf(s.at).difference(start).inDays;
    if (d >= 0 && d < 7) counts[d]++;
  }
  return counts;
}

/// Днів поспіль із тренуванням. Сьогодні ще без тренування — серія
/// не обривається, рахуємо від учора.
int currentStreak(Iterable<BreathSessionLog> sessions, DateTime now) {
  final days = {for (final s in sessions) if (s.completed) dayOf(s.at)};
  var day = dayOf(now);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var n = 0;
  while (days.contains(day)) {
    n++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return n;
}

/// Найдовша серія днів за всю історію.
int longestStreak(Iterable<BreathSessionLog> sessions) {
  final days = {for (final s in sessions) if (s.completed) dayOf(s.at)}.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

/// Останні [limit] спроб вправи в хронологічному порядку — для графіка.
List<BreathAttempt> chartPoints(Iterable<BreathAttempt> attempts, String exerciseId, {int limit = 30}) {
  final list = attempts.where((a) => a.exerciseId == exerciseId).toList()..sort((a, b) => a.at.compareTo(b.at));
  return list.length > limit ? list.sublist(list.length - limit) : list;
}
