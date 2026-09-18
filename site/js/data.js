// Дані: сигнали, категорії (Firestore), обране та плейлисти (localStorage —
// як SharedPreferences у додатку).
import {
  db, collection, doc, getDocs, setDoc, deleteDoc, onSnapshot, writeBatch,
  storage, storageRef, uploadBytes, getDownloadURL,
} from './firebase.js';

// Категорії — ті самі, що в HuntingDataService.getCategories().
export const CATEGORIES = [
  { id: '1', name: 'Інформаційні', description: 'Сигнали для передачі інформації', icon: 'info', color: '#2196F3' },
  { id: '2', name: 'Організаційні', description: 'Сигнали для організації полювання', icon: 'group', color: '#4CAF50' },
  { id: '3', name: 'Сигнали покоту', description: 'Сигнали для полювання з гончими', icon: 'pets', color: '#FF9800' },
  { id: '4', name: 'Святково-церемоніальні', description: 'Сигнали для святкових та церемоніальних подій', icon: 'celebration', color: '#9C27B0' },
  { id: '5', name: 'Довільні', description: 'Довільні мисливські сигнали', icon: 'music_note', color: '#009688' },
];

export const ALL_CATEGORIES = 'Всі категорії';

const listeners = new Set();
let signals = [];
let loaded = false;

function normalize(id, d) {
  return {
    id: d.id?.toString() || id,
    name: d.name || '',
    description: d.description || '',
    category: d.category || '',
    audioUrl: d.audioUrl || null,
    videoUrl: d.videoUrl || null,
    videoUrl2: d.videoUrl2 || null,
    notationUrl: d.notationUrl || null,
    notationAudioUrl: d.notationAudioUrl || null,
    imageUrl: d.imageUrl || null,
    galleryImages: Array.isArray(d.galleryImages) ? d.galleryImages.filter(Boolean) : [],
    duration: Number(d.duration) || 0,
    tags: Array.isArray(d.tags) ? d.tags : [],
    historicalInfo: d.historicalInfo || null,
    usageInstructions: d.usageInstructions || null,
    difficulty: d.difficulty || null,
    signalText: d.signalText || null,
    notationData: Array.isArray(d.notationData) ? d.notationData : [],
    notationTempo: d.notationTempo != null ? Number(d.notationTempo) : null,
    sortOrder: Number(d.sortOrder) || 0,
    partitureUrl: d.partitureUrl || null,
  };
}

/** Підписка на сигнали в реальному часі (як signalsStream у додатку). */
export function subscribeSignals(cb) {
  listeners.add(cb);
  if (loaded) cb(signals);
  if (listeners.size === 1) {
    onSnapshot(collection(db, 'signals'), (snap) => {
      signals = snap.docs.map((s) => normalize(s.id, s.data()))
        .sort((a, b) => a.sortOrder - b.sortOrder);
      loaded = true;
      listeners.forEach((l) => l(signals));
    }, (err) => console.error('signals stream', err));
  }
  return () => listeners.delete(cb);
}

export function getSignals() { return signals; }
export function getSignal(id) { return signals.find((s) => s.id === id) || null; }

export async function waitForSignals() {
  if (loaded) return signals;
  return new Promise((res) => {
    const off = subscribeSignals((list) => { off(); res(list); });
  });
}

// ── Адмін: запис сигналів ────────────────────────────────────────────────────

export async function saveSignal(signal) {
  const data = { ...signal };
  Object.keys(data).forEach((k) => { if (data[k] === undefined) data[k] = null; });
  await setDoc(doc(db, 'signals', signal.id), data);
}

export async function deleteSignal(id) {
  await deleteDoc(doc(db, 'signals', id));
}

export async function reorderSignals(orderedIds) {
  const batch = writeBatch(db);
  orderedIds.forEach((id, i) => batch.update(doc(db, 'signals', id), { sortOrder: i }));
  await batch.commit();
}

// ── Медіа у Firebase Storage (MediaStorageService) ───────────────────────────

const CONTENT_TYPES = {
  mp3: 'audio/mpeg', m4a: 'audio/mp4', aac: 'audio/mp4', ogg: 'audio/ogg', wav: 'audio/wav',
  png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp', gif: 'image/gif',
  mp4: 'video/mp4', webm: 'video/webm', mov: 'video/quicktime',
};
export const AUDIO_EXT = ['mp3', 'm4a', 'aac', 'ogg', 'wav'];
export const IMAGE_EXT = ['png', 'jpg', 'jpeg', 'webp', 'gif'];
export const VIDEO_EXT = ['mp4', 'webm', 'mov'];

export async function uploadMedia(folder, file) {
  const ext = (file.name.split('.').pop() || '').toLowerCase();
  const safe = file.name.trim().replace(/[^\w.\-]+/gu, '_') || 'file';
  const path = `signals/${folder}/${Date.now()}_${safe}`;
  const ref = storageRef(storage, path);
  await uploadBytes(ref, file, { contentType: CONTENT_TYPES[ext] || file.type || 'application/octet-stream' });
  return getDownloadURL(ref);
}

// ── Посилання на медіа ───────────────────────────────────────────────────────

export function isYouTube(url) {
  return /youtube\.com\/(watch|shorts|embed)|youtu\.be\//.test(url || '');
}
export function youTubeId(url) {
  const m = (url || '').match(/(?:youtu\.be\/|shorts\/|embed\/|[?&]v=)([A-Za-z0-9_-]{11})/);
  return m ? m[1] : null;
}
export function driveId(url) {
  const m = (url || '').match(/drive\.google\.com\/file\/d\/([^/?]+)/)
    || (url || '').match(/lh3\.googleusercontent\.com\/d\/([^/?]+)/)
    || (url || '').match(/[?&]id=([^&]+)/);
  return m ? m[1] : null;
}
/** Storage-URL віддаємо як є; застарілі Drive-посилання — на download-URL. */
export function mediaUrl(url) {
  if (!url) return null;
  const id = driveId(url);
  if (!id || url.includes('firebasestorage')) return url;
  return `https://drive.usercontent.google.com/download?id=${id}&export=download&authuser=0&confirm=t`;
}

// ── Обране (favorite_signals) ────────────────────────────────────────────────

const FAV_KEY = 'favorite_signals';
const favListeners = new Set();
function readJson(key, fallback) {
  try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; } catch { return fallback; }
}
function writeJson(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* приватний режим */ }
}
export function getFavorites() { return readJson(FAV_KEY, []); }
export function isFavorite(id) { return getFavorites().includes(id); }
export function toggleFavorite(id) {
  const list = getFavorites();
  const i = list.indexOf(id);
  if (i >= 0) list.splice(i, 1); else list.push(id);
  writeJson(FAV_KEY, list);
  favListeners.forEach((l) => l(list));
  return i < 0;
}
export function onFavoritesChange(cb) { favListeners.add(cb); return () => favListeners.delete(cb); }

// ── Плейлисти (PlaylistService) ──────────────────────────────────────────────

const PL_KEY = 'playlists';
export function getPlaylists() { return readJson(PL_KEY, []); }
export function savePlaylist(pl) {
  const list = getPlaylists();
  const i = list.findIndex((p) => p.id === pl.id);
  if (i >= 0) list[i] = pl; else list.push(pl);
  writeJson(PL_KEY, list);
}
export function deletePlaylist(id) {
  writeJson(PL_KEY, getPlaylists().filter((p) => p.id !== id));
}
