import 'package:hunting_signals/models/breath_gym_models.dart';

// Каталог дихального тренажера: 17 вправ і 4 програми.
// Джерела: A. Jacobs, «The Breathing Gym» (Pilafian & Sheridan),
// гімнастика О. Стрельникової, класична шкільна методика.

const srcBreathingGym = 'The Breathing Gym (Pilafian & Sheridan)';
const srcStrelnikova = 'Гімнастика О. Стрельникової';
const srcJacobs = 'A. Jacobs';
const srcClassic = 'Класична методика';

const breathGymBlocks = {
  1: 'Підготовка',
  2: 'Гімнастика Стрельникової',
  3: 'Ігрове дихання',
  4: 'Вправи з предметами (A. Jacobs)',
  5: 'На інструменті',
};

/// Показується один раз перед блоком II і на картках його вправ.
const strelnikovaWarning = 'Короткий вдих носом тут тренувальний. Ігровий вдих — ротом, '
    'глибокий і безшумний. Якщо паморочиться в голові — зупинись.';

const dizzinessWarning = 'Якщо паморочиться в голові — зупинись і подихай спокійно.';

/// Підказки постави для ігрових вправ.
const playTips = ['Плечі не піднімаються', 'Горло відкрите, вдих наче на «о»'];

const breathGymIntro = 'Вправи взято з методик A. Jacobs, The Breathing Gym і О. Стрельникової, '
    'які використовують у музичних школах і вишах. Навантаження збільшуй поступово.';

Phase _in(int beats, [String hint = '']) => Phase(PhaseType.inhale, beats: beats, hint: hint);
Phase _ex(int beats, [String hint = '', bool swell = false]) =>
    Phase(PhaseType.exhale, beats: beats, hint: hint, swell: swell);
Phase _hold(int beats, [String hint = '']) => Phase(PhaseType.hold, beats: beats, hint: hint);
Phase _rest(int beats, [String hint = '']) => Phase(PhaseType.rest, beats: beats, hint: hint);
Phase _act(int beats, [String hint = '']) => Phase(PhaseType.action, beats: beats, hint: hint);

/// Вправа Стрельникової: серія — 8 коротких вдихів по долі (видих
/// пасивний, окремої фази немає), між серіями 4 с відпочинку.
/// Кілька підказок чергуються від вдиху до вдиху.
Exercise _strelnikova(String id, String title, String description, List<String> hints) {
  assert(8 % hints.length == 0);
  return Exercise(
    id: id,
    block: 2,
    title: title,
    source: srcStrelnikova,
    description: description,
    mode: ExerciseMode.guided,
    groups: [PhaseGroup([for (final h in hints) _in(1, h)], repeats: 8 ~/ hints.length)],
    series: 3,
    seriesMin: 1,
    seriesMax: 12,
    restBetweenSeriesSec: 4,
    defaultBpm: 90,
    bpmMin: 60,
    bpmMax: 120,
    warning: strelnikovaWarning,
  );
}

/// Flow Studies: пари вдих/видих у долях, кожна двічі, без пауз.
PhaseGroup _flowPair(int inBeats, int exBeats) {
  final play = inBeats == 1;
  return PhaseGroup([
    _in(inBeats, 'вдих ротом'),
    _ex(exBeats, play ? 'так дихаємо під час гри' : 'видих'),
  ], repeats: 2);
}

