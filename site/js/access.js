// Вхід і право користуватися сайтом — дзеркало AccessService у додатку
// (lib/services/access_service.dart): корпоративна пошта — безкоштовно,
// решта — пробний період від першого входу (серверна дата у users/{uid}),
// код доступу від адміністратора — назавжди або на N днів.
import {
  auth, db, doc, collection, getDoc, getDocFromServer, setDoc, updateDoc, deleteDoc, onSnapshot, query, orderBy,
  runTransaction, serverTimestamp, increment, arrayUnion, Timestamp,
  onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword,
  sendEmailVerification, sendPasswordResetEmail, signOut,
} from './firebase.js';

const CACHE_KEY = 'access_status_v1';
const CONFIG_REF = () => doc(db, 'app_access', 'config');

// ── Налаштування ─────────────────────────────────────────────────────────────

export const DEFAULT_CONFIG = {
  corporateDomains: ['forestcollege.ukr.education'],
  trialDays: 30,
  adminEmails: ['volcovskij@forestcollege.ukr.education'],
};
let config = { ...DEFAULT_CONFIG };
export const getConfig = () => config;

function normalizeConfig(d) {
  if (!d) return { ...DEFAULT_CONFIG };
  const strings = (v, fb) => (Array.isArray(v) ? v.map((x) => String(x).trim().toLowerCase()).filter(Boolean) : fb);
  const trial = Number(d.trialDays);
  return {
    corporateDomains: strings(d.corporateDomains, DEFAULT_CONFIG.corporateDomains),
    trialDays: trial > 0 ? Math.round(trial) : DEFAULT_CONFIG.trialDays,
    adminEmails: strings(d.adminEmails, DEFAULT_CONFIG.adminEmails),
  };
}

export async function loadConfig(fromServer = false) {
  try {
    const snap = await (fromServer ? getDocFromServer(CONFIG_REF()) : getDoc(CONFIG_REF()));
    config = normalizeConfig(snap.exists() ? snap.data() : null);
  } catch (e) { console.warn('access: config unavailable, using defaults', e); }
  return config;
}

export async function saveConfig(cfg) {
  await setDoc(CONFIG_REF(), cfg, { merge: true });
  config = normalizeConfig(cfg);
}

export const emailDomain = (email) => {
  const at = (email || '').lastIndexOf('@');
  return at < 0 ? null : email.slice(at + 1).trim().toLowerCase();
};
export const isCorporate = (email) => config.corporateDomains.includes(emailDomain(email));
export const isAdminEmail = (email) => config.adminEmails.includes((email || '').trim().toLowerCase());

// ── Автентифікація ───────────────────────────────────────────────────────────

export const currentUser = () => auth.currentUser;
export const onAuthChange = (cb) => onAuthStateChanged(auth, cb);

export class AccessError extends Error {}

export function describeAuthError(e) {
  switch (e?.code) {
    case 'auth/invalid-email': return 'Некоректна адреса пошти';
    case 'auth/user-disabled': return 'Обліковий запис заблоковано';
    case 'auth/user-not-found':
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
    case 'auth/invalid-login-credentials': return 'Неправильна пошта або пароль';
    case 'auth/email-already-in-use': return 'Ця пошта вже зареєстрована — увійдіть';
    case 'auth/weak-password': return 'Пароль надто простий (мінімум 6 символів)';
    case 'auth/too-many-requests': return 'Забагато спроб. Спробуйте пізніше';
    case 'auth/network-request-failed': return 'Немає з’єднання з інтернетом';
    case 'auth/operation-not-allowed': return 'Вхід за поштою не ввімкнено у Firebase';
    case 'auth/unauthorized-domain': return 'Цей домен сайту не дозволено у Firebase Authentication';
    default: return e?.message || 'Помилка входу';
  }
}
const wrap = async (fn) => { try { return await fn(); } catch (e) { throw new AccessError(describeAuthError(e)); } };

