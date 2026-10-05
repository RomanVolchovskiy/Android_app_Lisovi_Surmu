// Тренажер «Покіт: розкладка здобичі». Довідник видів і порядок (pokitRank)
// задає адміністратор (pokit_species), межі раунду — pokit_trainer/config.
// Код порядку не знає: лише сортує за pokitRank. Спроби — pokit_sessions.
// (Не плутати з категорією сигналів «Сигнали покоту» — це інше значення.)
import { h, icon, toast, pushScreen, appBar, confirmDialog, clear, spinner, emptyState } from '../ui.js';
import { db, auth, collection, doc, getDoc, getDocs, setDoc, query, where, writeBatch, serverTimestamp } from '../firebase.js';
import { getSignal, waitForSignals } from '../data.js';
import { audio } from '../audio.js';
import { isAdminUser } from '../access.js';

export const SPECIES = 'pokit_species';
export const CONFIG_DOC = ['pokit_trainer', 'config'];
const SESSIONS = 'pokit_sessions';
const HINT_KEY = 'pokit_hint_hidden';

export const DEFAULT_CONFIG = { minSpecies: 2, maxSpecies: 4, minCountPerSpecies: 1, maxCountPerSpecies: 3, groupingRequired: true };
const OK = '#2E7D32', BAD = '#C62828';

const num = (v, d = 0) => (Number.isFinite(Number(v)) ? Number(v) : d);
/** Справжній Fisher–Yates (не sort(() => Math.random() - .5)). */
export function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}
const randInt = (lo, hi) => lo + Math.floor(Math.random() * (hi - lo + 1));

export async function loadSpecies() {
  const snap = await getDocs(collection(db, SPECIES));
  return snap.docs.map((d) => ({ ...d.data(), id: d.data().id || d.id }));
}
export async function loadConfig() {
  try {
    const snap = await getDoc(doc(db, ...CONFIG_DOC));
    return { ...DEFAULT_CONFIG, ...(snap.exists() ? snap.data() : {}) };
  } catch { return { ...DEFAULT_CONFIG }; }
}

/** Іконка виду: власне зображення або Material-іконка. */
export function speciesBadge(sp, size = 40) {
  return sp.imageUrl
    ? h('img', { src: sp.imageUrl, alt: '', style: { width: `${size}px`, height: `${size}px`, objectFit: 'contain', borderRadius: '8px' } })
    : h('span', { class: 'mi', style: { fontSize: `${Math.round(size * 0.8)}px`, color: 'var(--brown-800, #5D4037)' } }, sp.icon || 'pets');
}

/** Раунд: N різних видів, у кожного випадкова кількість особин. */
export function generateRound(species, cfg) {
  const pool = shuffle(species.slice());
  const lo = Math.max(1, num(cfg.minSpecies, 2)), hi = Math.max(lo, num(cfg.maxSpecies, 4));
  const n = Math.min(pool.length, randInt(lo, hi));
  const cLo = Math.max(1, num(cfg.minCountPerSpecies, 1)), cHi = Math.max(cLo, num(cfg.maxCountPerSpecies, 3));
  return pool.slice(0, n).map((sp) => ({ species: sp, count: randInt(cLo, cHi) }));
}

/** Правильний ряд: за pokitRank (зростання), однакові види підряд. */
export function correctOrder(round) {
  return round.slice()
    .sort((a, b) => num(a.species.pokitRank) - num(b.species.pokitRank) || a.species.name.localeCompare(b.species.name, 'uk'))
    .flatMap((r) => Array(r.count).fill(r.species));
}

/**
 * Перевірка ряду студента (масив видів по одній тварині).
 * Тварина зарахована, якщо (а) ранг її виду дорівнює рангу, який має стояти
 * на цьому місці в правильному ряду (види однакового рангу взаємозамінні), і
 * (б) за обов'язкового групування — усі тварини її виду стоять суцільним блоком.
 */
