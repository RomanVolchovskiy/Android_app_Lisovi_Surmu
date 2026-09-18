// Переглядач нот (_NotationViewerScreen): зображення нот, аудіо до нот,
// темп, графічне відображення з відліком і підсвіткою поточної ноти,
// текст сигналу та партитура за паролем.
import { h, icon, toast, pushScreen, appBar, openDialog } from '../ui.js';
import { mediaUrl } from '../data.js';
import { audio } from '../audio.js';

const PITCH_LABELS = ['СОЛЬ2', 'МІ2', 'ДО2', 'СОЛЬ', 'ДО'];
const FILLED = [0, 4, 3, 2, 1];               // ціла, половинна, четвертна, восьма, 1/16
const DURATION_LABELS = ['Ціла', 'Половинна', 'Четвертна', 'Восьма', '1/16'];
const BEATS = [4, 2, 1, 0.5, 0.25];
const ROW_H = 40, GAP = 4, NOTE_W = 62;
const STAFF_H = 5 * ROW_H + 4 * GAP;
const PARTITURE_PASSWORD = '2505';

export function squares(duration) {
  const f = FILLED[duration] ?? 0;
  return h('span', { class: 'sq' }, Array.from({ length: 5 }, (_, i) => h('i', { class: i < f ? 'f' : '' })));
}

/** Графічний нотний стан (NotationDisplayWidget). */
export function notationStaff(notes) {
  const cols = Math.max(notes.length + 2, 4);
  const rows = h('div', { class: 'rows', style: { width: `${cols * NOTE_W}px`, height: `${STAFF_H}px` } },
    Array.from({ length: 5 }, () => h('div', { class: 'row' })));
  const highlight = h('div', { class: 'item cur', hidden: true, style: { top: 0, height: `${STAFF_H}px` } });
  const cursor = h('div', { class: 'cursor', hidden: true });
  rows.append(highlight, cursor);
  notes.forEach((item, i) => {
    const t = item.t || 'n', x = i * NOTE_W;
    if (t === 'n') {
      rows.append(h('div', { class: 'item', style: { left: `${x}px`, top: `${(item.p | 0) * (ROW_H + GAP)}px` } }, squares(item.d | 0)));
    } else if (t === 'b') {
      rows.append(h('div', { style: { position: 'absolute', left: `${x + NOTE_W / 2 - 1}px`, top: 0, width: '1.5px', height: `${STAFF_H}px`, background: '#000' } }));
    } else if (t === 'pa') {
      rows.append(
        h('div', { style: { position: 'absolute', left: `${x + NOTE_W / 2 - 7}px`, top: 0, width: '4px', height: `${STAFF_H}px`, background: '#000' } }),
        h('div', { style: { position: 'absolute', left: `${x + NOTE_W / 2 + 2}px`, top: 0, width: '4px', height: `${STAFF_H}px`, background: '#000' } }));
    }
  });
  const wrap = h('div', { class: 'staff-wrap' },
    h('div', { class: 'staff' },
      h('div', { class: 'labels' }, PITCH_LABELS.map((l) => h('div', {}, l))),
      rows));
  const legend = h('div', { class: 'dk-row', style: { marginTop: '8px', fontSize: '11px', gap: '12px' } },
    DURATION_LABELS.map((l, i) => h('span', { class: 'dk-row', style: { gap: '4px' } }, h('span', { style: { background: '#fff', padding: '2px 3px', borderRadius: '3px' } }, squares(i)), l)),
    h('span', {}, '│ — вдих'), h('span', {}, '║ — пауза'));
  return {
    el: h('div', {}, wrap, legend),
    setCurrent(i) {
      const on = i >= 0 && i < notes.length;
      highlight.hidden = cursor.hidden = !on;
      if (on) {
        highlight.style.left = cursor.style.left = `${i * NOTE_W}px`;
        const target = i * NOTE_W - wrap.clientWidth / 2 + NOTE_W;
        wrap.scrollTo({ left: Math.max(0, target), behavior: 'smooth' });
      }
    },
  };
}

