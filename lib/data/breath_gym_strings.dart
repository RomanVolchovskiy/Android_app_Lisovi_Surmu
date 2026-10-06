import 'package:hunting_signals/models/breath_gym_models.dart';

/// Тексти інтерфейсу дихального тренажера (зміст вправ — у каталозі).
class BgStrings {
  static const tabTitle = 'Дихальний тренажер';
  static const introTitle = 'Про тренажер';
  static const introOk = 'Зрозуміло';
  static const exercises = 'Вправи';
  static const programs = 'Програми';
  static const needs = 'Потрібно';
  static const source = 'Джерело';
  static const warning = 'Увага';
  static const tips = 'Підказки';
  static const settings = 'Налаштування';
  static const tempo = 'Темп';
  static const series = 'Серії';
  static const repeats = 'Повтори';
  static const syllable = 'Склад';
  static const syllableTu = 'ту (з атакою)';
  static const syllableHu = 'ху (без атаки)';
  static const start = 'Почати';
  static const pause = 'Пауза';
  static const resume = 'Продовжити';
  static const stop = 'Стоп';
  static const skip = 'Пропустити';
  static const again = 'Ще раз';
  static const done = 'Готово';
  static const getReady = 'Приготуйся';
  static const finished = 'Вправу завершено';
  static const stopped = 'Вправу зупинено';
  static const stopTitle = 'Зупинити вправу?';
  static const stopBody = 'Прогрес цієї спроби не буде враховано.';
  static const cancel = 'Скасувати';
  static const pausedHint = 'Пауза — натисни «Продовжити»';

  // Секундомір
  static const record = 'Рекорд';
  static const noRecord = 'Рекорду ще немає';
  static const result = 'Результат';
  static const newRecord = 'Новий рекорд!';
  static const firstResult = 'Перший результат';
  static const startAttempt = 'Почати спробу';
  static const anotherAttempt = 'Ще спроба';
  static const lastAttempts = 'Останні спроби';
  static const inhaleSoon = 'Зараз буде вдих ротом';
  static const inhaleDeep = 'Глибокий безшумний вдих ротом';
  static const exhaleEvenly = 'Видихай рівно. Натисни «Стоп», коли закінчиться повітря';

  // Таймер
  static const timeUp = 'Час вийшов';
  static const finishedEarly = 'Вправу виконано';

  /// «32,4».
  static String secNumber(double s) => s.toStringAsFixed(1).replaceAll('.', ',');

  /// «32,4 с».
  static String sec(double s) => '${secNumber(s)} с';

  /// «06.10 07:41».
  static String dateTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  static String phase(PhaseType t) => switch (t) {
        PhaseType.inhale => 'ВДИХ',
        PhaseType.exhale => 'ВИДИХ',
        PhaseType.hold => 'ПАУЗА',
        PhaseType.action => 'ІМПУЛЬС',
        PhaseType.rest => 'ВІДПОЧИНОК',
      };

  static String mode(ExerciseMode m) => switch (m) {
        ExerciseMode.guided => 'Під метроном',
        ExerciseMode.stopwatch => 'Секундомір',
        ExerciseMode.freeTimer => 'Таймер',
      };

  static String beatOf(int beat, int beats) => 'Доля $beat / $beats';
  static String repeatOf(int r, int n) => 'Повтор $r / $n';
  static String inhaleOf(int r, int n) => 'Вдих $r / $n';
  static String seriesOf(int s, int n) => 'Серія $s / $n';
  static String bpm(int v) => '$v уд/хв';
  static String remaining(int sec) => 'Залишилось ${clock(sec)}';

  /// «≈ 1 хв 20 с» / «≈ 45 с».
  static String approx(int sec) => '≈ ${duration(sec)}';

  static String duration(int sec) => sec >= 60
      ? '${sec ~/ 60} хв${sec % 60 > 0 ? ' ${sec % 60} с' : ''}'
      : '$sec с';

  /// «1:05».
  static String clock(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  static const romans = ['I', 'II', 'III', 'IV', 'V'];
}