export function checkRow(row, round, groupingRequired) {
  const expected = correctOrder(round).map((sp) => num(sp.pokitRank));
  const firstIdx = {}, lastIdx = {}, count = {};
  row.forEach((sp, i) => { firstIdx[sp.id] ??= i; lastIdx[sp.id] = i; count[sp.id] = (count[sp.id] || 0) + 1; });
  const grouped = (id) => lastIdx[id] - firstIdx[id] + 1 === count[id];
  const marks = row.map((sp, i) => {
    const rankOk = num(sp.pokitRank) === expected[i];
    const groupOk = !groupingRequired || grouped(sp.id);
    return { ok: rankOk && groupOk, rankOk, groupOk };
  });
  const correct = marks.filter((m) => m.ok).length;
  return { marks, correct, total: row.length, percent: row.length ? Math.round((correct / row.length) * 100) : 0 };
}

// ── Фішка в «Навчальних тренажерах» ─────────────────────────────────────────
export function pokitTrainer() {
  return h('div', {},
    h('div', { class: 's', style: { color: 'var(--grey-600)', margin: '4px 0 10px' } },
      'Після полювання здобич викладають у ряд у визначеному порядку. Викладіть «улов» так, як це робиться за традицією.'),
    h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: openGame },
      h('div', { style: { width: '44px', height: '44px', borderRadius: '12px', background: 'rgba(93,64,55,.12)', display: 'grid', placeItems: 'center', color: 'var(--brown-800, #5D4037)' } }, icon('pets')),
      h('div', { class: 'grow' }, h('div', { class: 't' }, 'Почати тренування'), h('div', { class: 's' }, 'Випадковий улов — викладіть ряд тапами')),
      icon('play_arrow', '')),
    h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: openMyResults },
      icon('history'), h('div', { class: 'grow' }, h('div', { class: 't' }, 'Мої результати'), h('div', { class: 's' }, 'Останні 50 спроб')), icon('chevron_right', '')));
}

