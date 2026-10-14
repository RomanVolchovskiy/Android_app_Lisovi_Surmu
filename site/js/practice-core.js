// Програма навчальної практики ЛГс-32 у вигляді послідовності кроків
// (за «Покроковою інструкцією студента») і чиста логіка статусів та балів.
// Без DOM і Firebase — тести: scripts/site_tests/practice_core.test.mjs.
//
// Види кроків (kind):
//   check   — студент ставить відмітку «Виконано» (без балів);
//   profile — «Мої дані» заповнені (ПІБ і група) — автоматично;
//   submit  — студент додає файли й/або відмітку → «На перевірці», бали ставить викладач;
//   quiz    — пробні теоретичні тести тем (topics) — автоматично з quiz_results;
//   audio   — пробні аудіотести, щонайменше minCount — автоматично;
//   retest  — усі теми 1–6 з найкращим результатом ≥ threshold % — автоматично;
//   diary   — щоденний запис (аудиторна, самостійна робота, висновок);
//   breath  — таблиця самоконтролю дихальних вправ;
//   signals — облік розучених сигналів;
//   exam    — бали з іспиту на сайті (part: 'theory' | 'audio') — автоматично;
//   teacher — оцінює викладач на заліку (виконання сигналу, читання ритму).
//
// Усе, що не перевіряється автоматично (CONFIRM_KINDS), після виконання студентом
// стає «Очікування на підтвердження», доки викладач не підтвердить.

export const BREATH_DATES = ['30.09', '01.10', '02.10', '03.10', '04.10'];
export const BREATH_EXERCISES = ['Вдих 4 – затримка 2 – видих 8', 'Видих «с-с-с»', 'Атака «ту-ту»', 'Вібрація губ / мундштук'];
export const DIARY_FIELDS = [
  ['aud', 'Зміст аудиторної роботи'],
  ['self', 'Зміст самостійної роботи'],
  ['concl', 'Висновок (що вдалося, над чим працювати)'],
];
export const TRACKED_SIGNALS = [
  'Привітання', 'Збір мисливців', 'Вирушаємо на полювання', 'Початок загону', 'Припинити стрільбу',
  'Кінець загону', 'Полювання завершено', 'Халалі',
];
export const SIGNAL_SKILLS = [['know', 'Знаю призначення'], ['hear', 'Розпізнаю на слух'], ['play', 'Виконую']];

const MR = '📘 Методичні рекомендації', TASKS = '📗 Завдання практики', DIARY = '📙 Щоденник і звіт';

