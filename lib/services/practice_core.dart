// Програма навчальної практики ЛГс-32 як послідовність кроків і чиста логіка
// статусів та балів. Дзеркало site/js/practice-core.js — кроки, id і бали
// мають збігатися, бо сайт і застосунок пишуть ті самі документи
// practice_work/{uid}. Тести: test/practice_core_test.dart.

const breathDates = ['30.09', '01.10', '02.10', '03.10', '04.10'];
const breathExercises = ['Вдих 4 – затримка 2 – видих 8', 'Видих «с-с-с»', 'Атака «ту-ту»', 'Вібрація губ / мундштук'];
const diaryFields = [
  ('aud', 'Зміст аудиторної роботи'),
  ('self', 'Зміст самостійної роботи'),
  ('concl', 'Висновок (що вдалося, над чим працювати)'),
];
const trackedSignals = [
  'Привітання', 'Збір мисливців', 'Вирушаємо на полювання', 'Початок загону', 'Припинити стрільбу',
  'Кінець загону', 'Полювання завершено', 'Халалі',
];
const signalSkills = [('know', 'Знаю призначення'), ('hear', 'Розпізнаю на слух'), ('play', 'Виконую')];

/// Види кроків — як kind на сайті.
enum StepKind { check, profile, submit, quiz, audio, retest, diary, breath, signals, exam, teacher }

class PracticeStep {
  final String id;
  final StepKind kind;
  final String title;
  final String? hint;
  final String? group; // pr | sr | report | exam
  final int points;
  final bool fileRequired;
  final String? due;
  final List<int> topics;
  final int threshold;
  final int minCount;
  final int? day;
  final String? part; // theory | audio
  final String? action; // metronome | cards
  late final String stageId;

  PracticeStep(this.id, this.kind, this.title,
      {this.hint, this.group, this.points = 0, this.fileRequired = false, this.due,
      this.topics = const [], this.threshold = 0, this.minCount = 0, this.day, this.part, this.action});
}

class PracticeStage {
  final String id, title, date;
  final int? day;
  final List<PracticeStep> steps;
  PracticeStage(this.id, this.title, this.date, this.steps, {this.day}) {
    for (final s in steps) {
      s.stageId = id;
    }
  }
}

const _mr = '📘 Методичні рекомендації', _tasks = '📗 Завдання практики', _diary = '📙 Щоденник і звіт';

