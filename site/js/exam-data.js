// Дані іспитів у Firestore — спільне для студента (views/exam.js) і
// адміністратора (views/admin-exams.js).
//
//   exam_sessions/{id}      — сесія; поля exam_models.dart (додаток) + нові
//                             необов'язкові: group, timeLimitMin, startsAt,
//                             showReview, theoryTopicIds, theoryShuffle*,
//                             audioTag, audioSignalIds. Нові сесії мають id = код.
//   exam_attempts/{sid_uid} — спроба студента: зафіксований набір питань,
//                             відповіді, час; одна на студента.
//   exam_submissions/{sid_uid} — підсумок у форматі ExamSubmission, щоб
//                             результати бачила й адмін-панель додатку.
//                             Пишеться в одному батчі зі здачею спроби.
import {
  db, collection, doc, getDocs, getDocFromServer, query, where, limit, writeBatch, serverTimestamp,
} from './firebase.js';
import { waitForSignals } from './data.js';
import { examConfig, countTheoryCorrect, countAudioCorrect, scorePart } from './quiz-core.js';
import { bySortOrder } from './csv-import.js';

export const SESSIONS = 'exam_sessions';
export const ATTEMPTS = 'exam_attempts';
export const SUBMISSIONS = 'exam_submissions';
export const PRACTICE_TAG = 'практика';

export const toDate = (v) => (v?.toDate ? v.toDate() : v ? new Date(v) : null);
export const attemptIdOf = (sessionId, uid) => `${sessionId}_${uid}`;
export const attemptRef = (sessionId, uid) => doc(db, ATTEMPTS, attemptIdOf(sessionId, uid));

const withId = (d) => ({ ...d.data(), id: d.data().id || d.id });

/** Сесія за кодом: спершу документ з id = код, потім (старі сесії) запит за полем code. */
export async function findSession(code) {
  const direct = await getDocFromServer(doc(db, SESSIONS, code));
  if (direct.exists()) return withId(direct);
  const snap = await getDocs(query(collection(db, SESSIONS), where('code', '==', code), limit(1)));
  return snap.empty ? null : withId(snap.docs[0]);
}

/** Питання вибраних тем — без кешу; 'in' приймає не більше 10 значень. */
export async function loadQuestionPool(topicIds) {
  const ids = [...new Set(topicIds || [])];
  const out = [];
  for (let i = 0; i < ids.length; i += 10) {
    const snap = await getDocs(query(collection(db, 'edu_test_questions'), where('topicId', 'in', ids.slice(i, i + 10))));
    snap.docs.forEach((d) => out.push({ ...d.data(), id: d.id }));
  }
  const rank = new Map(ids.map((id, i) => [id, i]));
  return out.sort((a, b) => (rank.get(a.topicId) - rank.get(b.topicId))
    || bySortOrder(a, b));
}

/** Усе, що потрібно для показу й оцінювання спроби: питання і сигнали за id. */
export async function loadExamKeys(session) {
  const cfg = examConfig(session);
  const [questions, signals] = await Promise.all([
    cfg.theory ? loadQuestionPool(cfg.theory.topicIds) : [],
    waitForSignals(),
  ]);
  return {
    questions, signals,
    questionsById: new Map(questions.map((q) => [q.id, q])),
    signalsById: new Map(signals.map((s) => [s.id, s])),
  };
}

/** Бали спроби (правильність рахується лише тут — у спробі до здачі її немає). */
export function scoreAttempt(session, attempt, keys) {
  const cfg = examConfig(session);
  const part = (p, items, correct, maxPoints) => (p ? {
    ...p, correct, total: items.length, points: scorePart(correct, items.length, maxPoints),
  } : null);
  const theory = part(attempt.theory, attempt.theory?.items || [],
    countTheoryCorrect(attempt.theory?.items, keys.questionsById), cfg.theory?.maxPoints ?? 0);
  const audio = part(attempt.audio, attempt.audio?.items || [],
    countAudioCorrect(attempt.audio?.items, keys.signalsById), cfg.audio?.maxPoints ?? 0);
  return { theory, audio, totalPoints: (theory?.points ?? 0) + (audio?.points ?? 0) };
}

/**
 * Здача: спроба → submitted + підсумок у exam_submissions (формат додатку).
 * Викликає студент (своя спроба) або адміністратор («Примусово здати»).
 */
export async function submitAttempt(session, attempt, keys, { auto = false, byAdmin = false } = {}) {
  const scored = scoreAttempt(session, attempt, keys);
  const id = attemptIdOf(attempt.sessionId, attempt.uid);
  const batch = writeBatch(db);
  batch.update(doc(db, ATTEMPTS, id), {
    status: 'submitted',
    submittedAt: serverTimestamp(),
    theory: scored.theory,
    audio: scored.audio,
    totalPoints: scored.totalPoints,
    autoSubmitted: auto,
    ...(byAdmin ? { forcedByAdmin: true } : {}),
  });
  batch.set(doc(db, SUBMISSIONS, id), {
    id, sessionId: attempt.sessionId, sessionCode: attempt.sessionCode,
    studentName: attempt.fullName || attempt.email || '—',
    submittedAt: serverTimestamp(),
    theoryCorrect: scored.theory?.correct ?? 0, theoryTotal: scored.theory?.total ?? 0,
    theoryAutoPoints: scored.theory?.points ?? 0, adminTheoryPoints: null,
    audioCorrect: scored.audio?.correct ?? 0, audioTotal: scored.audio?.total ?? 0,
    audioAutoPoints: scored.audio?.points ?? 0, adminAudioPoints: null,
    fileUrl: attempt.file?.fileUrl ?? null, fileName: attempt.file?.fileName ?? null, adminFilePoints: null,
    adminNote: null, status: 'pending',
    // поля сайту (додаток їх ігнорує)
    uid: attempt.uid, email: attempt.email || null, group: attempt.group || null, attemptId: id,
  });
  await batch.commit();
  return { ...attempt, ...scored, status: 'submitted', autoSubmitted: auto, submittedAt: new Date() };
}

/** Зрозумілий текст помилки Firestore українською. */
export function errorText(e) {
  if (e?.code === 'permission-denied') return 'Немає доступу. Перевірте, що ви увійшли і підтвердили пошту';
  if (e?.code === 'unavailable') return 'Немає зв’язку з сервером. Перевірте інтернет';
  return `Помилка: ${e?.message || e}`;
}
