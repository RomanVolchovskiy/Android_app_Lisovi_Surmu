// Один плеєр на весь сайт (AudioService): грає одне джерело за раз,
// повідомляє підписників про зміну стану.
import { mediaUrl } from './data.js';

const el = new Audio();
el.preload = 'auto';

let currentId = null;   // URL того, що грає (як currentSignalId у додатку)
let playing = false;
const listeners = new Set();

function emit() { listeners.forEach((l) => l({ currentId, playing })); }

el.addEventListener('play', () => { playing = true; emit(); });
el.addEventListener('pause', () => { playing = false; emit(); });
el.addEventListener('ended', () => { playing = false; currentId = null; emit(); });
el.addEventListener('error', () => { playing = false; emit(); });

export const audio = {
  get currentId() { return currentId; },
  get playing() { return playing; },
  isPlaying(url) { return playing && currentId === (url || '').trim(); },
  isCurrent(url) { return currentId === (url || '').trim(); },

  async play(url) {
    url = (url || '').trim();
    if (!url) throw new Error('Аудіо не додано');
    if (currentId === url && !playing) { await el.play(); return; }
    el.pause();
    currentId = url;
    el.src = mediaUrl(url);
    emit();
    try {
      await el.play();
    } catch (e) {
      currentId = null; playing = false; emit();
      throw e;
    }
  },
  pause() { el.pause(); },
  stop() { el.pause(); el.removeAttribute('src'); el.load(); currentId = null; playing = false; emit(); },
  async toggle(url) {
    if (this.isPlaying(url)) this.pause(); else await this.play(url);
  },
  subscribe(cb) { listeners.add(cb); cb({ currentId, playing }); return () => listeners.delete(cb); },
  /** Черга: грає список URL один за одним (плейлисти, події). */
  async playQueue(urls, onIndex) {
    const list = urls.map((u) => (u || '').trim()).filter(Boolean);
    for (let i = 0; i < list.length; i++) {
      onIndex?.(i);
      await this.play(list[i]);
      await new Promise((res) => {
        const done = () => { el.removeEventListener('ended', done); el.removeEventListener('error', done); res(); };
        el.addEventListener('ended', done); el.addEventListener('error', done);
      });
      if (currentId !== list[i] && currentId !== null) return; // перемкнули на інше
    }
    onIndex?.(-1);
  },
};