export const STAGES = [
  {
    id: 'prep', title: 'До початку практики', date: 'до 29.09',
    steps: [
      { id: 'prep_profile', kind: 'profile', title: 'Заповнити «Мої дані»', hint: 'ПІБ і група — у «Мій акаунт». За ними викладач бачить ваші роботи й результати.' },
      { id: 'prep_rules', kind: 'check', title: 'Ознайомитися з метою й оцінюванням практики', hint: `${MR}: розділ 1 «Загальні положення» і розділ 12 «Оцінювання» (100 балів, допуск — не менше 35 поточних).` },
      { id: 'prep_diary', kind: 'check', title: 'Заповнити титульну сторінку щоденника', hint: `${DIARY}: ПІБ, відділення, форма навчання, курс.` },
    ],
  },
  {
    id: 'd1', title: 'День 1. Історія сигналів. Будова ріжка', date: '29.09 · 4 год ауд. + 6 год сам.', day: 1,
    steps: [
      { id: 'd1_safety', kind: 'check', title: 'Інструктаж з охорони праці', hint: `${DIARY}: підпис у рядку за 29.09; ${MR}: розділ 2 (правило про мундштук).` },
      { id: 'd1_survey', kind: 'check', title: 'Вхідне анкетування', hint: 'Заповнити анкету (5 питань) і здати викладачу.' },
      { id: 'd1_pr', kind: 'submit', group: 'pr', points: 6, title: 'Практична робота № 1', hint: `${TASKS}: «День 1» → «Хід роботи», кроки 1–7: конспект лекції, схема ріжка, станції «Ріжок», «Ритм і ноти», «Слух». Додайте фото сторінок зошита/щоденника.` },
      { id: 'd1_sr', kind: 'submit', group: 'sr', points: 6, fileRequired: true, due: '30.09', title: 'Самостійна робота № 1', hint: 'Конспект 2–3 с. (розділ 3), хронологічна таблиця (≥ 8 етапів), схема ріжка + пам’ятка догляду (8–10 пунктів), есе «Звук, що об’єднує мисливців». Додайте фото або файли.' },
      { id: 'd1_quiz', kind: 'quiz', topics: [1], title: 'Пробний тест «Практика. Тема 1»', hint: 'Пройдіть тест і перегляньте розбір помилок. Результат зарахується автоматично.' },
      { id: 'd1_diary', kind: 'diary', day: 1, title: 'Щоденник: запис за день 1' },
    ],
  },
  {
    id: 'd2', title: 'День 2. Музична грамота. Техніка звуковидобування', date: '30.09 · 4 + 6 год', day: 2,
    steps: [
      { id: 'd2_pr', kind: 'submit', group: 'pr', points: 6, title: 'Практична робота № 2', hint: `${TASKS}: «День 2», кроки 1–7: ноти, таблиця тривалостей, натуральний звукоряд, дихальні вправи, станції.` },
      { id: 'd2_metronome', kind: 'check', action: { type: 'metronome' }, title: 'Ритм «Збір мисливців» під метроном ♩ = 80', hint: 'Навчання → Навчальні тренажери → «Метроном».' },
      { id: 'd2_sr', kind: 'submit', group: 'sr', points: 6, fileRequired: true, due: '01.10', title: 'Самостійна робота № 2', hint: 'По 2 такти в розмірах 2/4, 3/4, 4/4, 6/8; нотний запис 4 сигналів («Привітання», «Збір мисливців», «Початок загону», «Припинити стрільбу») з підписами.' },
      { id: 'd2_quiz', kind: 'quiz', topics: [2, 3], title: 'Пробні тести «Тема 2» і «Тема 3»' },
      { id: 'd2_breath', kind: 'breath', title: 'Дихальні вправи щодня (30.09–04.10)', hint: `${MR}: розділ 6 → «Комплекс дихальних вправ», 15–20 хв щодня. Відмічайте вправи й найдовший видих.` },
      { id: 'd2_diary', kind: 'diary', day: 2, title: 'Щоденник: запис за день 2' },
    ],
  },
  {
    id: 'd3', title: 'День 3. Система мисливських сигналів', date: '01.10 · 4 + 6 год', day: 3,
    steps: [
      { id: 'd3_pr', kind: 'submit', group: 'pr', points: 6, title: 'Практична робота № 3', hint: `${TASKS}: «День 3»: класифікація, таблиця «Керівні сигнали», розучування сигналів, гра «Сигнал – дія».` },
      { id: 'd3_sr', kind: 'submit', group: 'sr', points: 6, fileRequired: true, due: '02.10', title: 'Самостійна робота № 3', hint: 'Картки сигналів (9 керівних + 6 вшанування), власний глосарій (≥ 30 термінів), схема загінного полювання.' },
      { id: 'd3_audio', kind: 'audio', minCount: 3, title: 'Аудіотест — не менше 3 спроб', hint: 'Практика → «Сигнали практики» або Навчання → Тестування → Аудіо тест.' },
      { id: 'd3_cards', kind: 'check', action: { type: 'cards' }, title: 'Повторити терміни на флеш-картках', hint: 'Навчання → Флеш-картки.' },
      { id: 'd3_quiz', kind: 'quiz', topics: [4, 5], title: 'Пробні тести «Тема 4» і «Тема 5»' },
      { id: 'd3_signals', kind: 'signals', title: 'Облік розучених сигналів', hint: 'Позначте, які сигнали ви знаєте, розпізнаєте на слух і виконуєте.' },
      { id: 'd3_diary', kind: 'diary', day: 3, title: 'Щоденник: запис за день 3' },
    ],
  },
  {
    id: 'd4', title: 'День 4. Мисливська культура та етика. Ділова гра', date: '02.10 · 4 + 6 год', day: 4,
    steps: [
      { id: 'd4_safety', kind: 'check', title: 'Цільовий інструктаж', hint: `${DIARY}: підпис за 02.10. Заняття надворі — зручний одяг.` },
      { id: 'd4_pr', kind: 'submit', group: 'pr', points: 6, title: 'Практична робота № 4', hint: `${TASKS}: «День 4»: зламки, ділова гра у своїй ролі, дії за сигналами.` },
      { id: 'd4_sr', kind: 'submit', group: 'sr', points: 6, fileRequired: true, title: 'Самостійна робота № 4', hint: 'Конспект «Етичний кодекс і звичаї мисливця», сценарій полювального дня із сигнальним супроводом.' },
      { id: 'd4_individual', kind: 'submit', points: 0, fileRequired: true, title: 'Індивідуальне завдання', hint: 'Реферат 8–10 с. або презентація 10–12 слайдів (тему погодити з керівником). Враховується в оцінці щоденника і звіту.' },
      { id: 'd4_quiz', kind: 'quiz', topics: [6], title: 'Пробний тест «Тема 6»' },
      { id: 'd4_diary', kind: 'diary', day: 4, title: 'Щоденник: запис за день 4' },
    ],
  },
  {
    id: 'w', title: 'Вихідні 03–04.10. Звіт і підготовка до заліку', date: '03–04.10',
    steps: [
      { id: 'w_selfcheck', kind: 'check', title: 'Питання для самоконтролю', hint: `${MR}: розділ 13 — відповісти на всі питання усно.` },
      { id: 'w_retest', kind: 'retest', topics: [1, 2, 3, 4, 5, 6], threshold: 80, title: 'Повторно: теми 1–6 не менше 80 %', hint: 'Зараховується найкращий результат кожної теми.' },
      { id: 'w_report', kind: 'submit', group: 'report', points: 12, fileRequired: true, title: 'Щоденник і звіт', hint: `${MR}: розділ 11 (вимоги). Звіт 10–15 с. з додатками + скан/фото заповненого щоденника. Здати до заліку.` },
    ],
  },
  {
    id: 'd5', title: 'День 5. Диференційований залік', date: '05.10 · 2 + 3 год', day: 5,
    steps: [
      { id: 'e_theory', kind: 'exam', part: 'theory', group: 'exam', points: 20, title: 'Теоретичний тест (20 питань)', hint: 'Практика → «Ввести код сесії». Бали ставляться автоматично.' },
      { id: 'e_audio', kind: 'exam', part: 'audio', group: 'exam', points: 6, title: 'Аудіотест (10 сигналів)', hint: 'У тій самій сесії. Бал = правильних × 0,6.' },
      { id: 'e_signal', kind: 'teacher', group: 'exam', points: 8, title: 'Виконання сигналу на ріжку', hint: 'Оцінює викладач на заліку (голосом — до 4 балів).' },
      { id: 'e_rhythm', kind: 'teacher', group: 'exam', points: 6, title: 'Читання ритму незнайомого сигналу', hint: 'Оцінює викладач на заліку.' },
      { id: 'd5_diary', kind: 'diary', day: 5, title: 'Щоденник: запис за день 5' },
    ],
  },
];

