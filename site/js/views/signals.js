// Вкладка «Сигнали» (CategoriesScreen): фішки категорій зі стрілками та
// список карток сигналів (SignalCard).
import { h, icon, toast, clear, emptyState } from '../ui.js';
import { CATEGORIES, ALL_CATEGORIES, subscribeSignals, isFavorite, toggleFavorite, onFavoritesChange } from '../data.js';
import { audio } from '../audio.js';
import { openSignalDetail } from './signal-detail.js';
import { openVideo } from './video.js';

let selectedCategory = ALL_CATEGORIES;

export function renderSignals(container) {
  const chips = h('div', { class: 'chips' });
  const left = h('div', { class: 'chips-fade left', hidden: true },
    h('button', { class: 'chips-arrow', onClick: () => chips.scrollBy({ left: -140 }) }, icon('chevron_left')));
  const right = h('div', { class: 'chips-fade right' },
    h('button', { class: 'chips-arrow', onClick: () => chips.scrollBy({ left: 140 }) }, icon('chevron_right')));
  const list = h('div', { class: 'list' });

  const names = [ALL_CATEGORIES, ...CATEGORIES.map((c) => c.name)];
  const renderChips = () => {
    clear(chips).append(...names.map((n) => h('button', {
      class: `chip ${n === selectedCategory ? 'selected' : ''}`,
      onClick: () => { selectedCategory = n; renderChips(); renderList(); },
    }, n)));
  };
  const updateArrows = () => {
    left.hidden = chips.scrollLeft <= 0;
    right.hidden = chips.scrollLeft >= chips.scrollWidth - chips.clientWidth - 1;
  };
  chips.addEventListener('scroll', updateArrows);
  window.addEventListener('resize', updateArrows);

  let all = [];
  const renderList = () => {
    const items = selectedCategory === ALL_CATEGORIES ? all : all.filter((s) => s.category === selectedCategory);
    clear(list);
    if (!items.length) {
      list.append(emptyState('surround_sound', 'Сигнали не знайдені', 'Виберіть іншу категорію'));
      return;
    }
    list.append(...items.map(signalCard));
  };

  const unsub = subscribeSignals((signals) => { all = signals; renderList(); });
  container.append(h('div', { class: 'chips-wrap' }, chips, left, right), list);
  renderChips();
  requestAnimationFrame(updateArrows);
  return () => unsub();
}

/** Картка сигналу — той самий вигляд, що й SignalCard у додатку. */
export function signalCard(signal) {
  const fav = h('button', { class: `fav ${isFavorite(signal.id) ? 'on' : ''}`, title: 'В обране' },
    icon(isFavorite(signal.id) ? 'favorite' : 'favorite_border'));
  fav.addEventListener('click', (e) => {
    e.stopPropagation();
    const on = toggleFavorite(signal.id);
    fav.classList.toggle('on', on);
    fav.firstChild.textContent = on ? 'favorite' : 'favorite_border';
  });
  onFavoritesChange((ids) => {
    const on = ids.includes(signal.id);
    fav.classList.toggle('on', on);
    fav.firstChild.textContent = on ? 'favorite' : 'favorite_border';
  });

  const playIcon = icon('play_arrow');
  const playLabel = h('span', {}, 'Слухати');
  const playBtn = h('button', { class: 'cbtn green' }, playIcon, playLabel);
  playBtn.addEventListener('click', async (e) => {
    e.stopPropagation();
    if (!signal.audioUrl) { toast('Аудіо не додано для цього сигналу'); return; }
    try { await audio.toggle(signal.audioUrl); } catch (err) { toast(`Помилка відтворення: ${err.message || err}`, 'err'); }
  });
  audio.subscribe(({ currentId, playing }) => {
    const on = playing && currentId === (signal.audioUrl || '').trim();
    playIcon.textContent = on ? 'pause' : 'play_arrow';
    playLabel.textContent = on ? 'Пауза' : 'Слухати';
  });

  const card = h('div', { class: 'scard', onClick: () => openSignalDetail(signal) },
    h('div', { class: 'head' },
      h('img', { class: 'ico', src: 'assets/icon.png', alt: '' }),
      h('div', { class: 'grow' }, h('div', { class: 'name' }, signal.name), h('div', { class: 'cat' }, signal.category)),
      fav),
    h('div', { class: 'desc' }, signal.description),
    h('div', { class: 'btns' },
      playBtn,
      h('button', { class: 'cbtn blue', onClick: (e) => { e.stopPropagation(); openVideo(signal.videoUrl, signal.name); } }, icon('videocam'), h('span', {}, 'Відео')),
      h('button', { class: 'cbtn grey outlined', onClick: (e) => { e.stopPropagation(); openSignalDetail(signal); } }, icon('info'), h('span', {}, 'Інфо'))));
  return card;
}
