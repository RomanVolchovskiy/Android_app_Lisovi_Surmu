// Вкладка «Події» (EventsScreen): глобальні події (Firestore), особисті
// події (localStorage) з кодом для обміну через shared_events.
import { h, icon, toast, clear, emptyState, pushScreen, appBar, confirmDialog, openDialog, promptDialog } from '../ui.js';
import { db, collection, doc, getDocs, setDoc, onSnapshot, query, where } from '../firebase.js';
import { getSignals, subscribeSignals } from '../data.js';
import { audio } from '../audio.js';
import { openSignalDetail } from './signal-detail.js';

const TYPES = ['Полювання', 'Змагання', 'Фестиваль', 'Навчання'];
const TYPE_ICON = { 'Полювання': 'forest', 'Змагання': 'emoji_events', 'Фестиваль': 'celebration', 'Навчання': 'school' };
const TYPE_COLOR = { 'Полювання': '#2F4F2F', 'Змагання': '#D4A017', 'Фестиваль': '#4A7C3F', 'Навчання': '#1C3A1C' };
const USER_KEY = 'user_events';

const readUser = () => { try { return JSON.parse(localStorage.getItem(USER_KEY) || '[]'); } catch { return []; } };
const writeUser = (list) => { try { localStorage.setItem(USER_KEY, JSON.stringify(list)); } catch { /* ignore */ } };

function normalize(d) {
  return {
    id: d.id?.toString() || '', title: d.title || '', description: d.description || '', location: d.location || '',
    date: d.date || new Date().toISOString(), type: d.type || 'Полювання',
    mainSignalIds: d.mainSignalIds || (d.relatedSignalId ? [String(d.relatedSignalId)] : []),
    accompanyingSignalIds: d.accompanyingSignalIds || [], isGlobal: !!d.isGlobal, shareCode: d.shareCode || null,
  };
}

const fmtDate = (iso) => { const d = new Date(iso); return isNaN(d) ? '' : d.toLocaleDateString('uk-UA', { day: '2-digit', month: '2-digit', year: 'numeric' }); };

export function renderEvents(container) {
  let globalEvents = [], search = '';
  const body = h('div', { class: 'list' });
  const searchInput = h('input', { type: 'search', placeholder: 'Пошук події...', style: { width: '100%', padding: '10px 12px 10px 40px', borderRadius: '24px', border: '1px solid rgba(0,0,0,.2)', background: '#fff' },
    onInput: (e) => { search = e.target.value.trim().toLowerCase(); render(); } });
  const header = h('div', { style: { padding: '12px 16px 0' } },
    h('div', { style: { position: 'relative' } }, h('span', { class: 'mi', style: { position: 'absolute', left: '12px', top: '9px', color: 'var(--grey-500)' } }, 'search'), searchInput),
    h('div', { class: 'dk-row', style: { marginTop: '10px' } },
      h('button', { class: 'btn', style: { flex: 1 }, onClick: () => createEventDialog(render) }, icon('add'), 'Створити подію'),
      h('button', { class: 'btn text', style: { flex: 1, border: '1px solid var(--primary)' }, onClick: () => importByCode(render) }, icon('key'), 'Ввести код')));

  const render = () => {
    clear(body);
    const match = (e) => !search || e.title.toLowerCase().includes(search) || e.description.toLowerCase().includes(search) || e.location.toLowerCase().includes(search);
    const g = globalEvents.filter(match);
    const u = readUser().map(normalize).filter(match);
    body.append(h('div', { class: 'sec-title', style: { marginTop: 0 } }, 'Мисливські події'));
    if (!g.length) body.append(h('div', { class: 's', style: { color: 'var(--grey-600)', marginBottom: '12px' } }, 'Подій ще немає'));
    g.forEach((e) => body.append(eventCard(e, { onDelete: null })));
    body.append(h('div', { class: 'sec-title' }, 'Мої події'));
    if (!u.length) body.append(h('div', { class: 's', style: { color: 'var(--grey-600)' } }, 'Створіть особисту подію або додайте за кодом'));
    u.forEach((e) => body.append(eventCard(e, {
      onDelete: async () => {
        if (await confirmDialog('Видалити подію?', `Видалити "${e.title}"?`)) { writeUser(readUser().filter((x) => String(x.id) !== e.id)); render(); }
      },
    })));
  };

  const unsubSignals = subscribeSignals(render);
  const unsub = onSnapshot(collection(db, 'global_events'), (snap) => {
    globalEvents = snap.docs.map((d) => normalize(d.data())).sort((a, b) => a.date.localeCompare(b.date));
    render();
  }, (e) => { toast(`Помилка завантаження подій: ${e.message}`, 'err'); });
  container.append(header, body);
  return () => { unsub(); unsubSignals(); };
}