export const ALL_STEPS = STAGES.flatMap((s) => s.steps.map((st) => ({ ...st, stageId: s.id })));
export const STEP_BY_ID = Object.fromEntries(ALL_STEPS.map((s) => [s.id, s]));
export const MAX_CURRENT = ALL_STEPS.filter((s) => ['pr', 'sr', 'report'].includes(s.group)).reduce((a, s) => a + s.points, 0); // 60
export const MAX_EXAM = ALL_STEPS.filter((s) => s.group === 'exam').reduce((a, s) => a + s.points, 0); // 40
export const ADMISSION_MIN = 35;
export const CONFIRM_KINDS = ['check', 'diary', 'breath', 'signals'];

/** Номер теми з назви «Практика. Тема N. …». */
export function topicNumber(name) {
  const m = /Тема\s+(\d+)/.exec(name || '');
  return m ? Number(m[1]) : null;
}

/** Найкращий відсоток пробного теоретичного тесту для кожної теми (за номером). */
export function bestByTopic(quizResults = []) {
  const best = {};
  for (const r of quizResults) {
    if (r.kind !== 'theory') continue;
    const n = topicNumber(r.topicName);
    if (n == null) continue;
    const p = Number(r.percent ?? (r.total ? Math.round((r.correct / r.total) * 100) : 0));
    if (!(n in best) || p > best[n]) best[n] = p;
  }
  return best;
}