export const signIn = (email, password) => wrap(() => signInWithEmailAndPassword(auth, email.trim(), password));
export const register = (email, password) => wrap(async () => {
  const cred = await createUserWithEmailAndPassword(auth, email.trim(), password);
  await sendEmailVerification(cred.user);
});
export const resendVerification = () => wrap(() => auth.currentUser && sendEmailVerification(auth.currentUser));
export const resetPassword = (email) => wrap(() => sendPasswordResetEmail(auth, email.trim()));
export async function reloadVerified() {
  const u = auth.currentUser;
  if (!u) return false;
  try { await u.reload(); } catch { return false; }
  return !!auth.currentUser?.emailVerified;
}
export async function logout() {
  publish(null);
  try { localStorage.removeItem(CACHE_KEY); } catch { /* ignore */ }
  await signOut(auth);
}

// ── Статус доступу ───────────────────────────────────────────────────────────
// { kind: 'corporate'|'code'|'trial'|'expired', until: Date|null, fromCache }

let status = null;
const listeners = new Set();
export const getStatus = () => status;
export function onStatus(cb) { listeners.add(cb); return () => listeners.delete(cb); }
function publish(s) { status = s; listeners.forEach((l) => l(s)); return s; }

export const allowed = (s) => !!s && s.kind !== 'expired';
export function daysLeft(s) {
  if (!s?.until) return -1;
  const ms = s.until.getTime() - Date.now();
  return ms < 0 ? 0 : Math.ceil(ms / 86400000);
}
export const fmtDate = (d) => d.toLocaleDateString('uk-UA', { day: '2-digit', month: '2-digit', year: 'numeric' });

let serverOffset = 0; // сервер − пристрій, мс
export const serverNow = () => new Date(Date.now() + serverOffset);

export async function resolve() {
  const user = auth.currentUser;
  if (!user || !user.emailVerified) return publish({ kind: 'expired', until: null });
  try {
    const s = await resolveOnline(user);
    writeCache(user.uid, s);
    return publish(s);
  } catch (e) {
    console.warn('access: online check failed', e);
    const cached = readCache(user.uid);
    if (cached) {
      if (cached.until && cached.until < new Date()) return publish({ kind: 'expired', until: cached.until, fromCache: true });
      return publish(cached);
    }
    throw new AccessError('Не вдалося перевірити доступ. Перевірте з’єднання з інтернетом');
  }
}

async function resolveOnline(user) {
  await loadConfig();
  const email = (user.email || '').trim().toLowerCase();
  if (isCorporate(email) || isAdminEmail(email)) {
    try { await touchUser(user, false); } catch { /* без мережі — не заважає */ }
    return { kind: 'corporate', until: null };
  }
  const data = await touchUser(user, true);
  const createdAt = data.createdAt?.toDate?.();
  const lastSeen = data.lastSeenAt?.toDate?.();
  if (lastSeen) serverOffset = lastSeen.getTime() - Date.now();
  const now = serverNow();

  if (data.accessType === 'code') {
    const until = data.accessUntil?.toDate?.() || null;
    if (!until) return { kind: 'code', until: null };
    if (until > now) return { kind: 'code', until };
  }
  const start = createdAt || now;
  const trialEnd = new Date(start.getTime() + config.trialDays * 86400000);
  return trialEnd > now ? { kind: 'trial', until: trialEnd } : { kind: 'expired', until: trialEnd };
}

/** users/{uid}: створює при першому вході або оновлює lastSeenAt; повертає серверні дані. */
async function touchUser(user, needRead) {
  const ref = doc(db, 'users', user.uid);
  const email = (user.email || '').trim().toLowerCase();
  const snap = await getDocFromServer(ref);
  if (!snap.exists()) {
    await setDoc(ref, { email, createdAt: serverTimestamp(), lastSeenAt: serverTimestamp(), accessType: 'trial' });
  } else {
    await updateDoc(ref, { email, lastSeenAt: serverTimestamp() });
  }
  if (!needRead) return {};
  return (await getDocFromServer(ref)).data() || {};
}

function writeCache(uid, s) {
  try { localStorage.setItem(CACHE_KEY, JSON.stringify({ uid, kind: s.kind, until: s.until ? s.until.getTime() : null })); } catch { /* ignore */ }
}
function readCache(uid) {
  try {
    const j = JSON.parse(localStorage.getItem(CACHE_KEY) || 'null');
    if (!j || j.uid !== uid) return null;
    return { kind: j.kind, until: j.until ? new Date(j.until) : null, fromCache: true };
  } catch { return null; }
}