final List<Exercise> breathGymExercises = [
  // ── Блок I. Підготовка ─────────────────────────────────────────────
  Exercise(
    id: 'stretch_breath',
    block: 1,
    title: 'Розтяжка з диханням',
    source: srcBreathingGym,
    description: 'Стань рівно, ноги на ширині плечей. На вдиху плавно піднімай руки через сторони вгору, '
        'на видиху опускай. Рух і дихання тривають однаково довго — на всі 4 долі.',
    mode: ExerciseMode.guided,
    groups: [PhaseGroup([_in(4, 'руки через сторони вгору'), _ex(4, 'руки вниз')], repeats: 6)],
    repeatsAdjustable: true,
    defaultBpm: 60,
    bpmMin: 40,
    bpmMax: 90,
  ),
  Exercise(
    id: 'rag_doll',
    block: 1,
    title: 'Ганчір\'яна лялька',
    source: srcBreathingGym,
    description: 'На видиху вільно, без зусилля опусти корпус донизу, руки висять. Зачекай, розслаб плечі й шию, '
        'потім на повільному вдиху випрямляйся хребець за хребцем.',
    mode: ExerciseMode.guided,
    groups: [
      PhaseGroup([
        _ex(4, 'вільно опусти корпус донизу'),
        _hold(2, 'розслаб плечі й шию'),
        _in(6, 'повільно випрямляйся'),
      ], repeats: 3),
    ],
    repeatsAdjustable: true,
    defaultBpm: 60,
    bpmMin: 40,
    bpmMax: 90,
    warning: 'Випрямляйся повільно, особливо якщо паморочиться в голові.',
  ),
  Exercise(
    id: 'book_on_belly',
    block: 1,
    title: 'Дихання лежачи з книгою',
    source: srcClassic,
    description: 'Ляж на спину, поклади книгу на живіт. Дихай так, щоб на вдиху книга піднімалася, а на видиху '
        'опускалася; груди й плечі майже нерухомі. Так відчувається робота діафрагми.',
    mode: ExerciseMode.guided,
    groups: [PhaseGroup([_in(4, 'книга піднімається'), _ex(6, 'книга опускається')], repeats: 8)],
    repeatsAdjustable: true,
    defaultBpm: 60,
    bpmMin: 40,
    bpmMax: 90,
    needsItem: 'книга',
  ),

  // ── Блок II. Гімнастика Стрельникової ──────────────────────────────
  _strelnikova('str_palms', 'Долоньки',
      'Стань рівно, зігнуті в ліктях руки долонями від себе. На кожен короткий шумний вдих носом стискай кулаки, '
          'видих пасивний — кулаки розтискаються самі.',
      ['стисни кулаки']),
  _strelnikova('str_epaulettes', 'Погончики',
      'Кулаки притиснуті до пояса. На кожен короткий вдих носом різко штовхай руки вниз, розтискаючи кулаки; '
          'на пасивному видиху повертай їх до пояса.',
      ['руки різко вниз, розтисни кулаки']),
  _strelnikova('str_pump', 'Насос',
      'Легкий нахил уперед, руки опущені, спина кругла. Короткий вдих носом — у нижній точці нахилу, '
          'на пасивному видиху трохи випрямляйся, не до кінця.',
      ['нахил уперед, вдих у нижній точці']),
  _strelnikova('str_cat', 'Кішка',
      'Ноги на ширині плечей. Легкий присід з поворотом корпусу то вправо, то вліво, руки роблять хапальний рух. '
          'На кожен присід — короткий вдих носом.',
      ['присід з поворотом вправо', 'присід з поворотом вліво']),
  _strelnikova('str_hug', 'Обійми плечі',
      'Руки зігнуті в ліктях на рівні плечей. На кожен короткий вдих носом зустрічним рухом обіймай себе за плечі, '
          'руки йдуть паралельно, не навхрест.',
      ['обійми плечі зустрічним рухом']),
  _strelnikova('str_pendulum', 'Великий маятник',
      'Поєднання «Насоса» й «Обійми плечі»: нахил уперед — вдих, прогин назад з обійманням плечей — вдих. '
          'Видих пасивний між рухами.',
      ['нахил уперед', 'прогин назад, обійми плечі']),

  // ── Блок III. Ігрове дихання ──────────────────────────────────────
  Exercise(
    id: 'flow_studies',
    block: 3,
    title: 'Flow Studies',
    source: srcBreathingGym,
    description: 'Безперервне дихання без пауз: вдих ротом плавно переходить у видих. Вдих поступово коротшає '
        '(4 → 1 доля), видих довшає (4 → 8). Пари 1/7 і 1/8 — так дихаємо під час гри.',
    mode: ExerciseMode.guided,
    groups: [_flowPair(4, 4), _flowPair(3, 5), _flowPair(2, 6), _flowPair(1, 7), _flowPair(1, 8)],
    repeatsAdjustable: true,
    defaultBpm: 60,
    bpmMin: 40,
    bpmMax: 90,
    tips: playTips,
  ),
  Exercise(
    id: 'hiss_exhale',
    block: 3,
    title: 'Видих на «с-с-с»',
    source: srcClassic,
    description: 'Після відліку зроби глибокий вдих ротом за 3 секунди, потім видихай рівно й тонко на «с-с-с». '
        'Натисни «Стоп», коли повітря закінчиться. Струмінь має бути рівним від початку до кінця.',
    mode: ExerciseMode.stopwatch,
    tips: playTips,
    benchmark: 'Орієнтири: початківець — 20–25 с, просунутий — 40–60+ с.',
  ),
  Exercise(
    id: 'panting',
    block: 3,
    title: 'Собачка',
    source: srcBreathingGym,
    description: 'Швидке поверхневе дихання ротом, як у собаки після бігу: вдих і видих по одній долі. '
        'Рухається тільки живіт, плечі й груди спокійні. Активізує діафрагму.',
    mode: ExerciseMode.guided,
    groups: [PhaseGroup([_in(1, 'вдих'), _ex(1, 'видих')])],
    totalSeconds: 15,
    series: 2,
    seriesMin: 1,
    seriesMax: 4,
    restBetweenSeriesSec: 10,
    defaultBpm: 140,
    bpmMin: 120,
    bpmMax: 160,
    warning: dizzinessWarning,
  ),
  Exercise(
    id: 'air_notes',
    block: 3,
    title: 'Повітряні ноти',
    source: srcClassic,
    description: 'Швидкий вдих ротом на одну долю, потім сім коротких поштовхів повітря без інструмента — '
        'по одному на долю. «Ту» тренує атаку язиком, «ху» — чистий поштовх діафрагмою без атаки.',
    mode: ExerciseMode.guided,
    groups: [PhaseGroup([_in(1, 'вдих ротом'), _act(7, 'ту')], repeats: 4)],
    repeatsAdjustable: true,
    defaultBpm: 80,
    bpmMin: 60,
    bpmMax: 100,
    hasSyllable: true,
    tips: playTips,
  ),

  // ── Блок IV. Вправи з предметами (A. Jacobs) ──────────────────────
  Exercise(
    id: 'candle',
    block: 4,
    title: 'Свічка',
    source: srcJacobs,
    description: 'Тримай запалену свічку на відстані 20–30 см. Після вдиху дми тонким рівним струменем на полум\'я: '
        'воно відхиляється, але не гасне. Натисни «Стоп», коли струмінь урветься.',
    mode: ExerciseMode.stopwatch,
    needsItem: 'свічка',
    warning: 'Обережно з вогнем: не нахиляйся до полум\'я.',
  ),
  Exercise(
    id: 'paper_wall',
    block: 4,
    title: 'Аркуш на стіні',
    source: srcJacobs,
    description: 'Приклади аркуш паперу до стіни й відпусти, утримуючи його тільки видихом. Чим рівніший струмінь, '
        'тим довше аркуш тримається. Натисни «Стоп», коли він упаде.',
    mode: ExerciseMode.stopwatch,
    needsItem: 'аркуш паперу',
  ),
  Exercise(
    id: 'breathing_bag',
    block: 4,
    title: 'Дихальний мішок',
    source: srcJacobs,
    description: 'Робиш повний вдих із мішка й повний видих у мішок, горло без напруги. Обсяг мішка показує, '
        'скільки повітря ти рухаєш. Дихай спокійно, не форсуй.',
    mode: ExerciseMode.freeTimer,
    totalSeconds: 120,
    needsItem: 'мішок 5–6 л або трубка',
    warning: dizzinessWarning,
  ),

  // ── Блок V. На інструменті ────────────────────────────────────────
  Exercise(
    id: 'long_tones',
    block: 5,
    title: 'Довгі ноти',
    source: srcClassic,
    description: 'Візьми ріжок чи валторну. Вдих на одну долю, нота на вісім долей рівним звуком, дві долі відпочинку. '
        'Потім ще чотири ноти з crescendo – diminuendo: голосніше до середини видиху, тихіше до кінця.',
    mode: ExerciseMode.guided,
    groups: [
      PhaseGroup([_in(1, 'вдих ротом'), _ex(8, 'рівна нота'), _rest(2, 'відпочинок')], repeats: 4),
      PhaseGroup([_in(1, 'вдих ротом'), _ex(8, 'crescendo – diminuendo', true), _rest(2, 'відпочинок')], repeats: 4),
    ],
    repeatsAdjustable: true,
    defaultBpm: 60,
    bpmMin: 40,
    bpmMax: 80,
    tips: playTips,
  ),
];