// ── Гра ─────────────────────────────────────────────────────────────────────
function openGame() {
  pushScreen((ctx) => {
    const body = h('div', { class: 'body-inner', style: { maxWidth: '720px' } }, spinner());
    let species = [], cfg = DEFAULT_CONFIG;
    let round = [], pool = [], row = [];
    ctx.onPop = () => audio.stop();

    const card = (sp, { onClick, mark, small } = {}) => h('button', {
      class: 'tile', onClick,
      style: {
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '2px',
        width: small ? '64px' : '76px', minHeight: small ? '72px' : '86px', padding: '6px 4px', margin: '0', cursor: onClick ? 'pointer' : 'default',
        border: mark ? `2px solid ${mark.ok ? OK : BAD}` : '1px solid #ddd', position: 'relative', flex: '0 0 auto',
      },
    }, speciesBadge(sp, small ? 30 : 38),
    h('span', { style: { fontSize: '11px', lineHeight: 1.15, textAlign: 'center', wordBreak: 'break-word' } }, sp.name),
    mark ? h('span', { style: { position: 'absolute', top: '2px', right: '4px', fontWeight: 700, color: mark.ok ? OK : BAD } }, mark.ok ? '✓' : '✗') : null);

    const strip = (children, minH) => h('div', { style: {
      display: 'flex', flexWrap: 'wrap', gap: '6px', padding: '8px', minHeight: minH, borderRadius: '12px',
      background: 'rgba(93,64,55,.06)', border: '1px dashed rgba(93,64,55,.35)', alignContent: 'flex-start',
    } }, children);

    const newRound = () => {
      round = generateRound(species, cfg);
      pool = shuffle(round.flatMap((r) => Array(r.count).fill(r.species)));
      row = [];
      draw();
    };

    const draw = () => {
      const catchText = round.map((r) => `${r.count}× ${r.species.name}`).join(', ');
      const slots = row.map((sp, i) => card(sp, { small: true, onClick: i === row.length - 1 ? () => { pool.push(row.pop()); draw(); } : null }));
      const empties = Array.from({ length: pool.length }, () => h('div', { style: { width: '64px', height: '72px', borderRadius: '10px', border: '1px dashed #bbb' } }));
      clear(body).append(
        h('div', { class: 'tile', style: { display: 'block' } }, h('div', { class: 's' }, 'Улов цього раунду'), h('div', { class: 't' }, catchText)),
        h('div', { class: 'sec-title' }, `Покіт (${row.length} з ${row.length + pool.length})`),
        h('div', { class: 's', style: { margin: '-4px 0 6px' } }, 'Початок ряду — ліворуч. Остання покладена тварина повертається в пул дотиком або кнопкою.'),
        strip([...slots, ...empties], '88px'),
        h('div', { class: 'sec-title' }, 'Здобич — торкніться, щоб покласти в ряд'),
        strip(pool.length ? pool.map((sp, i) => card(sp, { onClick: () => { row.push(pool.splice(i, 1)[0]); draw(); } })) : [h('div', { class: 's', style: { padding: '8px' } }, 'Усю здобич викладено')], '100px'),
        h('div', { style: { display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '12px' } },
          h('button', { class: 'btn text', disabled: !row.length, onClick: () => { pool.push(row.pop()); draw(); } }, icon('undo'), 'Прибрати останню'),
          h('button', { class: 'btn text', onClick: newRound }, icon('casino'), 'Новий раунд'),
          h('div', { class: 'grow' }),
          !pool.length ? h('button', { class: 'btn', onClick: showResult }, icon('fact_check'), 'Перевірити') : null));
    };

    const showResult = () => {
      const res = checkRow(row, round, cfg.groupingRequired !== false);
      const right = correctOrder(round);
      const honour = [...new Map(right.map((sp) => [sp.id, sp])).values()]
        .map((sp) => getSignal(sp.signalId)?.audioUrl).filter(Boolean);
      const reasons = [];
      if (res.marks.some((m) => !m.rankOk)) reasons.push('порушено порядок покоту');
      if (res.marks.some((m) => !m.groupOk)) reasons.push('однакові види мають лежати поряд');
      const save = h('button', { class: 'btn', onClick: async () => { save.disabled = true; await saveSession(round, row, res); } }, icon('save'), 'Зберегти результат');
      clear(body).append(
        h('div', { style: { textAlign: 'center', padding: '8px 0' } },
          h('div', { style: { fontSize: '48px', fontWeight: 700, color: res.percent === 100 ? OK : res.percent >= 50 ? '#EF6C00' : BAD } }, `${res.percent}%`),
          h('div', { class: 's', style: { fontSize: '15px' } }, `${res.correct} з ${res.total} тварин на правильному місці`),
          reasons.length ? h('div', { class: 's', style: { color: BAD, marginTop: '4px' } }, reasons.join('; ')) : h('div', { style: { color: OK, fontWeight: 600, marginTop: '4px' } }, 'Покіт викладено правильно!')),
        h('div', { class: 'sec-title' }, 'Ваш ряд'),
        strip(row.map((sp, i) => card(sp, { small: true, mark: res.marks[i] })), '80px'),
        h('div', { class: 'sec-title' }, 'Правильний ряд'),
        strip(right.map((sp) => card(sp, { small: true })), '80px'),
        honour.length && res.percent === 100 ? h('button', { class: 'btn text', style: { marginTop: '8px' }, onClick: () => audio.playQueue(honour).catch((e) => toast(`Помилка відтворення: ${e.message}`, 'err')) }, icon('campaign'), 'Сигнали вшанування здобичі') : null,
        h('div', { style: { display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '16px' } },
          save,
          h('button', { class: 'btn text', onClick: () => { audio.stop(); newRound(); } }, icon('casino'), 'Новий раунд'),
          h('button', { class: 'btn text', onClick: ctx.pop }, icon('home'), 'На головну')));
    };

    const hint = () => {
      let hidden = false;
      try { hidden = localStorage.getItem(HINT_KEY) === '1'; } catch { /* приватний режим */ }
      if (hidden) return null;
      const box = h('div', { class: 'tile', style: { display: 'block', background: '#FFF8E1', border: '1px solid var(--gold)' } },
        h('div', {}, 'Викладіть здобич у ряд у правильному порядку покоту. Однакові види мають стояти поряд.'),
        h('div', { style: { textAlign: 'right' } }, h('button', { class: 'btn text', onClick: () => { try { localStorage.setItem(HINT_KEY, '1'); } catch { /* ок */ } box.remove(); } }, 'Зрозуміло, більше не показувати')));
      return box;
    };

    (async () => {
      [species, cfg] = await Promise.all([loadSpecies(), loadConfig(), waitForSignals()]);
      species = species.filter((s) => !s.hidden && (s.name || '').trim());
      const need = Math.max(1, num(cfg.minSpecies, 2));
      if (species.length < need) {
        clear(body).append(emptyState('pets', 'Адміністратор ще не наповнив довідник видів', `Для раунду потрібно щонайменше ${need} види (зараз — ${species.length}).`));
        return;
      }
      const h0 = hint();
      newRound();
      if (h0) body.prepend(h0);
    })().catch((e) => clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)));

    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Покіт: розкладка здобичі', { back: ctx.pop, small: true }),
      h('div', { class: 'body' }, body));
  });
}