const filled = (v) => typeof v === 'string' && v.trim().length > 0;

export function diaryDone(entry) {
  return !!entry && DIARY_FIELDS.every(([k]) => filled(entry[k]));
}
export function breathDone(table) {
  return !!table && BREATH_DATES.every((d) => {
    const row = table[d];
    return row && Array.isArray(row.ex) && row.ex.some(Boolean);
  });
}
export function signalsDone(table) {
  return !!table && TRACKED_SIGNALS.every((s) => table[s] && SIGNAL_SKILLS.some(([k]) => table[s][k]));
}

/**
 * Статус кроку для студента й викладача.
 * work — practice_work/{uid}; grades — practice_grades/{uid}.grades;
 * ctx — { profile: {fullName, group}, quizResults: [], exam: {theory, audio} | null }.
 * Повертає { state, label, points, max }:
 *   state: todo | done | review | revise | graded | teacher
 *   points — зараховані бали (або null), max — максимум кроку (0 — без балів).
 */
export function stepStatus(step, work = {}, grades = {}, ctx = {}) {
  const max = step.points || 0;
  const g = grades?.[step.id];
  const s = work?.steps?.[step.id] || {};
  // «none» — оцінку скинуто; points: null не рахуємо (Number(null) === 0)
  const graded = !!g && !['revise', 'none'].includes(g.status) && g.points != null && Number.isFinite(Number(g.points));
  const res = (state, label, points = null) => ({ state, label, points, max });
  // відмітку, щоденник і таблиці студента підтверджує викладач; «Не підтверджено»
  // знімається, коли студент змінив пункт після цього (doneAt / submittedAt)
  const confirmStatus = (studentDone, todoLabel) => {
    if (graded) return res('graded', 'Виконано · Підтверджено');
    const touched = Math.max(toMs(s.doneAt), toMs(s.submittedAt));
    if (g?.status === 'revise' && !(touched && g.gradedAt && touched > toMs(g.gradedAt))) return res('revise', 'Не підтверджено');
    return studentDone ? res('review', 'Очікування на підтвердження') : res('todo', todoLabel);
  };

  switch (step.kind) {
    case 'profile':
      return ctx.profile?.fullName && ctx.profile?.group ? res('done', 'Виконано') : res('todo', 'Не виконано');
    case 'check':
      return confirmStatus(s.done, 'Не виконано');
    case 'diary':
      return confirmStatus(diaryDone(work?.diary?.[`d${step.day}`]), 'Не заповнено');
    case 'breath':
      return confirmStatus(breathDone(work?.breath),
        `Заповнено днів: ${BREATH_DATES.filter((d) => work?.breath?.[d]?.ex?.some(Boolean)).length} з ${BREATH_DATES.length}`);
    case 'signals':
      return confirmStatus(signalsDone(work?.signals), 'Не заповнено');
    case 'quiz': {
      const best = bestByTopic(ctx.quizResults);
      const doneN = step.topics.filter((n) => n in best);
      if (doneN.length === step.topics.length) {
        return res('done', `Виконано автоматично · ${step.topics.map((n) => `тема ${n}: ${best[n]} %`).join(', ')}`);
      }
      return res('todo', step.topics.length > 1 ? `Пройдено ${doneN.length} з ${step.topics.length}` : 'Не пройдено');
    }
    case 'retest': {
      const best = bestByTopic(ctx.quizResults);
      const ok = step.topics.filter((n) => (best[n] ?? -1) >= step.threshold);
      return ok.length === step.topics.length
        ? res('done', `Виконано автоматично · усі теми ≥ ${step.threshold} %`)
        : res('todo', `≥ ${step.threshold} %: ${ok.length} з ${step.topics.length} тем`);
    }
    case 'audio': {
      const n = (ctx.quizResults || []).filter((r) => r.kind === 'audio').length;
      return n >= step.minCount ? res('done', `Виконано автоматично · спроб: ${n}`) : res('todo', `Спроб: ${n} з ${step.minCount}`);
    }
    case 'exam': {
      if (graded) return res('graded', `Оцінено: ${Number(g.points)} з ${max} балів`, Number(g.points));
      const p = ctx.exam?.[step.part];
      return p != null ? res('graded', `Автоматично: ${p} з ${max} балів`, p) : res('todo', `Не складено · макс. ${max} балів`);
    }
    case 'teacher':
      return graded ? res('graded', `Оцінено: ${Number(g.points)} з ${max} балів`, Number(g.points))
        : res('teacher', `Оцінює викладач на заліку · макс. ${max} балів`);
    case 'submit': {
      if (graded) {
        return max ? res('graded', `Виконано · Оцінено: ${Number(g.points)} з ${max} балів`, Number(g.points)) : res('graded', 'Виконано · Прийнято');
      }
      if (g?.status === 'revise' && !(s.submittedAt && g.gradedAt && toMs(s.submittedAt) > toMs(g.gradedAt))) {
        return res('revise', 'На доопрацювання');
      }
      if (s.done) {
        return res('review', max ? `Виконано · На перевірці: максимальна кількість балів за завдання ${max} балів` : 'Виконано · На перевірці');
      }
      return res('todo', max ? `Не виконано · макс. ${max} балів` : 'Не виконано');
    }
    default:
      return res('todo', '—');
  }
}