final Map<String, Exercise> breathGymById = {for (final e in breathGymExercises) e.id: e};

const List<Program> breathGymPrograms = [
  Program(
    id: 'daily',
    title: 'Щоденна розминка',
    durationLabel: '8–10 хв',
    description: 'Розтяжка, три вправи Стрельникової, ігрове дихання й довгі ноти.',
    exerciseIds: ['stretch_breath', 'str_palms', 'str_epaulettes', 'str_pump', 'flow_studies', 'hiss_exhale', 'long_tones'],
  ),
  Program(
    id: 'full',
    title: 'Повний комплекс',
    durationLabel: '25–30 хв',
    description: 'Усі 17 вправ від підготовки до інструмента.',
    exerciseIds: [
      'stretch_breath', 'rag_doll', 'book_on_belly',
      'str_palms', 'str_epaulettes', 'str_pump', 'str_cat', 'str_hug', 'str_pendulum',
      'flow_studies', 'hiss_exhale', 'panting', 'air_notes',
      'candle', 'paper_wall', 'breathing_bag',
      'long_tones',
    ],
  ),
  Program(
    id: 'pre_performance',
    title: 'Перед виступом',
    durationLabel: '≈7 хв',
    description: 'Розслаблення, активізація діафрагми й довгі ноти перед виходом на сцену.',
    exerciseIds: ['rag_doll', 'flow_studies', 'panting', 'air_notes', 'long_tones'],
  ),
  Program(
    id: 'strelnikova',
    title: 'Стрельникова',
    durationLabel: '5–7 хв',
    description: 'Усі шість вправ гімнастики О. Стрельникової.',
    exerciseIds: ['str_palms', 'str_epaulettes', 'str_pump', 'str_cat', 'str_hug', 'str_pendulum'],
  ),
];
