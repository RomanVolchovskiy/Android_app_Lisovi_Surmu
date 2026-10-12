// Історія пробних тестів (ТЗ практики, розділ 4): quiz_results/{autoId}.
// Пише студент після завершення пробного тесту; читає він сам (картка
// «Мої результати») і адміністратор («Управління іспитами» → «Пробні тести»).
// Запити без складених індексів: студент — лише where uid, адмін — лише
// діапазон createdAt; решта фільтрів і сортування — на клієнті.
import {
  db, auth, collection, doc, getDocs, setDoc, query, where, orderBy, serverTimestamp, Timestamp,
} from './firebase.js';
import { getProfile } from './access.js';

export const QUIZ_RESULTS = 'quiz_results';
const toDate = (v) => (v?.toDate ? v.toDate() : v ? new Date(v) : null);

/**
 * meta: { kind: 'theory'|'audio', topicId, topicName, audioFilter }.
 * Помилка запису не заважає студенту — лише console.warn.
 */
export async function saveQuizResult(meta, correct, total) {
  const user = auth.currentUser;
  if (!user || !total) return;
  try {
    const profile = await getProfile().catch(() => ({}));
    await setDoc(doc(collection(db, QUIZ_RESULTS)), {
      uid: user.uid,
      email: (user.email || '').toLowerCase(),
      fullName: profile?.fullName || '',
      group: profile?.group || '',
      kind: meta.kind,
      topicId: meta.topicId ?? null,
      topicName: meta.topicName || '',
      audioFilter: meta.audioFilter ?? null,
      correct, total, percent: Math.round(correct / total * 100),
      createdAt: serverTimestamp(),
    });
  } catch (e) { console.warn('quiz_results', e); }
}

const rowOf = (d) => ({ id: d.id, ...d.data(), createdAt: toDate(d.data().createdAt) });
const newestFirst = (a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0);

/** Останні 50 результатів поточного користувача. */
export async function myQuizResults() {
  const user = auth.currentUser;
  if (!user) return [];
  const snap = await getDocs(query(collection(db, QUIZ_RESULTS), where('uid', '==', user.uid)));
  return snap.docs.map(rowOf).sort(newestFirst).slice(0, 50);
}

/** Адмін: результати за період [from, to). */
export async function quizResultsBetween(from, to) {
  const snap = await getDocs(query(collection(db, QUIZ_RESULTS),
    where('createdAt', '>=', Timestamp.fromDate(from)), where('createdAt', '<', Timestamp.fromDate(to)), orderBy('createdAt', 'desc')));
  return snap.docs.map(rowOf);
}

/** Назва тесту для таблиць. */
export function quizTitle(r) {
  if (r.kind === 'audio') return `Аудіотест: ${r.topicName || 'усі сигнали'}`;
  return r.topicName || 'Теоретичний тест';
}