async function saveSession(round, row, res) {
  const u = auth.currentUser;
  if (!u) { toast('Увійдіть, щоб зберігати результати', 'err'); return; }
  let profile = {};
  try { profile = (await getDoc(doc(db, 'users', u.uid))).data() || {}; } catch { /* профіль необов'язковий */ }
  try {
    await setDoc(doc(collection(db, SESSIONS)), {
      uid: u.uid, email: (u.email || '').toLowerCase(),
      fullName: profile.fullName ?? null, group: profile.group ?? null,
      round: round.map((r) => ({ speciesId: r.species.id, speciesName: r.species.name, count: r.count })),
      studentOrder: row.map((sp) => sp.id),
      correct: res.correct, total: res.total, percent: res.percent,
      createdAt: serverTimestamp(),
    });
    toast('Результат збережено', 'ok');
  } catch (e) { toast(`Не вдалося зберегти: ${e.message}`, 'err'); }
}

// ── Мої результати ──────────────────────────────────────────────────────────
function openMyResults() {
  pushScreen(({ pop }) => {
    const body = h('div', { class: 'body-inner' }, spinner());
    const u = auth.currentUser;
    const admin = isAdminUser(); // видаляти записи правила дозволяють лише адміністратору
    const remove = async (ids, what) => {
      if (!await confirmDialog('Видалити?', `Видалити ${what}? Цю дію не можна скасувати.`, { okLabel: 'Видалити', cancelLabel: 'Скасувати', danger: true })) return;
      try {
        for (let i = 0; i < ids.length; i += 400) {
          const batch = writeBatch(db);
          ids.slice(i, i + 400).forEach((id) => batch.delete(doc(db, SESSIONS, id)));
          await batch.commit();
        }
        toast('Видалено', 'ok'); load();
      } catch (e) { toast(`Не вдалося видалити: ${e.message}`, 'err'); }
    };
    const load = async () => {
      clear(body).append(spinner());
      if (!u) { clear(body).append(emptyState('lock', 'Увійдіть, щоб бачити результати')); return; }
      const snap = await getDocs(query(collection(db, SESSIONS), where('uid', '==', u.uid)));
      const all = snap.docs.map((d) => ({ ...d.data(), _id: d.id }))
        .sort((a, b) => (b.createdAt?.toMillis?.() ?? 0) - (a.createdAt?.toMillis?.() ?? 0));
      clear(body);
      if (!all.length) { body.append(emptyState('history', 'Ще немає збережених спроб')); return; }
      if (admin) body.append(h('button', { class: 'btn text', style: { color: BAD, marginBottom: '8px' }, onClick: () => remove(all.map((r) => r._id), `усі свої результати (${all.length})`) }, icon('delete_sweep'), 'Видалити всі мої результати'));
      all.slice(0, 50).forEach((r) => {
        const d = r.createdAt?.toDate?.();
        body.append(h('div', { class: 'tile' },
          h('b', { style: { minWidth: '48px', color: r.percent === 100 ? OK : r.percent >= 50 ? '#EF6C00' : BAD } }, `${r.percent}%`),
          h('div', { class: 'grow' },
            h('div', { class: 't', style: { fontSize: '14px' } }, (r.round || []).map((x) => `${x.count}× ${x.speciesName}`).join(', ')),
            h('div', { class: 's' }, [d ? d.toLocaleString('uk-UA', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '', `${r.correct}/${r.total}`].filter(Boolean).join(' · '))),
          admin ? h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: () => remove([r._id], 'цей результат') }, icon('delete')) : null));
      });
    };
    load().catch((e) => clear(body).append(emptyState('error_outline', 'Помилка завантаження', e.message)));
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar('Мої результати: покіт', { back: pop, small: true }),
      h('div', { class: 'body' }, body));
  });
}