final List<PracticeStage> practiceStages = [
  PracticeStage('prep', 'До початку практики', 'до 29.09', [
    PracticeStep('prep_profile', StepKind.profile, 'Заповнити «Мої дані»', hint: 'ПІБ і група — у «Мій акаунт». За ними викладач бачить ваші роботи й результати.'),
    PracticeStep('prep_rules', StepKind.check, 'Ознайомитися з метою й оцінюванням практики', hint: '$_mr: розділ 1 «Загальні положення» і розділ 12 «Оцінювання» (100 балів, допуск — не менше 35 поточних).'),
    PracticeStep('prep_diary', StepKind.check, 'Заповнити титульну сторінку щоденника', hint: '$_diary: ПІБ, відділення, форма навчання, курс.'),
  ]),
  PracticeStage('d1', 'День 1. Історія сигналів. Будова ріжка', '29.09 · 4 год ауд. + 6 год сам.', day: 1, [
    PracticeStep('d1_safety', StepKind.check, 'Інструктаж з охорони праці', hint: '$_diary: підпис у рядку за 29.09; $_mr: розділ 2 (правило про мундштук).'),
    PracticeStep('d1_survey', StepKind.check, 'Вхідне анкетування', hint: 'Заповнити анкету (5 питань) і здати викладачу.'),
    PracticeStep('d1_pr', StepKind.submit, 'Практична робота № 1', group: 'pr', points: 6, hint: '$_tasks: «День 1» → «Хід роботи», кроки 1–7: конспект лекції, схема ріжка, станції «Ріжок», «Ритм і ноти», «Слух». Додайте фото сторінок зошита/щоденника.'),
    PracticeStep('d1_sr', StepKind.submit, 'Самостійна робота № 1', group: 'sr', points: 6, fileRequired: true, due: '30.09', hint: 'Конспект 2–3 с. (розділ 3), хронологічна таблиця (≥ 8 етапів), схема ріжка + пам’ятка догляду (8–10 пунктів), есе «Звук, що об’єднує мисливців». Додайте фото або файли.'),
    PracticeStep('d1_quiz', StepKind.quiz, 'Пробний тест «Практика. Тема 1»', topics: [1], hint: 'Пройдіть тест і перегляньте розбір помилок. Результат зарахується автоматично.'),
    PracticeStep('d1_diary', StepKind.diary, 'Щоденник: запис за день 1', day: 1),
  ]),
  PracticeStage('d2', 'День 2. Музична грамота. Техніка звуковидобування', '30.09 · 4 + 6 год', day: 2, [
    PracticeStep('d2_pr', StepKind.submit, 'Практична робота № 2', group: 'pr', points: 6, hint: '$_tasks: «День 2», кроки 1–7: ноти, таблиця тривалостей, натуральний звукоряд, дихальні вправи, станції.'),
    PracticeStep('d2_metronome', StepKind.check, 'Ритм «Збір мисливців» під метроном ♩ = 80', action: 'metronome', hint: 'Навчання → Тренажери → «Метроном».'),
    PracticeStep('d2_sr', StepKind.submit, 'Самостійна робота № 2', group: 'sr', points: 6, fileRequired: true, due: '01.10', hint: 'По 2 такти в розмірах 2/4, 3/4, 4/4, 6/8; нотний запис 4 сигналів («Привітання», «Збір мисливців», «Початок загону», «Припинити стрільбу») з підписами.'),
    PracticeStep('d2_quiz', StepKind.quiz, 'Пробні тести «Тема 2» і «Тема 3»', topics: [2, 3]),
    PracticeStep('d2_breath', StepKind.breath, 'Дихальні вправи щодня (30.09–04.10)', hint: '$_mr: розділ 6 → «Комплекс дихальних вправ», 15–20 хв щодня. Відмічайте вправи й найдовший видих.'),
    PracticeStep('d2_diary', StepKind.diary, 'Щоденник: запис за день 2', day: 2),
  ]),
  PracticeStage('d3', 'День 3. Система мисливських сигналів', '01.10 · 4 + 6 год', day: 3, [
    PracticeStep('d3_pr', StepKind.submit, 'Практична робота № 3', group: 'pr', points: 6, hint: '$_tasks: «День 3»: класифікація, таблиця «Керівні сигнали», розучування сигналів, гра «Сигнал – дія».'),
    PracticeStep('d3_sr', StepKind.submit, 'Самостійна робота № 3', group: 'sr', points: 6, fileRequired: true, due: '02.10', hint: 'Картки сигналів (9 керівних + 6 вшанування), власний глосарій (≥ 30 термінів), схема загінного полювання.'),
    PracticeStep('d3_audio', StepKind.audio, 'Аудіотест — не менше 3 спроб', minCount: 3, hint: 'Практика → «Сигнали практики» або Навчання → Тести → Аудіо тест.'),
    PracticeStep('d3_cards', StepKind.check, 'Повторити терміни на флеш-картках', action: 'cards', hint: 'Навчання → Картки.'),
    PracticeStep('d3_quiz', StepKind.quiz, 'Пробні тести «Тема 4» і «Тема 5»', topics: [4, 5]),
    PracticeStep('d3_signals', StepKind.signals, 'Облік розучених сигналів', hint: 'Позначте, які сигнали ви знаєте, розпізнаєте на слух і виконуєте.'),
    PracticeStep('d3_diary', StepKind.diary, 'Щоденник: запис за день 3', day: 3),
  ]),
  PracticeStage('d4', 'День 4. Мисливська культура та етика. Ділова гра', '02.10 · 4 + 6 год', day: 4, [
    PracticeStep('d4_safety', StepKind.check, 'Цільовий інструктаж', hint: '$_diary: підпис за 02.10. Заняття надворі — зручний одяг.'),
    PracticeStep('d4_pr', StepKind.submit, 'Практична робота № 4', group: 'pr', points: 6, hint: '$_tasks: «День 4»: зламки, ділова гра у своїй ролі, дії за сигналами.'),
    PracticeStep('d4_sr', StepKind.submit, 'Самостійна робота № 4', group: 'sr', points: 6, fileRequired: true, hint: 'Конспект «Етичний кодекс і звичаї мисливця», сценарій полювального дня із сигнальним супроводом.'),
    PracticeStep('d4_individual', StepKind.submit, 'Індивідуальне завдання', fileRequired: true, hint: 'Реферат 8–10 с. або презентація 10–12 слайдів (тему погодити з керівником). Враховується в оцінці щоденника і звіту.'),
    PracticeStep('d4_quiz', StepKind.quiz, 'Пробний тест «Тема 6»', topics: [6]),
    PracticeStep('d4_diary', StepKind.diary, 'Щоденник: запис за день 4', day: 4),
  ]),
  PracticeStage('w', 'Вихідні 03–04.10. Звіт і підготовка до заліку', '03–04.10', [
    PracticeStep('w_selfcheck', StepKind.check, 'Питання для самоконтролю', hint: '$_mr: розділ 13 — відповісти на всі питання усно.'),
    PracticeStep('w_retest', StepKind.retest, 'Повторно: теми 1–6 не менше 80 %', topics: [1, 2, 3, 4, 5, 6], threshold: 80, hint: 'Зараховується найкращий результат кожної теми.'),
    PracticeStep('w_report', StepKind.submit, 'Щоденник і звіт', group: 'report', points: 12, fileRequired: true, hint: '$_mr: розділ 11 (вимоги). Звіт 10–15 с. з додатками + скан/фото заповненого щоденника. Здати до заліку.'),
  ]),
  PracticeStage('d5', 'День 5. Диференційований залік', '05.10 · 2 + 3 год', day: 5, [
    PracticeStep('e_theory', StepKind.exam, 'Теоретичний тест (20 питань)', part: 'theory', group: 'exam', points: 20, hint: 'Іспит проходять на сайті: «Практика» → «Ввести код сесії». Бали ставляться автоматично.'),
    PracticeStep('e_audio', StepKind.exam, 'Аудіотест (10 сигналів)', part: 'audio', group: 'exam', points: 6, hint: 'У тій самій сесії на сайті. Бал = правильних × 0,6.'),
    PracticeStep('e_signal', StepKind.teacher, 'Виконання сигналу на ріжку', group: 'exam', points: 8, hint: 'Оцінює викладач на заліку (голосом — до 4 балів).'),
    PracticeStep('e_rhythm', StepKind.teacher, 'Читання ритму незнайомого сигналу', group: 'exam', points: 6, hint: 'Оцінює викладач на заліку.'),
    PracticeStep('d5_diary', StepKind.diary, 'Щоденник: запис за день 5', day: 5),
  ]),
];

