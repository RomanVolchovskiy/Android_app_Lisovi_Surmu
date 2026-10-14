// Дані розділу «Практика»: робота студента (practice_work/{uid}), оцінки
// викладача (practice_grades/{uid}), файли (Storage practice_uploads/{uid}/…),
// а також автоматичні джерела — quiz_results та іспит (exam_attempts/submissions).
import {
  db, auth, storage, collection, doc, getDoc, getDocs, setDoc, query, where, serverTimestamp,
  storageRef, uploadBytes, getDownloadURL, deleteObject,
} from './firebase.js';
import { getProfile } from './access.js';
import { ATTEMPTS, SUBMISSIONS } from './exam-data.js';
import { bestExam } from './practice-core.js';

export const WORK = 'practice_work';
export const GRADES = 'practice_grades';
export const MAX_FILE = 20 * 1024 * 1024;
export const FILE_ACCEPT = 'image/*,.pdf,.doc,.docx,.odt,.ppt,.pptx,.odp,.txt';
const MIME = {
  pdf: 'application/pdf', doc: 'application/msword', txt: 'text/plain',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  ppt: 'application/vnd.ms-powerpoint',
  odt: 'application/vnd.oasis.opendocument.text', odp: 'application/vnd.oasis.opendocument.presentation',
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', heic: 'image/heic', webp: 'image/webp',
};

const rows = (snap) => snap.docs.map((d) => ({ id: d.id, ...d.data() }));

/** Тип файлу: браузер іноді не знає DOCX/HEIC — тоді за розширенням. */
export function contentTypeOf(file) {
  if (file.type) return file.type;
  const ext = (file.name.split('.').pop() || '').toLowerCase();
  return MIME[ext] || '';
}

/** Пробні тести й іспит конкретного студента (для автоматичних кроків). */
async function autoSources(uid) {
  const [qr, attempts] = await Promise.all([
    getDocs(query(collection(db, 'quiz_results'), where('uid', '==', uid))).then(rows).catch(() => []),
    getDocs(query(collection(db, ATTEMPTS), where('uid', '==', uid))).then(rows).catch(() => []),
  ]);
  const submitted = attempts.filter((a) => a.status === 'submitted');
  const subs = (await Promise.all(submitted.map((a) => getDoc(doc(db, SUBMISSIONS, `${a.sessionId}_${a.uid}`))
    .then((d) => (d.exists() ? { id: d.id, ...d.data() } : null)).catch(() => null)))).filter(Boolean);
  return { quizResults: qr, exam: bestExam(attempts, subs) };
}

/** Усе для екрана студента. */
export async function loadMyPractice() {
  const user = auth.currentUser;
  if (!user) throw new Error('Увійдіть в акаунт');
  const [profile, work, grades, auto] = await Promise.all([
    getProfile().catch(() => ({ fullName: '', group: '' })),
    getDoc(doc(db, WORK, user.uid)).then((d) => d.data() || {}),
    getDoc(doc(db, GRADES, user.uid)).then((d) => d.data()?.grades || {}),
    autoSources(user.uid),
  ]);
  return { uid: user.uid, email: user.email, profile, work, grades, ctx: { profile, ...auto } };
}

/**
 * Зберегти частину роботи (merge). patch — { steps: {id: {...}} } / { diary: {...} } тощо.
 * Разом з нею — ПІБ і група, щоб викладач бачив, чия робота.
 */
export async function saveWork(patch, profile = {}) {
  const user = auth.currentUser;
  if (!user) throw new Error('Увійдіть в акаунт');
  await setDoc(doc(db, WORK, user.uid), {
    ...patch,
    uid: user.uid, email: user.email || '', fullName: profile.fullName || '', group: profile.group || '',
    updatedAt: serverTimestamp(),
  }, { merge: true });
}

