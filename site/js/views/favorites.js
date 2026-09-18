// Вкладка «Обране» (FavoritesScreen): «Мої обрані» та «Плейлисти».
import { h, icon, toast, clear, emptyState, confirmDialog, openDialog } from '../ui.js';
import { getSignals, subscribeSignals, getFavorites, onFavoritesChange, getPlaylists, savePlaylist, deletePlaylist } from '../data.js';
import { audio } from '../audio.js';
import { signalCard } from './signals.js';

export function renderFavorites(container, { onGoToSignals }) {
  let tab = 'fav';
  const body = h('div', { class: 'list' });
  const tabs = h('div', { class: 'subtabs' },
    h('button', { class: 'active', onClick: () => setTab('fav') }, 'Мої обрані'),
    h('button', { onClick: () => setTab('pl') }, 'Плейлисти'));
  const setTab = (t) => { tab = t; [...tabs.children].forEach((b, i) => b.classList.toggle('active', (i === 0) === (t === 'fav'))); render(); };

  const render = () => {
    clear(body);
    if (tab === 'fav') renderFavTab(body, onGoToSignals); else renderPlaylistsTab(body);
  };
  const offSig = subscribeSignals(render);
  const offFav = onFavoritesChange(() => { if (tab === 'fav') render(); });
  container.append(tabs, body);
  return () => { offSig(); offFav(); };
}

function renderFavTab(body, onGoToSignals) {
  const ids = getFavorites();
  const items = getSignals().filter((s) => ids.includes(s.id));
  if (!items.length) {
    body.append(emptyState('favorite_border', 'Ще немає обраних сигналів', 'Натисніть ♥ на картці сигналу'),
      h('div', { style: { textAlign: 'center' } }, h('button', { class: 'btn', onClick: onGoToSignals }, 'Перейти до сигналів')));
    return;
  }
  body.append(...items.map(signalCard));
}

function renderPlaylistsTab(body) {
  const lists = getPlaylists();
  const rerender = () => { clear(body); renderPlaylistsTab(body); };
  if (!lists.length) {
    body.append(emptyState('queue_music', 'Плейлисти відсутні', 'Створіть плейлист із обраних сигналів'));
  }
  for (const pl of lists) {
    const count = h('div', { class: 's' }, icon('audiotrack', 'sm'), ` ${pl.signalIds.length} сигнал(ів)`);
    body.append(h('div', { class: 'tile' },
      h('div', { style: { width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(47,79,47,.1)', display: 'grid', placeItems: 'center', color: 'var(--primary)' } }, icon('queue_music')),
      h('div', { class: 'grow' }, h('div', { class: 't' }, pl.name), count),
      h('button', { class: 'iconbtn', style: { color: 'var(--primary)' }, title: 'Відтворити', onClick: () => playPlaylist(pl) }, icon('play_arrow')),
      h('button', { class: 'iconbtn', style: { color: '#F44336' }, title: 'Видалити', onClick: async () => {
        if (await confirmDialog('Видалити плейлист?', `Видалити "${pl.name}"?`, { okLabel: 'Видалити', danger: true })) { deletePlaylist(pl.id); rerender(); }
      } }, icon('delete'))));
  }
  body.append(h('div', { style: { textAlign: 'center', marginTop: '12px' } },
    h('button', { class: 'btn', onClick: () => createPlaylistDialog(rerender) }, icon('add'), 'Створити плейлист')));
}

function playPlaylist(pl) {
  const urls = pl.signalIds.map((id) => getSignals().find((s) => s.id === id)?.audioUrl).filter(Boolean);
  if (!urls.length) { toast('У плейлисті немає сигналів з аудіо'); return; }
  toast(`Відтворення плейлиста: ${pl.name}`);
  audio.playQueue(urls).catch((e) => toast(`Помилка відтворення: ${e.message || e}`, 'err'));
}

function createPlaylistDialog(done) {
  const name = h('input', { type: 'text', placeholder: 'Введіть назву плейлиста' });
  const err = h('div', { class: 'err', hidden: true });
  const checks = getSignals().map((s) => {
    const cb = h('input', { type: 'checkbox', value: s.id });
    return h('label', { style: { display: 'flex', gap: '10px', alignItems: 'center', padding: '8px 0', borderBottom: '1px solid #eee' } },
      cb, h('div', {}, h('div', { style: { fontSize: '14px' } }, s.name), h('div', { style: { fontSize: '12px', color: 'var(--grey-600)' } }, s.category)));
  });
  const d = openDialog([
    h('h3', {}, 'Створити плейлист'),
    h('label', { class: 'field' }, h('span', {}, 'Назва плейлиста *'), name),
    err,
    h('div', { style: { fontWeight: 600, marginBottom: '6px' } }, 'Оберіть сигнали:'),
    h('div', { style: { maxHeight: '40vh', overflowY: 'auto' } }, checks),
    h('div', { class: 'row' },
      h('button', { class: 'btn text', onClick: () => d.close() }, 'Скасувати'),
      h('button', { class: 'btn', onClick: () => {
        const n = name.value.trim();
        if (!n) { err.textContent = 'Введіть назву плейлиста'; err.hidden = false; return; }
        const ids = checks.map((l) => l.querySelector('input')).filter((c) => c.checked).map((c) => c.value);
        savePlaylist({ id: `${Date.now()}`, name: n, signalIds: ids });
        d.close(); done();
      } }, 'Зберегти')),
  ]);
  setTimeout(() => name.focus(), 50);
}