final List<PracticeStep> allPracticeSteps = [for (final s in practiceStages) ...s.steps];
final Map<String, PracticeStep> practiceStepById = {for (final s in allPracticeSteps) s.id: s};
final int maxCurrent = allPracticeSteps
    .where((s) => const ['pr', 'sr', 'report'].contains(s.group))
    .fold(0, (a, s) => a + s.points); // 60
final int maxExam = allPracticeSteps.where((s) => s.group == 'exam').fold(0, (a, s) => a + s.points); // 40
const admissionMin = 35;

/// Найкращі бали іспиту (теорія, аудіо) або null, якщо іспит не складено.
typedef ExamPoints = ({num? theory, num? audio});

/// Автоматичні джерела й профіль для статусів.
class PracticeCtx {
  final String fullName, group;
  final List<Map<String, dynamic>> quizResults;
  final ExamPoints? exam;
  const PracticeCtx({this.fullName = '', this.group = '', this.quizResults = const [], this.exam});
}

enum PracticeState { todo, done, review, revise, graded, teacher }

class StepStatus {
  final PracticeState state;
  final String label;
  final num? points;
  final int max;
  const StepStatus(this.state, this.label, this.points, this.max);
}

/// Номер теми з назви «Практика. Тема N. …».
int? topicNumber(String? name) {
  final m = RegExp(r'Тема\s+(\d+)').firstMatch(name ?? '');
  return m == null ? null : int.parse(m.group(1)!);
}

/// Найкращий відсоток пробного теоретичного тесту для кожної теми (за номером).
Map<int, int> bestByTopic(List<Map<String, dynamic>> quizResults) {
  final best = <int, int>{};
  for (final r in quizResults) {
    if (r['kind'] != 'theory') continue;
    final n = topicNumber(r['topicName']?.toString());
    if (n == null) continue;
    final total = (r['total'] as num?) ?? 0;
    final p = (r['percent'] as num?)?.round() ??
        (total > 0 ? (((r['correct'] as num?) ?? 0) / total * 100).round() : 0);
    if (!best.containsKey(n) || p > best[n]!) best[n] = p;
  }
  return best;
}

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
bool _filled(Object? v) => v is String && v.trim().isNotEmpty;