/** Відтворення графічних нот: відлік 5 с, далі підсвітка нот за темпом. */
export function notationPlayer(notes, getTempo, { onCountdown, onIndex, onState }) {
  let timer = null, index = -1;
  const stop = () => { clearTimeout(timer); timer = null; index = -1; onIndex(-1); onCountdown(null); onState(false); };
  const next = () => {
    if (index >= notes.length) { stop(); return; }
    onIndex(index);
    const item = notes[index];
    const beats = (item.t || 'n') === 'n' ? BEATS[item.d | 0] : 1;
    timer = setTimeout(() => { index++; next(); }, Math.round(beats * 60000 / getTempo()));
  };
  const start = () => {
    if (!notes.length) return;
    clearTimeout(timer);
    let c = 5;
    onState(true); onCountdown(c);
    const tick = () => {
      c--;
      if (c <= 0) { onCountdown(null); index = 0; next(); } else { onCountdown(c); timer = setTimeout(tick, 1000); }
    };
    timer = setTimeout(tick, 1000);
  };
  return { start, stop, get running() { return timer !== null; } };
}

export function openNotation(signal) {
  pushScreen((ctx) => {
    const { pop, el: screen } = ctx;
    screen.classList.add('dark');
    let tempo = signal.notationTempo || 90;
    const sections = [];

    // ── Зображення нот ──
    if (signal.notationUrl) {
      const img = h('img', { class: 'notation-img', src: mediaUrl(signal.notationUrl), alt: 'Ноти', loading: 'lazy',
        onError: (e) => e.target.replaceWith(h('div', { class: 'sec-text', style: { color: '#fff' } }, 'Помилка завантаження нот')) });
      sections.push(h('div', { class: 'dk-card' },
        h('div', { class: 'dk-title' }, icon('music_note'), 'Ноти'),
        img,
        h('div', { class: 'dk-row', style: { marginTop: '10px', justifyContent: 'flex-end' } },
          h('button', { class: 'dk-btn', onClick: () => openFullscreenImage(mediaUrl(signal.notationUrl), 'Ноти') }, icon('fullscreen'), 'Повний екран'))));
    }

    // ── Аудіо до нот ──
    if (signal.notationAudioUrl) {
      const pi = icon('play_arrow');
      const btn = h('button', { class: 'play-big', onClick: async () => {
        try { await audio.toggle(signal.notationAudioUrl); } catch (e) { toast(`Помилка відтворення: ${e.message || e}`, 'err'); }
      } }, pi);
      audio.subscribe(({ currentId, playing }) => { pi.textContent = playing && currentId === signal.notationAudioUrl.trim() ? 'pause' : 'play_arrow'; });
      sections.push(h('div', { class: 'dk-card' },
        h('div', { class: 'dk-title' }, icon('mic'), 'Аудіо до нот (спів із сигналом)'),
        h('div', { class: 'dk-row', style: { justifyContent: 'center' } }, btn)));
    }

    // ── Темп + графічне відображення ──
    if (signal.notationData.length) {
      const tempoVal = h('div', { class: 'tempo-val' }, `${tempo}`);
      const slider = h('input', { type: 'range', class: 'gold', min: 40, max: 300, value: tempo,
        onInput: (e) => { tempo = +e.target.value; tempoVal.textContent = `${tempo}`; } });
      const staff = notationStaff(signal.notationData);
      const countdown = h('div', { class: 'countdown', hidden: true });
      const playIc = icon('play_arrow');
      const playLbl = h('span', {}, 'Відтворити');
      const player = notationPlayer(signal.notationData, () => tempo, {
        onCountdown: (c) => { countdown.hidden = c == null; countdown.textContent = c ?? ''; },
        onIndex: (i) => staff.setCurrent(i),
        onState: (on) => { playIc.textContent = on ? 'stop' : 'play_arrow'; playLbl.textContent = on ? 'Зупинити' : 'Відтворити'; },
      });
      const playBtn = h('button', { class: 'dk-btn fill', onClick: () => (player.running ? player.stop() : player.start()) }, playIc, playLbl);
      ctx.onPop = () => player.stop();

      sections.push(
        h('div', { class: 'dk-card' },
          h('div', { class: 'dk-title' }, icon('speed'), 'Темп відтворення'),
          h('div', { class: 'dk-row' }, h('span', { class: 'tempo-lbl' }, '40'), h('div', { style: { flex: 1 } }, slider), h('span', { class: 'tempo-lbl' }, '300'), tempoVal, h('span', { class: 'tempo-lbl' }, 'BPM'))),
        h('div', { class: 'dk-card' },
          h('div', { class: 'dk-title' }, icon('grid_on'), 'Графічне відображення нот'),
          countdown,
          staff.el,
          h('div', { class: 'dk-row', style: { marginTop: '10px', justifyContent: 'space-between' } },
            playBtn,
            h('button', { class: 'dk-btn', onClick: () => openFullscreenGraphic(signal, () => tempo) }, icon('fullscreen'), 'Повний екран'))));
    }

    // ── Текст сигналу ──
    if (signal.signalText) {
      sections.push(h('div', { class: 'dk-card' },
        h('div', { class: 'dk-title' }, icon('text_fields'), 'Текст сигналу'),
        h('div', { class: 'signal-text' }, signal.signalText)));
    }

    // ── Партитура за паролем ──
    if (signal.partitureUrl) {
      const holder = h('div', { class: 'dk-row', style: { justifyContent: 'center' } });
      const unlock = () => {
        const err = h('div', { class: 'err', hidden: true }, 'Невірний пароль');
        const input = h('input', { type: 'password', placeholder: 'Пароль', style: { width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid var(--dk-border)', background: 'var(--dk-bg)', color: '#fff', marginBottom: '12px' } });
        const submit = () => {
          if (input.value === PARTITURE_PASSWORD) {
            d.close();
            holder.replaceChildren(
              h('img', { class: 'notation-img', src: mediaUrl(signal.partitureUrl), alt: 'Партитура' }),
              h('button', { class: 'dk-btn', style: { marginTop: '10px' }, onClick: () => openFullscreenImage(mediaUrl(signal.partitureUrl), 'Партитура') }, icon('fullscreen'), 'Повний екран'));
          } else { err.hidden = false; }
        };
        input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
        const d = openDialog([
          h('h3', {}, 'Партитура'),
          h('div', { class: 'sec-text', style: { color: 'var(--dk-text)', marginBottom: '10px' } }, 'Введіть пароль для перегляду:'),
          input, err,
          h('div', { class: 'row' },
            h('button', { class: 'dk-btn', onClick: () => d.close() }, 'Скасувати'),
            h('button', { class: 'dk-btn fill', onClick: submit }, 'Увійти')),
        ], { dark: true, dismissible: false });
        setTimeout(() => input.focus(), 50);
      };
      holder.append(h('button', { class: 'dk-btn', onClick: unlock }, icon('lock'), 'Відкрити партитуру'));
      sections.push(h('div', { class: 'dk-card' },
        h('div', { class: 'dk-title' }, icon('library_music'), 'Партитура (захищене зображення)'),
        holder));
    }

    return h('div', { class: 'page dark' },
      appBar(`Ноти — ${signal.name}`, { back: pop, cls: 'dark', small: true }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' }, sections)));
  });
}

function openFullscreenImage(src, title) {
  pushScreen(({ pop }) => h('div', { class: 'gallery' },
    h('div', { class: 'appbar dark' },
      h('div', { class: 'lead' }, h('button', { class: 'iconbtn', onClick: pop }, icon('arrow_back'))),
      h('div', { class: 'title sm' }, title)),
    h('div', { class: 'track' }, h('div', { class: 'slide', style: { overflow: 'auto' } }, h('img', { src, alt: title, style: { maxHeight: 'none', maxWidth: 'none', width: 'auto' } })))));
}

function openFullscreenGraphic(signal, getTempo) {
  pushScreen(({ pop, el: screen }) => {
    screen.classList.add('dark');
    let tempo = getTempo();
    const staff = notationStaff(signal.notationData);
    const countdown = h('div', { class: 'countdown', hidden: true });
    const tempoVal = h('span', { class: 'tempo-val' }, `${tempo}`);
    const playIc = icon('play_arrow');
    const player = notationPlayer(signal.notationData, () => tempo, {
      onCountdown: (c) => { countdown.hidden = c == null; countdown.textContent = c ?? ''; },
      onIndex: (i) => staff.setCurrent(i),
      onState: (on) => { playIc.textContent = on ? 'stop' : 'play_arrow'; },
    });
    return h('div', { class: 'page dark' },
      appBar('Графічне відображення', { back: () => { player.stop(); pop(); }, cls: 'dark', small: true }),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' },
        h('div', { class: 'dk-row', style: { marginBottom: '12px', gap: '16px' } },
          h('span', { style: { color: 'var(--gold)', fontSize: '13px' } }, 'BPM:'),
          tempoVal,
          h('input', { type: 'range', class: 'gold', min: 40, max: 300, value: tempo, style: { flex: 1, minWidth: '160px' }, onInput: (e) => { tempo = +e.target.value; tempoVal.textContent = `${tempo}`; } }),
          h('button', { class: 'dk-btn fill', onClick: () => (player.running ? player.stop() : player.start()) }, playIc)),
        countdown,
        staff.el)));
  });
}