/** Завантажити файл кроку у власну теку; повертає опис для steps[id].files. */
export async function uploadStepFile(stepId, file) {
  const user = auth.currentUser;
  if (!user) throw new Error('Увійдіть в акаунт');
  if (file.size > MAX_FILE) throw new Error(`Файл «${file.name}» більший за 20 МБ`);
  const type = contentTypeOf(file);
  if (!/^image\/|^application\/(pdf|msword|vnd\.openxmlformats|vnd\.oasis|vnd\.ms-powerpoint)|^text\/plain/.test(type)) {
    throw new Error(`Формат «${file.name}» не підтримується. Можна фото, PDF, DOC/DOCX, ODT, PPT/PPTX, TXT`);
  }
  const safe = file.name.replace(/[^\p{L}\p{N}._-]+/gu, '_').slice(-80);
  const path = `practice_uploads/${user.uid}/${stepId}/${Date.now()}_${safe}`;
  const r = storageRef(storage, path);
  await uploadBytes(r, file, { contentType: type });
  return { name: file.name, path, url: await getDownloadURL(r), size: file.size, type, at: Date.now() };
}

export async function deleteStepFile(meta) {
  try { await deleteObject(storageRef(storage, meta.path)); } catch (e) {
    if (e?.code !== 'storage/object-not-found') throw e;
  }
}

// ── Адміністратор ────────────────────────────────────────────────────────────

/** Усі студенти: роботи, оцінки, профілі (users з групою) — для журналу. */
export async function loadAllPractice() {
  const [works, grades, users, qr, attempts, subs] = await Promise.all([
    getDocs(collection(db, WORK)).then(rows),
    getDocs(collection(db, GRADES)).then(rows),
    getDocs(collection(db, 'users')).then(rows).catch(() => []),
    getDocs(collection(db, 'quiz_results')).then(rows).catch(() => []),
    getDocs(collection(db, ATTEMPTS)).then(rows).catch(() => []),
    getDocs(collection(db, SUBMISSIONS)).then(rows).catch(() => []),
  ]);
  const byUid = new Map();
  const ensure = (uid) => {
    if (!byUid.has(uid)) byUid.set(uid, { uid, work: {}, grades: {}, profile: { fullName: '', group: '' }, email: '' });
    return byUid.get(uid);
  };
  // студенти — ті, хто почав практику, або заповнив групу в «Мої дані»
  users.filter((u) => (u.group || '').trim()).forEach((u) => {
    const s = ensure(u.id);
    s.profile = { fullName: u.fullName || '', group: u.group || '' };
    s.email = u.email || '';
  });
  works.forEach((w) => {
    const s = ensure(w.id);
    s.work = w;
    s.email ||= w.email || '';
    if (!s.profile.fullName) s.profile = { fullName: w.fullName || '', group: w.group || '' };
  });
  grades.forEach((g) => { if (byUid.has(g.id)) byUid.get(g.id).grades = g.grades || {}; });
  for (const s of byUid.values()) {
    const myAttempts = attempts.filter((a) => a.uid === s.uid);
    s.ctx = {
      profile: s.profile,
      quizResults: qr.filter((r) => r.uid === s.uid),
      exam: bestExam(myAttempts, subs.filter((x) => x.uid === s.uid)),
    };
  }
  return [...byUid.values()].sort((a, b) => (a.profile.group || '').localeCompare(b.profile.group || '', 'uk')
    || (a.profile.fullName || a.email).localeCompare(b.profile.fullName || b.email, 'uk'));
}

/** Оцінка кроку: { points, comment, status: 'graded' | 'revise' | 'none' }. */
export async function saveGrade(uid, stepId, { points = null, comment = '', status = 'graded' }) {
  await setDoc(doc(db, GRADES, uid), {
    uid,
    grades: { [stepId]: { points, comment: comment || '', status, gradedAt: serverTimestamp(), by: auth.currentUser?.email || '' } },
    updatedAt: serverTimestamp(),
  }, { merge: true });
}

/** Свіжі дані одного студента (після оцінювання). */
export async function loadStudentPractice(uid) {
  const [work, grades, user, auto] = await Promise.all([
    getDoc(doc(db, WORK, uid)).then((d) => d.data() || {}),
    getDoc(doc(db, GRADES, uid)).then((d) => d.data()?.grades || {}),
    getDoc(doc(db, 'users', uid)).then((d) => d.data() || {}).catch(() => ({})),
    autoSources(uid),
  ]);
  const profile = { fullName: user.fullName || work.fullName || '', group: user.group || work.group || '' };
  return { uid, email: user.email || work.email || '', work, grades, profile, ctx: { profile, ...auto } };
}
