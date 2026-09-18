// Екран деталей сигналу (SignalDetailScreen): опис, обкладинка, історична
// довідка, інструкції, теги; внизу — Аудіо / Відео / Ноти / Галерея.
import { h, icon, toast, pushScreen, appBar } from '../ui.js';
import { mediaUrl } from '../data.js';
import { audio } from '../audio.js';
import { openVideo } from './video.js';
import { openGallery } from './gallery.js';
import { openNotation } from './notation.js';

export function openSignalDetail(signal) {
  pushScreen(({ pop }) => {
    const playIcon = icon('play_circle');
    const playLabel = h('span', {}, 'Аудіо');
    const unsub = audio.subscribe(({ currentId, playing }) => {
      const on = playing && currentId === (signal.audioUrl || '').trim();
      playIcon.textContent = on ? 'pause_circle' : 'play_circle';
      playLabel.textContent = on ? 'Пауза' : 'Аудіо';
    });

    const toggleAudio = async () => {
      if (!signal.audioUrl) { toast('Аудіо не додано для цього сигналу'); return; }
      try { await audio.toggle(signal.audioUrl); } catch (e) { toast(`Помилка відтворення: ${e.message || e}`, 'err'); }
    };
    const gallery = () => {
      if (!signal.galleryImages.length) { toast('Фотогалерея не додана для цього сигналу'); return; }
      openGallery(signal.galleryImages, signal.name);
    };
    const notation = () => {
      const has = signal.notationUrl || signal.notationData.length || signal.signalText || signal.partitureUrl;
      if (!has) { toast('Ноти не додані для цього сигналу'); return; }
      openNotation(signal);
    };

    const body = h('div', { class: 'body-inner' },
      h('div', { class: 'catbox' },
        icon('category'), h('span', { class: 'grow' }, signal.category),
        signal.duration > 0 ? h('span', { class: 'dur' }, icon('timer'), `${signal.duration}с`) : null),
      h('div', { class: 'sec-title' }, 'Опис'),
      h('div', { class: 'sec-text lead' }, signal.description),
      signal.imageUrl ? h('img', { class: 'cover', src: mediaUrl(signal.imageUrl), alt: signal.name, loading: 'lazy',
        onError: (e) => e.target.remove() }) : null,
      signal.historicalInfo ? [h('div', { class: 'sec-title' }, 'Історична довідка'), h('div', { class: 'sec-text' }, signal.historicalInfo)] : null,
      signal.usageInstructions ? [h('div', { class: 'sec-title' }, 'Інструкції з використання'), h('div', { class: 'sec-text' }, signal.usageInstructions)] : null,
      signal.tags.length ? [h('div', { class: 'sec-title' }, 'Теги'), h('div', { class: 'tags' }, signal.tags.map((t) => h('span', { class: 'tag' }, t)))] : null,
      h('div', { style: { height: '12px' } }));

    const actionBtn = (ic, label, color, onClick) => h('button', { class: 'abtn', style: { '--c': color }, onClick },
      h('div', { class: 'circ' }, ic), label);

    const el = h('div', { class: 'page' },
      appBar(signal.name, { back: () => { unsub(); pop(); }, cls: 'brown', small: true }),
      h('div', { class: 'body' }, body),
      h('div', { class: 'actionbar' },
        actionBtn(playIcon, playLabel, 'var(--primary)', toggleAudio),
        actionBtn(icon('videocam'), 'Відео', 'var(--blue-700)', () => openVideo(signal.videoUrl2 || signal.videoUrl, signal.name)),
        actionBtn(icon('music_note'), 'Ноти', 'var(--orange-700)', notation),
        actionBtn(icon('photo_library'), 'Галерея', 'var(--teal-600)', gallery)));
    return el;
  });
}
