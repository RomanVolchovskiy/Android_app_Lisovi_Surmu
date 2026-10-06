// Дихальний тренажер для духовиків: модель вправ і програм.
// Каталог статичний (lib/data/breath_gym_catalog.dart), тут лише типи
// та чиста логіка налаштувань — без Flutter, щоб тестувати без пристрою.

enum PhaseType { inhale, exhale, hold, action, rest }

enum ExerciseMode {
  /// Фази під метроном.
  guided,

  /// Секундомір видиху з рекордами.
  stopwatch,

  /// Інструкція й таймер.
  freeTimer,
}

/// Фаза: або [beats] долей метронома, або [seconds] секунд.
class Phase {
  final PhaseType type;
  final int beats;
  final double seconds;
  final String hint;

  /// Коло росте до середини фази, потім зменшується (crescendo – diminuendo).
  final bool swell;

  const Phase(this.type, {this.beats = 0, this.seconds = 0, this.hint = '', this.swell = false})
      : assert((beats > 0) != (seconds > 0), 'Фаза задається або долями, або секундами');

  bool get isBeatBased => beats > 0;
}

/// Набір фаз, що повторюється [repeats] разів. Вправа може мати кілька
/// груп поспіль: Flow Studies (4/4 → 3/5 → …) чи «Довгі ноти» (рівно →
/// crescendo).
class PhaseGroup {
  final List<Phase> phases;
  final int repeats;
  const PhaseGroup(this.phases, {this.repeats = 1});

  int get beatsPerPass => phases.fold(0, (s, p) => s + p.beats);
}

class Exercise {
  final String id;

  /// Блок 1–5 (див. [breathGymBlocks]).
  final int block;
  final String title;
  final String source;
  final String description;
  final ExerciseMode mode;
  final List<PhaseGroup> groups;

  final int series;
  final int seriesMin;
  final int seriesMax;
  final double restBetweenSeriesSec;

  /// Чи можна в налаштуваннях змінити кількість повторів кожної групи.
  final bool repeatsAdjustable;

  final int defaultBpm;
  final int bpmMin;
  final int bpmMax;

  /// GUIDED: тривалість серії — фази йдуть по колу, доки не мине час.
  /// FREE_TIMER: тривалість таймера.
  final int totalSeconds;

  final String warning;
  final String needsItem;

  /// ACTION-фази показують склад «ту» / «ху» з налаштувань.
  final bool hasSyllable;

  /// Підказки постави (ігрові вправи).
  final List<String> tips;

  /// Орієнтири результату (STOPWATCH).
  final String benchmark;

  const Exercise({
    required this.id,
    required this.block,
    required this.title,
    required this.source,
    required this.description,
    required this.mode,
    this.groups = const [],
    this.series = 1,
    this.seriesMin = 1,
    this.seriesMax = 1,
    this.restBetweenSeriesSec = 0,
    this.repeatsAdjustable = false,
    this.defaultBpm = 60,
    this.bpmMin = 60,
    this.bpmMax = 60,
    this.totalSeconds = 0,
    this.warning = '',
    this.needsItem = '',
    this.hasSyllable = false,
    this.tips = const [],
    this.benchmark = '',
  });

  /// Усі фази одного проходу всіх груп.
  List<Phase> get phases => [for (final g in groups) ...g.phases];

  /// Повтори першої групи (у більшості вправ група одна).
  int get repeats => groups.isEmpty ? 0 : groups.first.repeats;

  bool get isTimed => mode == ExerciseMode.guided && totalSeconds > 0;
  bool get bpmAdjustable => mode == ExerciseMode.guided && bpmMax > bpmMin;
  bool get seriesAdjustable => mode == ExerciseMode.guided && seriesMax > seriesMin;

  ExerciseSettings get defaults => ExerciseSettings(bpm: defaultBpm, series: series);
}

/// Налаштування виконання, які студент змінює на картці вправи.
class ExerciseSettings {
  final int bpm;
  final int series;

  /// null — повтори з каталогу.
  final int? repeats;
  final String syllable;

  const ExerciseSettings({required this.bpm, required this.series, this.repeats, this.syllable = 'ту'});

  ExerciseSettings copyWith({int? bpm, int? series, int? repeats, bool clearRepeats = false, String? syllable}) =>
      ExerciseSettings(
        bpm: bpm ?? this.bpm,
        series: series ?? this.series,
        repeats: clearRepeats ? null : repeats ?? this.repeats,
        syllable: syllable ?? this.syllable,
      );

  /// Обмежує значення діапазонами вправи (наприклад, після зміни каталогу).
  ExerciseSettings clampTo(Exercise ex) => ExerciseSettings(
        bpm: bpm.clamp(ex.bpmMin, ex.bpmMax),
        series: series.clamp(ex.seriesMin, ex.seriesMax),
        repeats: ex.repeatsAdjustable ? repeats?.clamp(1, 20) : null,
        syllable: syllable == 'ху' ? 'ху' : 'ту',
      );
}

class Program {
  final String id;
  final String title;
  final String durationLabel;
  final String description;
  final List<String> exerciseIds;
  const Program({
    required this.id,
    required this.title,
    required this.durationLabel,
    required this.description,
    required this.exerciseIds,
  });
}