bool diaryDone(Object? entry) {
  final e = _map(entry);
  return e.isNotEmpty && diaryFields.every((f) => _filled(e[f.$1]));
}

bool _breathDay(Map<String, dynamic> table, String d) {
  final ex = _map(table[d])['ex'];
  return ex is List && ex.any((x) => x == true);
}

bool breathDone(Object? table) {
  final t = _map(table);
  return t.isNotEmpty && breathDates.every((d) => _breathDay(t, d));
}

bool signalsDone(Object? table) {
  final t = _map(table);
  return t.isNotEmpty && trackedSignals.every((s) => signalSkills.any((k) => _map(t[s])[k.$1] == true));
}

/// Мілісекунди з Timestamp / DateTime / числа.
int toMs(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is DateTime) return v.millisecondsSinceEpoch;
  try {
    // cloud_firestore Timestamp — без залежності від пакета в чистій логіці
    return (v as dynamic).millisecondsSinceEpoch as int;
  } catch (_) {
    return 0;
  }
}

String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

/// Статус кроку. work — practice_work/{uid}; grades — practice_grades/{uid}.grades.
StepStatus stepStatus(PracticeStep step, Map<String, dynamic> work, Map<String, dynamic> grades, [PracticeCtx ctx = const PracticeCtx()]) {
  final max = step.points;
  final g = grades[step.id] is Map ? _map(grades[step.id]) : null;
  final s = _map(_map(work['steps'])[step.id]);
  final gp = g?['points'];
  final graded = g != null && g['status'] != 'revise' && g['status'] != 'none' && gp is num && gp.isFinite;
  StepStatus res(PracticeState st, String label, [num? points]) => StepStatus(st, label, points, max);

  switch (step.kind) {
    case StepKind.profile:
      return ctx.fullName.isNotEmpty && ctx.group.isNotEmpty ? res(PracticeState.done, 'Виконано') : res(PracticeState.todo, 'Не виконано');
    case StepKind.check:
      // відмітку студента підтверджує викладач
      if (graded) return res(PracticeState.graded, 'Виконано · Підтверджено');
      if (g?['status'] == 'revise' &&
          !(s['doneAt'] != null && g?['gradedAt'] != null && toMs(s['doneAt']) > toMs(g?['gradedAt']))) {
        return res(PracticeState.revise, 'Не підтверджено');
      }
      return s['done'] == true ? res(PracticeState.review, 'Очікування на підтвердження') : res(PracticeState.todo, 'Не виконано');
    case StepKind.diary:
      return diaryDone(_map(work['diary'])['d${step.day}']) ? res(PracticeState.done, 'Виконано') : res(PracticeState.todo, 'Не заповнено');
    case StepKind.breath:
      if (breathDone(work['breath'])) return res(PracticeState.done, 'Виконано');
      final t = _map(work['breath']);
      return res(PracticeState.todo, 'Заповнено днів: ${breathDates.where((d) => _breathDay(t, d)).length} з ${breathDates.length}');
    case StepKind.signals:
      return signalsDone(work['signals']) ? res(PracticeState.done, 'Виконано') : res(PracticeState.todo, 'Не заповнено');
    case StepKind.quiz:
      final best = bestByTopic(ctx.quizResults);
      final doneN = step.topics.where(best.containsKey).length;
      if (doneN == step.topics.length) {
        return res(PracticeState.done, 'Виконано автоматично · ${step.topics.map((n) => 'тема $n: ${best[n]} %').join(', ')}');
      }
      return res(PracticeState.todo, step.topics.length > 1 ? 'Пройдено $doneN з ${step.topics.length}' : 'Не пройдено');
    case StepKind.retest:
      final best = bestByTopic(ctx.quizResults);
      final ok = step.topics.where((n) => (best[n] ?? -1) >= step.threshold).length;
      return ok == step.topics.length
          ? res(PracticeState.done, 'Виконано автоматично · усі теми ≥ ${step.threshold} %')
          : res(PracticeState.todo, '≥ ${step.threshold} %: $ok з ${step.topics.length} тем');
    case StepKind.audio:
      final n = ctx.quizResults.where((r) => r['kind'] == 'audio').length;
      return n >= step.minCount
          ? res(PracticeState.done, 'Виконано автоматично · спроб: $n')
          : res(PracticeState.todo, 'Спроб: $n з ${step.minCount}');
    case StepKind.exam:
      if (graded) return res(PracticeState.graded, 'Оцінено: ${_fmt(gp)} з $max балів', gp);
      final p = step.part == 'audio' ? ctx.exam?.audio : ctx.exam?.theory;
      return p != null ? res(PracticeState.graded, 'Автоматично: ${_fmt(p)} з $max балів', p) : res(PracticeState.todo, 'Не складено · макс. $max балів');
    case StepKind.teacher:
      return graded
          ? res(PracticeState.graded, 'Оцінено: ${_fmt(gp)} з $max балів', gp)
          : res(PracticeState.teacher, 'Оцінює викладач на заліку · макс. $max балів');
    case StepKind.submit:
      if (graded) {
        return max > 0
            ? res(PracticeState.graded, 'Виконано · Оцінено: ${_fmt(gp)} з $max балів', gp)
            : res(PracticeState.graded, 'Виконано · Прийнято');
      }
      if (g?['status'] == 'revise' &&
          !(s['submittedAt'] != null && g?['gradedAt'] != null && toMs(s['submittedAt']) > toMs(g?['gradedAt']))) {
        return res(PracticeState.revise, 'На доопрацювання');
      }
      if (s['done'] == true) {
        return res(PracticeState.review,
            max > 0 ? 'Виконано · На перевірці: максимальна кількість балів за завдання $max балів' : 'Виконано · На перевірці');
      }
      return res(PracticeState.todo, max > 0 ? 'Не виконано · макс. $max балів' : 'Не виконано');
  }
}