function eventCard(e, { onDelete }) {
  const color = TYPE_COLOR[e.type] || '#757575';
  return h('div', { class: 'tile', style: { cursor: 'pointer', borderLeft: `4px solid ${color}` }, onClick: () => openEvent(e) },
    h('div', { style: { width: '44px', height: '44px', borderRadius: '12px', background: `${color}1f`, display: 'grid', placeItems: 'center', color } }, icon(TYPE_ICON[e.type] || 'event')),
    h('div', { class: 'grow' },
      h('div', { class: 't' }, e.title),
      h('div', { class: 's' }, [e.type, fmtDate(e.date), e.location].filter(Boolean).join(' · ')),
      h('div', { class: 's' }, `Сигналів: ${e.mainSignalIds.length + e.accompanyingSignalIds.length}`)),
    e.shareCode ? h('button', { class: 'iconbtn dim', title: 'Код для обміну', onClick: (ev) => { ev.stopPropagation(); showCode(e); } }, icon('share')) : null,
    onDelete ? h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: (ev) => { ev.stopPropagation(); onDelete(); } }, icon('delete')) : null);
}

function openEvent(e) {
  pushScreen((ctx) => {
    ctx.onPop = () => audio.pause();
    const color = TYPE_COLOR[e.type] || '#757575';
    const signalRow = (id) => {
      const s = getSignals().find((x) => x.id === id);
      if (!s) return h('div', { class: 'tile' }, h('div', { class: 'grow s' }, 'Сигнал не знайдено'));
      const pi = icon('play_arrow');
      audio.subscribe(({ currentId, playing }) => { pi.textContent = playing && currentId === (s.audioUrl || '').trim() ? 'pause' : 'play_arrow'; });
      return h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => openSignalDetail(s) },
        h('img', { src: 'assets/icon.png', style: { width: '40px', height: '40px', borderRadius: '10px' }, alt: '' }),
        h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, s.name), h('div', { class: 's' }, s.category)),
        h('button', { class: 'iconbtn', style: { color: 'var(--primary)' }, onClick: async (ev) => {
          ev.stopPropagation();
          if (!s.audioUrl) { toast('Аудіо не доступне'); return; }
          try { await audio.toggle(s.audioUrl); } catch (err) { toast(`Помилка: ${err.message}`, 'err'); }
        } }, pi));
    };
    const section = (title, ids) => ids.length ? [h('div', { class: 'sec-title' }, title), ...ids.map(signalRow)] : null;
    const allUrls = [...e.mainSignalIds, ...e.accompanyingSignalIds].map((id) => getSignals().find((x) => x.id === id)?.audioUrl).filter(Boolean);
    return h('div', { class: 'page', style: { background: 'var(--bg)' } },
      appBar(e.title, { back: ctx.pop, small: true, actions: e.shareCode ? [h('button', { class: 'iconbtn', onClick: () => showCode(e) }, icon('share'))] : [] }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' },
        h('div', { class: 'catbox', style: { background: `${color}1f`, color } }, icon(TYPE_ICON[e.type] || 'event'), h('span', { class: 'grow' }, e.type), h('span', { class: 'dur' }, icon('event'), fmtDate(e.date))),
        e.location ? h('div', { class: 'sec-text', style: { marginTop: '10px' } }, icon('place'), ` ${e.location}`) : null,
        e.description ? [h('div', { class: 'sec-title' }, 'Опис'), h('div', { class: 'sec-text' }, e.description)] : null,
        allUrls.length ? h('div', { style: { marginTop: '16px' } }, h('button', { class: 'btn', onClick: () => audio.playQueue(allUrls).catch((err) => toast(`Помилка: ${err.message}`, 'err')) }, icon('playlist_play'), 'Відтворити всі сигнали')) : null,
        section('Основні сигнали', e.mainSignalIds),
        section('Сопутні сигнали', e.accompanyingSignalIds),
        e.accompanyingSignalIds.length ? h('div', { class: 's', style: { color: 'var(--grey-600)', marginTop: '4px' } }, 'Рекомендовані залежно від ситуації') : null)));
  });
}

function showCode(e) {
  const d = openDialog([
    h('h3', {}, 'Код для обміну'),
    h('div', { class: 'sec-text' }, 'Передайте цей код іншому користувачу, щоб він додав подію собі:'),
    h('div', { style: { fontSize: '32px', fontWeight: 700, letterSpacing: '6px', textAlign: 'center', color: 'var(--primary)', margin: '12px 0' } }, e.shareCode),
    h('div', { class: 'row' },
      h('button', { class: 'btn text', onClick: () => { navigator.clipboard?.writeText(e.shareCode).then(() => toast('Код скопійовано')); } }, icon('content_copy'), 'Скопіювати код'),
      h('button', { class: 'btn', onClick: () => d.close() }, 'Закрити')),
  ]);
}

