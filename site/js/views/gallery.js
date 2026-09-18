// Фотогалерея (_GalleryScreen): гортання свайпом, індикатор слайдів.
import { h, icon, pushScreen } from '../ui.js';
import { mediaUrl } from '../data.js';

export function openGallery(images, title, start = 0) {
  pushScreen(({ pop }) => {
    const dots = images.map((_, i) => h('i', { class: i === start ? 'on' : '' }));
    const counter = h('span', {}, `${start + 1} / ${images.length}`);
    const track = h('div', { class: 'track' }, images.map((src) => h('div', { class: 'slide' },
      h('img', { src: mediaUrl(src), alt: '',
        onError: (e) => { e.target.replaceWith(h('div', { style: { color: '#fff' } }, 'Не вдалося завантажити')); } }))));
    track.addEventListener('scroll', () => {
      const i = Math.round(track.scrollLeft / track.clientWidth);
      dots.forEach((d, k) => d.classList.toggle('on', k === i));
      counter.textContent = `${i + 1} / ${images.length}`;
    });
    const go = (d) => track.scrollBy({ left: d * track.clientWidth, behavior: 'smooth' });
    const el = h('div', { class: 'gallery' },
      h('div', { class: 'appbar dark' },
        h('div', { class: 'lead' }, h('button', { class: 'iconbtn', onClick: pop }, icon('arrow_back'))),
        h('div', { class: 'title sm' }, title || 'Галерея'),
        h('div', { class: 'actions' }, h('span', { style: { color: 'var(--gold)', paddingRight: '12px' } }, counter))),
      track,
      h('div', { class: 'dots' }, dots));
    el.tabIndex = 0;
    el.addEventListener('keydown', (e) => { if (e.key === 'ArrowRight') go(1); if (e.key === 'ArrowLeft') go(-1); if (e.key === 'Escape') pop(); });
    setTimeout(() => { track.scrollLeft = start * track.clientWidth; el.focus(); }, 0);
    return el;
  });
}