/** Мілісекунди з Timestamp / Date / числа (для порівняння часу здачі й оцінки). */
export function toMs(v) {
  if (!v) return 0;
  if (typeof v === 'number') return v;
  if (v instanceof Date) return v.getTime();
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (typeof v.seconds === 'number') return v.seconds * 1000;
  return 0;
}

/** Підсумок практики: бали за групами, разом, допуск, оцінка, прогрес. */
export function totals(work = {}, grades = {}, ctx = {}) {
  let current = 0, exam = 0, done = 0, review = 0;
  const byGroup = { pr: 0, sr: 0, report: 0, exam: 0 };
  for (const step of ALL_STEPS) {
    const st = stepStatus(step, work, grades, ctx);
    if (['done', 'graded'].includes(st.state) || st.state === 'review') done++;
    if (st.state === 'review') review++;
    if (st.points != null && step.group) {
      byGroup[step.group] += st.points;
      if (step.group === 'exam') exam += st.points; else current += st.points;
    }
  }
  const total = current + exam;
  return {
    current, exam, total, byGroup, review,
    done, count: ALL_STEPS.length,
    admitted: current >= ADMISSION_MIN,
    grade: ectsGrade(total),
  };
}

/** Переведення балів за шкалою коледжу (методичні рекомендації, розділ 12). */
export function ectsGrade(points) {
  if (points >= 90) return { ects: 'A', nat: 'відмінно' };
  if (points >= 82) return { ects: 'B', nat: 'добре' };
  if (points >= 74) return { ects: 'C', nat: 'добре' };
  if (points >= 64) return { ects: 'D', nat: 'задовільно' };
  if (points >= 60) return { ects: 'E', nat: 'задовільно' };
  if (points >= 35) return { ects: 'FX', nat: 'незадовільно (повторне складання)' };
  return { ects: 'F', nat: 'незадовільно (повторне проходження)' };
}

/** Перший невиконаний крок — «Далі». */
export function nextStep(work, grades, ctx) {
  return ALL_STEPS.find((s) => ['todo', 'revise'].includes(stepStatus(s, work, grades, ctx).state)) || null;
}

/** Найкращі бали іспиту з власних спроб/робіт (з урахуванням правок викладача). */
export function bestExam(attempts = [], submissions = []) {
  const subById = new Map(submissions.map((s) => [s.id, s]));
  let best = null;
  for (const a of attempts) {
    if (a.status !== 'submitted') continue;
    const sub = subById.get(`${a.sessionId}_${a.uid}`);
    const theory = sub?.adminTheoryPoints ?? a.theory?.points ?? null;
    const audio = sub?.adminAudioPoints ?? a.audio?.points ?? null;
    const sum = (theory ?? 0) + (audio ?? 0);
    if (!best || sum > best.sum) best = { theory, audio, sum };
  }
  return best ? { theory: best.theory, audio: best.audio } : null;
}