// ── Коди доступу ─────────────────────────────────────────────────────────────

const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // без схожих 0/O, 1/I/L
export function generateCode(length = 8) {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return [...bytes].map((b) => ALPHABET[b % ALPHABET.length]).join('');
}
export const normalizeCode = (raw) => (raw || '').trim().toUpperCase().replace(/[\s-]/g, '');

export function codeFromDoc(d) {
  const x = d.data() || {};
  const dur = Number(x.durationDays);
  return {
    code: d.id, note: x.note || '',
    maxUses: Number.isFinite(Number(x.maxUses)) ? Number(x.maxUses) : 1,
    usedCount: Number(x.usedCount) || 0,
    usedBy: Array.isArray(x.usedBy) ? x.usedBy : [],
    usedByEmails: Array.isArray(x.usedByEmails) ? x.usedByEmails : [],
    durationDays: dur > 0 ? Math.round(dur) : null,
    expiresAt: x.expiresAt?.toDate?.() || null,
    active: x.active !== false,
    createdAt: x.createdAt?.toDate?.() || null,
  };
}
export const codeExhausted = (c) => c.maxUses > 0 && c.usedCount >= c.maxUses;
export const codeExpired = (c) => !!c.expiresAt && c.expiresAt < new Date();
export const codeUsable = (c) => c.active && !codeExhausted(c) && !codeExpired(c);

/** Активує код для поточного користувача (транзакція, як у додатку). */
export async function redeemCode(raw) {
  const user = auth.currentUser;
  if (!user || !user.emailVerified) throw new AccessError('Спочатку увійдіть на сайт');
  const code = normalizeCode(raw);
  if (!code) throw new AccessError('Введіть код');
  const codeRef = doc(db, 'access_codes', code);
  const userRef = doc(db, 'users', user.uid);
  const email = (user.email || '').trim().toLowerCase();
  try {
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(codeRef);
      if (!snap.exists()) throw new AccessError('Код не знайдено');
      const c = codeFromDoc(snap);
      const now = serverNow();
      if (!c.active) throw new AccessError('Код деактивовано адміністратором');
      if (c.expiresAt && c.expiresAt < now) throw new AccessError('Термін дії коду минув');
      const already = c.usedBy.includes(user.uid);
      if (!already && codeExhausted(c)) throw new AccessError('Код уже використано максимальну кількість разів');
      if (!already) {
        tx.update(codeRef, { usedCount: increment(1), usedBy: arrayUnion(user.uid), usedByEmails: arrayUnion(email) });
      }
      const until = c.durationDays == null ? null : new Date(now.getTime() + c.durationDays * 86400000);
      tx.set(userRef, {
        email, accessType: 'code', codeId: code, codeActivatedAt: serverTimestamp(),
        accessUntil: until ? Timestamp.fromDate(until) : null,
      }, { merge: true });
    });
  } catch (e) {
    if (e instanceof AccessError) throw e;
    if (e?.code === 'permission-denied') throw new AccessError('Код відхилено правилами доступу. Зверніться до адміністратора');
    throw new AccessError(`Не вдалося активувати код: ${e?.message || e}`);
  }
  return resolve();
}

// ── Адміністрування кодів ────────────────────────────────────────────────────

export function subscribeCodes(cb, onError) {
  return onSnapshot(query(collection(db, 'access_codes'), orderBy('createdAt', 'desc')),
    (snap) => cb(snap.docs.map(codeFromDoc)), onError);
}
export async function createCode(c) {
  const ref = doc(db, 'access_codes', c.code);
  if ((await getDoc(ref)).exists()) throw new AccessError(`Код ${c.code} уже існує`);
  await setDoc(ref, {
    code: c.code, note: c.note || '', maxUses: c.maxUses ?? 1, usedCount: 0, usedBy: [], usedByEmails: [],
    durationDays: c.durationDays ?? null, expiresAt: c.expiresAt ? Timestamp.fromDate(c.expiresAt) : null,
    active: true, createdAt: serverTimestamp(),
  });
}
export const setCodeActive = (code, active) => updateDoc(doc(db, 'access_codes', code), { active });
export const deleteCode = (code) => deleteDoc(doc(db, 'access_codes', code));
