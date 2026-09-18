// Відеоплеєр (_VideoPlayerScreen): YouTube — вбудований програвач,
// файл зі сховища — <video> з рідними елементами керування.
import { h, icon, toast, pushScreen } from '../ui.js';
import { isYouTube, youTubeId, mediaUrl } from '../data.js';
import { audio } from '../audio.js';

export function openVideo(url, title) {
  if (!url) { toast('Відео не додано для цього сигналу'); return; }
  audio.pause();
  pushScreen(({ pop, el: screen }) => {
    screen.classList.add('dark');
    let player;
    if (isYouTube(url)) {
      const id = youTubeId(url);
      player = id
        ? h('iframe', { src: `https://www.youtube.com/embed/${id}?playsinline=1&rel=0&autoplay=1`, allow: 'autoplay; fullscreen; picture-in-picture', allowfullscreen: true })
        : h('div', { class: 'sec-text', style: { color: '#fff', padding: '24px' } }, 'Не вдалося розпізнати посилання YouTube');
    } else {
      player = h('video', { src: mediaUrl(url), controls: true, autoplay: true, playsinline: true, preload: 'metadata' });
      player.addEventListener('error', () => toast('Помилка завантаження відео', 'err'));
    }
    return h('div', { class: 'page dark' },
      h('div', { class: 'appbar dark' },
        h('div', { class: 'lead' }, h('button', { class: 'iconbtn', onClick: pop, style: { color: 'var(--gold)' } }, icon('arrow_back_ios_new'))),
        h('div', { class: 'title sm', style: { color: '#F3D77A' } }, `▶ ${title || 'Відео'}`)),
      h('div', { style: { height: '2px', background: 'linear-gradient(90deg, var(--dk-bg), var(--gold), var(--gold), var(--dk-bg))' } }),
      h('div', { class: 'body' },
        h('div', { class: 'body-inner', style: { padding: 0 } },
          h('div', { class: 'video-area' }, player),
          h('div', { class: 'notes-line' }, '♩ ♪ ♫ ♬ ♩ ♪ ♫ ♬ ♩ ♪ ♫ ♬'))));
  });
}
