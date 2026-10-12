// Спільна логіка тестів та іспитів: перемішування, добір питань і сигналів,
// підрахунок балів, CSV. Чисті функції без DOM і Firebase — їх перевіряє
// scripts/site_tests/quiz_core.test.mjs; завантаження з Firestore лишається
// у views/exam.js.

/** Fisher–Yates: нова перемішана копія (sort(() => Math.random() - .5) упереджений). */
export function shuffle(arr, rnd = Math.random) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const identity = (n) => Array.from({ length: n }, (_, i) => i);

/**
 * Перестановка варіантів питання. order[k] — індекс вихідного варіанта, що
 * показується k-м; correct — позиція правильного після перестановки.
 */
export function permuteOptions(q, rnd = Math.random, doShuffle = true) {
  const n = (q.options || []).length;
  const order = doShuffle ? shuffle(identity(n), rnd) : identity(n);
  return { order, options: order.map((i) => q.options[i]), correct: order.indexOf(Number(q.correctIndex) || 0) };
}

/** Варіанти питання в зафіксованому порядку спроби (order може бути відсутнім у старих даних). */
export function orderedOptions(q, order) {
  const opts = q?.options || [];
  return Array.isArray(order) && order.length === opts.length ? order.map((i) => opts[i]) : opts.slice();
}

/** Набір теоретичних питань спроби: [{ qid, order, answer: null }]. */
export function pickTheory(pool, { count, shuffleQuestions = true, shuffleOptions = true } = {}, rnd = Math.random) {
  const usable = pool.filter((q) => q && q.id && Array.isArray(q.options) && q.options.length >= 2);
  const ordered = shuffleQuestions ? shuffle(usable, rnd) : usable.slice();
  const n = Math.max(0, Math.min(count ?? ordered.length, ordered.length));
  return ordered.slice(0, n).map((q) => ({ qid: q.id, order: permuteOptions(q, rnd, shuffleOptions).order, answer: null }));
}

/**
 * Сигнали для аудіочастини: лише з аудіо, без дублікатів аудіофайлу.
 * Джерело — явний список id, тег або (старі сесії додатку) рівень складності.
 */
export function signalPool(signals, { signalIds = null, tag = null, difficulty = null } = {}) {
  const seen = new Set();
  const withAudio = signals.filter((s) => s && s.audioUrl && !seen.has(s.audioUrl) && seen.add(s.audioUrl));
  if (Array.isArray(signalIds) && signalIds.length) {
    const ids = new Set(signalIds);
    return withAudio.filter((s) => ids.has(s.id));
  }
  if (tag) {
    const t = String(tag).trim().toLowerCase();
    return withAudio.filter((s) => (s.tags || []).some((x) => String(x).trim().toLowerCase() === t));
  }
  if (difficulty) return withAudio.filter((s) => s.difficulty === difficulty);
  return withAudio;
}

/**
 * Питання аудіочастини: [{ signalId, options: [4 назви], answer: null }].
 * Хибні варіанти — з того самого пулу, якщо в ньому ≥ 4 різні назви,
 * інакше — з усіх сигналів з аудіо (allWithAudio).
 */
export function buildAudioItems(pool, count, rnd = Math.random, allWithAudio = pool) {
  const names = (list) => [...new Set(list.map((s) => s.name).filter(Boolean))];
  const poolNames = names(pool);
  const distractors = poolNames.length >= 4 ? poolNames : names(allWithAudio.length ? allWithAudio : pool);
  const picked = shuffle(pool, rnd).slice(0, Math.max(0, Math.min(count ?? pool.length, pool.length)));
  return picked.map((s) => {
    const wrongs = shuffle(distractors.filter((n) => n !== s.name), rnd).slice(0, 3);
    return { signalId: s.id, options: shuffle([s.name, ...wrongs], rnd), answer: null };
  });
}

/** Бал частини: round(correct / total × maxPoints); 8/10 × 6 = 4,8 → 5. */
export function scorePart(correct, total, maxPoints) {
  if (!total || !maxPoints) return 0;
  return Math.round(correct / total * maxPoints);
}

/** Правильні відповіді теорії: questionsById — Map або об'єкт qid → питання з correctIndex. */
export function countTheoryCorrect(items, questionsById) {
  const get = (id) => (questionsById instanceof Map ? questionsById.get(id) : questionsById[id]);
  return (items || []).filter((it) => {
    const q = get(it.qid);
    if (!q || it.answer == null) return false;
    const order = Array.isArray(it.order) && it.order.length ? it.order : identity((q.options || []).length);
    return order[it.answer] === (Number(q.correctIndex) || 0);
  }).length;
}

/** Правильні відповіді аудіо: правильна назва — поточна назва сигналу (signalsById). */
export function countAudioCorrect(items, signalsById) {
  const get = (id) => (signalsById instanceof Map ? signalsById.get(id) : signalsById[id]);
  return (items || []).filter((it) => {
    const s = get(it.signalId);
    return !!s && it.answer != null && it.options[it.answer] === s.name;
  }).length;
}

export const answeredCount = (items) => (items || []).filter((it) => it.answer != null).length;

/**
 * Налаштування сесії іспиту з урахуванням старих сесій додатку
 * (exam_models.dart: одна тема theoryTopicId, рівень audioDifficulty).
 */
export function examConfig(s) {
  const topicIds = Array.isArray(s.theoryTopicIds) && s.theoryTopicIds.length
    ? s.theoryTopicIds : (s.theoryTopicId ? [s.theoryTopicId] : []);
  return {
    theory: s.theoryEnabled ? {
      topicIds,
      count: Number(s.theoryQuestionCount) || 10,
      shuffleQuestions: s.theoryShuffleQuestions ?? true,
      shuffleOptions: s.theoryShuffleOptions ?? true,
      maxPoints: Number(s.theoryMaxPoints) || 0,
    } : null,
    audio: s.audioEnabled ? {
      signalIds: Array.isArray(s.audioSignalIds) && s.audioSignalIds.length ? s.audioSignalIds : null,
      tag: s.audioTag || null,
      difficulty: s.audioDifficulty || null,
      count: Number(s.audioQuestionCount) || 10,
      maxPoints: Number(s.audioMaxPoints) || 0,
    } : null,
    file: s.fileEnabled ? { maxPoints: Number(s.fileMaxPoints) || 0, description: s.fileTaskDescription || '' } : null,
    timeLimitMin: Number(s.timeLimitMin) || 0,
    showReview: s.showReview === true,
  };
}

/** Дедлайн спроби: старт + ліміт часу, але не пізніше дедлайну сесії. null — без обмеження. */
export function attemptDeadline(startedAt, timeLimitMin, sessionDeadline) {
  const byLimit = startedAt && timeLimitMin > 0 ? new Date(startedAt.getTime() + timeLimitMin * 60000) : null;
  if (byLimit && sessionDeadline) return byLimit < sessionDeadline ? byLimit : sessionDeadline;
  return byLimit || sessionDeadline || null;
}

/** Поле CSV для Excel: у лапках, якщо містить ';', '"' або перенос рядка. */
export function csvField(v) {
  const s = String(v ?? '');
  return /[;"\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** CSV з BOM (UTF-8 для Excel) і роздільником ';'. */
export function toCsv(rows) {
  return '﻿' + rows.map((r) => r.map(csvField).join(';')).join('\r\n');
}

const pad = (n) => String(n).padStart(2, '0');
/** dd.MM.yyyy HH:mm */
export function fmtDateTime(d) {
  return d ? `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}` : '';
}