class Grade {
  final String ects, nat;
  const Grade(this.ects, this.nat);
}

/// Переведення балів за шкалою коледжу (методичні рекомендації, розділ 12).
Grade ectsGrade(num p) {
  if (p >= 90) return const Grade('A', 'відмінно');
  if (p >= 82) return const Grade('B', 'добре');
  if (p >= 74) return const Grade('C', 'добре');
  if (p >= 64) return const Grade('D', 'задовільно');
  if (p >= 60) return const Grade('E', 'задовільно');
  if (p >= 35) return const Grade('FX', 'незадовільно (повторне складання)');
  return const Grade('F', 'незадовільно (повторне проходження)');
}

class PracticeTotals {
  final num current, exam;
  final int done, review, count;
  const PracticeTotals(this.current, this.exam, this.done, this.review, this.count);
  num get total => current + exam;
  bool get admitted => current >= admissionMin;
  Grade get grade => ectsGrade(total);
}

PracticeTotals practiceTotals(Map<String, dynamic> work, Map<String, dynamic> grades, [PracticeCtx ctx = const PracticeCtx()]) {
  num current = 0, exam = 0;
  var done = 0, review = 0;
  for (final step in allPracticeSteps) {
    final st = stepStatus(step, work, grades, ctx);
    if (const [PracticeState.done, PracticeState.graded, PracticeState.review].contains(st.state)) done++;
    if (st.state == PracticeState.review) review++;
    if (st.points != null && step.group != null) {
      if (step.group == 'exam') {
        exam += st.points!;
      } else {
        current += st.points!;
      }
    }
  }
  return PracticeTotals(current, exam, done, review, allPracticeSteps.length);
}

/// Перший невиконаний крок — «Далі».
PracticeStep? nextPracticeStep(Map<String, dynamic> work, Map<String, dynamic> grades, [PracticeCtx ctx = const PracticeCtx()]) {
  for (final s in allPracticeSteps) {
    final st = stepStatus(s, work, grades, ctx).state;
    if (st == PracticeState.todo || st == PracticeState.revise) return s;
  }
  return null;
}

/// Найкращі бали іспиту з власних спроб/робіт (з урахуванням правок викладача).
ExamPoints? bestExam(List<Map<String, dynamic>> attempts, List<Map<String, dynamic>> submissions) {
  final subById = {for (final s in submissions) s['id']: s};
  ExamPoints? best;
  num bestSum = -1;
  for (final a in attempts) {
    if (a['status'] != 'submitted') continue;
    final sub = subById['${a['sessionId']}_${a['uid']}'];
    final theory = (sub?['adminTheoryPoints'] as num?) ?? (_map(a['theory'])['points'] as num?);
    final audio = (sub?['adminAudioPoints'] as num?) ?? (_map(a['audio'])['points'] as num?);
    final sum = (theory ?? 0) + (audio ?? 0);
    if (best == null || sum > bestSum) {
      best = (theory: theory, audio: audio);
      bestSum = sum;
    }
  }
  return best;
}