async function importByCode(rerender) {
  const code = await promptDialog('Ввести код події', { label: 'Код', placeholder: 'XXXXXX', okLabel: 'Додати',
    validate: (v) => (v.length === 6 ? null : 'Код повинен містити 6 символів') });
  if (!code) return;
  toast('Пошук події...');
  try {
    const snap = await getDocs(query(collection(db, 'shared_events'), where('shareCode', '==', code.toUpperCase())));
    if (snap.empty) { toast('Подію з таким кодом не знайдено', 'err'); return; }
    const ev = normalize(snap.docs[0].data());
    const list = readUser();
    if (list.some((x) => String(x.id) === ev.id)) { toast('Цю подію вже додано'); return; }
    list.push(ev); writeUser(list); rerender();
    toast('Подію додано', 'ok');
  } catch (e) { toast(`Помилка: ${e.message}`, 'err'); }
}

function genCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const arr = crypto.getRandomValues(new Uint8Array(6));
  return [...arr].map((b) => chars[b % chars.length]).join('');
}

/** Діалог «Створити особисту подію» — використовується і адмінкою (isGlobal). */
export function createEventDialog(done, { isGlobal = false, existing = null } = {}) {
  const e = existing || {};
  const title = h('input', { type: 'text', placeholder: 'Введіть назву події', value: e.title || '' });
  const desc = h('textarea', { placeholder: 'Опис', value: e.description || '' });
  const loc = h('input', { type: 'text', placeholder: 'Місце', value: e.location || '' });
  const date = h('input', { type: 'date', value: (e.date || new Date().toISOString()).slice(0, 10) });
  const type = h('select', {}, TYPES.map((t) => h('option', { value: t, selected: (e.type || TYPES[0]) === t }, t)));
  const main = [...(e.mainSignalIds || [])], acc = [...(e.accompanyingSignalIds || [])];
  const sigList = (ids, label) => {
    const box = h('div');
    const render = () => {
      clear(box);
      ids.forEach((id, i) => box.append(h('div', { class: 'dk-row', style: { padding: '4px 0', fontSize: '13px' } },
        h('span', { class: 'grow' }, getSignals().find((s) => s.id === id)?.name || id),
        h('button', { class: 'mi', style: { color: '#F44336', fontSize: '18px' }, onClick: () => { ids.splice(i, 1); render(); } }, 'close'))));
      box.append(h('button', { class: 'btn text', style: { padding: '6px 10px', fontSize: '12px' }, onClick: () => pickSignal(ids, render) }, icon('add'), 'Додати сигнал'));
    };
    render();
    return h('div', { style: { marginBottom: '12px' } }, h('div', { style: { fontWeight: 600, fontSize: '13px' } }, label), box);
  };
  const d = openDialog([
    h('h3', {}, existing ? 'Редагувати подію' : (isGlobal ? 'Створити подію' : 'Створити особисту подію')),
    h('label', { class: 'field' }, h('span', {}, 'Назва події *'), title),
    h('label', { class: 'field' }, h('span', {}, 'Опис'), desc),
    h('label', { class: 'field' }, h('span', {}, 'Місце'), loc),
    h('label', { class: 'field' }, h('span', {}, 'Дата'), date),
    h('label', { class: 'field' }, h('span', {}, 'Тип події'), type),
    sigList(main, 'Основні сигнали'),
    sigList(acc, 'Сопутні сигнали'),
    h('div', { class: 'row' },
      h('button', { class: 'btn text', onClick: () => d.close() }, 'Скасувати'),
      h('button', { class: 'btn', onClick: async () => {
        if (!title.value.trim()) { toast('Введіть назву події', 'err'); return; }
        const ev = {
          id: e.id || `${Date.now()}`, title: title.value.trim(), description: desc.value.trim(), location: loc.value.trim(),
          date: new Date(date.value || Date.now()).toISOString(), type: type.value,
          mainSignalIds: main, accompanyingSignalIds: acc, isGlobal, shareCode: isGlobal ? null : (e.shareCode || genCode()),
        };
        try {
          if (isGlobal) {
            await setDoc(doc(db, 'global_events', ev.id), ev);
          } else {
            const list = readUser().filter((x) => String(x.id) !== ev.id);
            list.push(ev); writeUser(list);
            setDoc(doc(db, 'shared_events', ev.id), ev).catch(() => { /* офлайн — код не знайдеться, але подія збережена локально */ });
          }
          d.close(); done?.();
          toast('Подію збережено', 'ok');
        } catch (err) { toast(`Помилка: ${err.message}`, 'err'); }
      } }, 'Зберегти')),
  ]);
  setTimeout(() => title.focus(), 50);
}

function pickSignal(ids, done) {
  const rest = getSignals().filter((s) => !ids.includes(s.id));
  if (!rest.length) { toast('Усі сигнали вже додано'); return; }
  const d = openDialog([
    h('h3', {}, 'Обрати сигнал'),
    h('div', { style: { maxHeight: '50vh', overflowY: 'auto' } }, rest.map((s) => h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => { ids.push(s.id); d.close(); done(); } },
      h('div', { class: 'grow' }, h('div', { class: 't', style: { fontSize: '14px' } }, s.name), h('div', { class: 's' }, s.category))))),
    h('div', { class: 'row' }, h('button', { class: 'btn text', onClick: () => d.close() }, 'Скасувати')),
  ]);
}
