// Тренажер «Метроном» — як metronome-online, але відбиває мисливський ріг:
// сильна доля — СОЛЬ2, слабкі — ДО2, підрозділи — тихе ДО.
//
// Точність: удари плануються наперед у часі AudioContext (lookahead-планувальник),
// тому таймери сторінки не впливають на ритм; UI лише «ловить» заплановані удари.
import { h, icon, pushScreen, appBar, toast } from '../ui.js';
import { SITE } from '../config.js';
import { audioCtx, playTone, HORN } from '../horn-synth.js';

const STORAGE = 'metronome_v1';
const TEMPO_NAMES = [
  [40, 'Grave'], [60, 'Largo'], [66, 'Larghetto'], [76, 'Adagio'], [108, 'Andante'],
  [120, 'Moderato'], [156, 'Allegro'], [176, 'Vivace'], [200, 'Presto'], [251, 'Prestissimo'],
];
const SIGNATURES = ['1/4', '2/4', '3/4', '4/4', '5/4', '6/8', '7/8', '9/8', '12/8'];
const SUBDIVISIONS = [[1, '♩', 'Чверті'], [2, '♫', 'Восьмі'], [3, '♪♪♪', 'Тріолі'], [4, '♬♬', 'Шістнадцяті']];
const ACCENT_LABEL = ['тиша', 'звичайна', 'акцент'];

const tempoName = (bpm) => TEMPO_NAMES.find(([max]) => bpm < max)?.[1] || 'Prestissimo';

function loadSettings() {
  try { return { ...JSON.parse(localStorage.getItem(STORAGE) || '{}') }; } catch { return {}; }
}

export function openMetronome() {
  pushScreen((ctx) => {
    const { pop, el: screen } = ctx;
    screen.classList.add('dark');
    const saved = loadSettings();
    const st = {
      bpm: saved.bpm ?? 90,
      sig: SIGNATURES.includes(saved.sig) ? saved.sig : '4/4',
      sub: [1, 2, 3, 4].includes(saved.sub) ? saved.sub : 1,
      volume: saved.volume ?? 0.8,
      accents: Array.isArray(saved.accents) ? saved.accents : null,
    };
    const beatsInBar = () => +st.sig.split('/')[0];
    const noteValue = () => +st.sig.split('/')[1];
    const ensureAccents = () => {
      const n = beatsInBar();
      if (!st.accents || st.accents.length !== n) {
        // сильна перша; у 6/8, 9/8, 12/8 — ще й кожна третя
        st.accents = Array.from({ length: n }, (_, i) => (i === 0 || (noteValue() === 8 && i % 3 === 0) ? 2 : 1));
      }
    };
    ensureAccents();
    const save = () => { try { localStorage.setItem(STORAGE, JSON.stringify(st)); } catch { /* ignore */ } };

    // ── Планувальник ──
    let running = false, timer = null, nextTime = 0, beat = 0, subIdx = 0;
    const queue = []; // {time, beat, sub} — для підсвітки
    const LOOKAHEAD = 0.12, INTERVAL = 25;
    // тривалість однієї долі: у розмірах x/8 доля — восьма
    const beatSeconds = () => (60 / st.bpm) * (noteValue() === 8 ? 0.5 : 1);

    const scheduleNote = (time, b, s) => {
      const acc = st.accents[b];
      if (s === 0) {
        if (acc === 2) playTone(HORN[4].freq, 0.2, time, st.volume);
        else if (acc === 1) playTone(HORN[2].freq, 0.15, time, st.volume * 0.85);
      } else {
        playTone(HORN[0].freq, 0.07, time, st.volume * 0.35);
      }
      queue.push({ time, beat: b, sub: s });
    };
    const tick = () => {
      const c = audioCtx();
      while (nextTime < c.currentTime + LOOKAHEAD) {
        scheduleNote(nextTime, beat, subIdx);
        nextTime += beatSeconds() / st.sub;
        subIdx++;
        if (subIdx >= st.sub) { subIdx = 0; beat = (beat + 1) % beatsInBar(); }
      }
    };
    const start = () => {
      const c = audioCtx();
      running = true; beat = 0; subIdx = 0; nextTime = c.currentTime + 0.08; queue.length = 0;
      timer = setInterval(tick, INTERVAL); tick();
      playBtn.replaceChildren(icon('stop'), 'Стоп');
    };
    const stop = () => {
      running = false; clearInterval(timer); timer = null; queue.length = 0; curBeat = -1;
      playBtn.replaceChildren(icon('play_arrow'), 'Старт');
      renderBeats();
    };
    const restartIfRunning = () => { if (running) { stop(); start(); } };

    // ── Tap tempo ──
    let taps = [];
    const tap = () => {
      const now = performance.now();
      if (taps.length && now - taps[taps.length - 1] > 2000) taps = [];
      taps.push(now);
      if (taps.length > 6) taps.shift();
      if (taps.length >= 2) {
        const gaps = taps.slice(1).map((t, i) => t - taps[i]);
        const avg = gaps.reduce((a, b) => a + b, 0) / gaps.length;
        setBpm(Math.round(60000 / avg));
      }
      playTone(HORN[2].freq, 0.1, null, st.volume * 0.7);
    };

    // ── UI ──
    const bpmVal = h('div', { style: { fontSize: '64px', fontWeight: 700, color: 'var(--gold)', lineHeight: 1, fontFamily: '"Playfair Display", Georgia, serif' } });
    const bpmName = h('div', { style: { color: 'var(--dk-text)', fontSize: '14px', letterSpacing: '2px', textTransform: 'uppercase' } });
    const slider = h('input', { type: 'range', class: 'gold', min: 30, max: 250, step: 1, style: { width: '100%' },
      onInput: (e) => setBpm(+e.target.value, false) });
    const setBpm = (v, sync = true) => {
      st.bpm = Math.min(250, Math.max(30, Math.round(v)));
      bpmVal.textContent = `${st.bpm}`; bpmName.textContent = tempoName(st.bpm);
      if (sync) slider.value = st.bpm;
      save();
    };
    const stepBtn = (label, d) => h('button', { class: 'dk-btn', style: { minWidth: '52px', justifyContent: 'center', padding: '8px 10px' }, onClick: () => setBpm(st.bpm + d) }, label);

    // доріжка долей
    const beatsRow = h('div', { style: { display: 'flex', gap: '8px', justifyContent: 'center', flexWrap: 'wrap', minHeight: '48px' } });
    let curBeat = -1, curSub = 0; // eslint-disable-line no-unused-vars
    const renderBeats = () => {
      beatsRow.replaceChildren(...st.accents.map((acc, i) => {
        const active = i === curBeat;
        const size = acc === 2 ? 44 : acc === 1 ? 36 : 28;
        return h('button', {
          title: `Доля ${i + 1}: ${ACCENT_LABEL[acc]} — натисніть, щоб змінити`,
          style: {
            width: `${size}px`, height: `${size}px`, borderRadius: '50%', alignSelf: 'center',
            border: `2px solid ${acc === 0 ? 'rgba(204,221,204,.3)' : 'var(--gold)'}`,
            background: active ? (acc === 2 ? '#FFE9A6' : '#D4A017') : (acc === 2 ? 'rgba(212,160,23,.35)' : acc === 1 ? 'rgba(212,160,23,.15)' : 'transparent'),
            boxShadow: active ? '0 0 16px rgba(212,160,23,.9)' : 'none', color: active ? '#1b2a1e' : 'var(--dk-text)',
            fontWeight: 700, fontSize: '13px', transition: 'background .05s',
          },
          onClick: () => { st.accents[i] = (st.accents[i] + 2) % 3; save(); renderBeats(); },
        }, `${i + 1}`);
      }));
    };

    // маятник
    const canvas = h('canvas', { style: { width: '100%', height: '150px', display: 'block' } });
    let raf = 0;
    const draw = () => {
      const dpr = Math.min(devicePixelRatio || 1, 2);
      const w = canvas.clientWidth * dpr, hgt = 150 * dpr;
      if (canvas.width !== w || canvas.height !== hgt) { canvas.width = w; canvas.height = hgt; }
      const g = canvas.getContext('2d');
      g.clearRect(0, 0, w, hgt);
      // підсвітка поточної долі — з черги запланованих ударів
      if (running) {
        const now = audioCtx().currentTime;
        let changed = false;
        while (queue.length && queue[0].time <= now) { const q = queue.shift(); if (q.beat !== curBeat) changed = true; curBeat = q.beat; curSub = q.sub; }
        if (changed) renderBeats();
      }
      // маятник: кут за фазою долі (пів періоду на долю — як у механічного метронома)
      const period = beatSeconds() * 2;
      const phase = running ? ((audioCtx().currentTime - phaseZero) % period) / period : 0.25;
      const angle = Math.sin(phase * Math.PI * 2) * 0.55;
      const px = w / 2, py = hgt * 0.92, len = hgt * 0.78;
      const bx = px + Math.sin(angle) * len, by = py - Math.cos(angle) * len;
      // корпус: дерев'яна дуга
      g.strokeStyle = 'rgba(90,59,28,.9)'; g.lineWidth = 10 * dpr;
      g.beginPath(); g.arc(px, py, len + 8 * dpr, Math.PI * 1.22, Math.PI * 1.78); g.stroke();
      g.strokeStyle = 'rgba(212,160,23,.5)'; g.lineWidth = 1.5 * dpr;
      g.beginPath(); g.arc(px, py, len + 8 * dpr, Math.PI * 1.22, Math.PI * 1.78); g.stroke();
      // поділки
      for (let i = -3; i <= 3; i++) {
        const an = i * 0.19, x1 = px + Math.sin(an) * (len + 2 * dpr), y1 = py - Math.cos(an) * (len + 2 * dpr);
        const x2 = px + Math.sin(an) * (len + 14 * dpr), y2 = py - Math.cos(an) * (len + 14 * dpr);
        g.strokeStyle = 'rgba(245,230,200,.6)'; g.lineWidth = (i === 0 ? 2 : 1) * dpr;
        g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
      }
      // стрижень
      g.strokeStyle = '#B07A3E'; g.lineWidth = 4 * dpr; g.lineCap = 'round';
      g.beginPath(); g.moveTo(px, py); g.lineTo(bx, by); g.stroke();
      // латунний грузик
      const r = 13 * dpr;
      const grad = g.createRadialGradient(bx - r * .3, by - r * .3, r * .1, bx, by, r);
      grad.addColorStop(0, '#FFF1C1'); grad.addColorStop(0.5, '#D4A017'); grad.addColorStop(1, '#8a6410');
      g.fillStyle = grad; g.beginPath(); g.arc(bx, by, r, 0, Math.PI * 2); g.fill();
      // вісь
      g.fillStyle = '#3b2410'; g.beginPath(); g.arc(px, py, 7 * dpr, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#D4A017'; g.beginPath(); g.arc(px, py, 3 * dpr, 0, Math.PI * 2); g.fill();
      raf = requestAnimationFrame(draw);
    };
    let phaseZero = 0;

    // фаза маятника прив'язується до старту
    const origStart = start;
    const startWrapped = () => { origStart(); phaseZero = nextTime - 0.08 - beatSeconds() * 0.5; };

    const playBtn = h('button', { class: 'dk-btn fill', style: { fontSize: '16px', padding: '12px 28px' }, onClick: () => (running ? stop() : startWrapped()) }, icon('play_arrow'), 'Старт');

    const sigSel = h('select', { style: { padding: '8px 10px', borderRadius: '8px', background: 'var(--dk-bg)', color: '#fff', border: '1px solid var(--gold)' },
      onChange: (e) => { st.sig = e.target.value; st.accents = null; ensureAccents(); save(); renderBeats(); restartIfRunning(); } },
      SIGNATURES.map((s) => h('option', { value: s, selected: s === st.sig }, s)));
    const subBtns = SUBDIVISIONS.map(([n, sym, title]) => h('button', { class: `dk-btn ${st.sub === n ? 'fill' : ''}`, title, style: { padding: '6px 12px' },
      onClick: () => { st.sub = n; subBtns.forEach((b, k) => b.classList.toggle('fill', SUBDIVISIONS[k][0] === n)); save(); restartIfRunning(); } }, sym));
    const volume = h('input', { type: 'range', class: 'gold', min: 0, max: 1, step: 0.05, value: st.volume, style: { width: '140px' }, onInput: (e) => { st.volume = +e.target.value; save(); } });

    const card = (title, ic, ...children) => h('div', { class: 'dk-card' }, h('div', { class: 'dk-title' }, icon(ic), title), ...children);

    setBpm(st.bpm); renderBeats();
    const onKey = (e) => {
      if (e.repeat) return;
      if (e.key === ' ') { e.preventDefault(); running ? stop() : startWrapped(); }
      else if (e.key === 'ArrowUp' || e.key === '+') setBpm(st.bpm + 1);
      else if (e.key === 'ArrowDown' || e.key === '-') setBpm(st.bpm - 1);
      else if (e.key.toLowerCase() === 't' || e.key.toLowerCase() === 'е') tap();
    };
    window.addEventListener('keydown', onKey);
    const onVisibility = () => { if (document.hidden && running) stop(); };
    document.addEventListener('visibilitychange', onVisibility);
    ctx.onPop = () => { stop(); cancelAnimationFrame(raf); window.removeEventListener('keydown', onKey); document.removeEventListener('visibilitychange', onVisibility); };
    setTimeout(draw, 0);

    return h('div', { class: 'page dark' },
      appBar('Метроном', { back: pop, cls: 'dark', small: true }),
      h('div', { class: 'horn-plaque' },
        h('img', { src: 'assets/icon.png', alt: '' }),
        h('div', {}, h('div', { class: 'college' }, SITE.college), h('div', { class: 'ensemble' }, SITE.ensemble)),
        h('span', { class: 'notes' }, '𝄞 ♩ ♩ ♩ ♩')),
      h('div', { class: 'body' }, h('div', { class: 'body-inner' },
        h('div', { class: 'dk-card', style: { textAlign: 'center' } },
          canvas,
          h('div', { style: { margin: '6px 0 2px' } }, bpmVal), bpmName,
          h('div', { style: { margin: '12px 0 6px' } }, slider),
          h('div', { class: 'dk-row', style: { justifyContent: 'center', gap: '6px' } }, stepBtn('−5', -5), stepBtn('−1', -1), playBtn, stepBtn('+1', 1), stepBtn('+5', 5)),
          h('div', { class: 'dk-row', style: { justifyContent: 'center', marginTop: '10px' } },
            h('button', { class: 'dk-btn', onClick: tap }, icon('touch_app'), 'Відстукати темп (T)'))),
        card('Долі такту', 'radio_button_checked',
          h('div', { class: 's', style: { color: 'var(--dk-text)', fontSize: '12px', marginBottom: '8px' } }, 'Натисніть на долю, щоб перемкнути: акцент → звичайна → тиша'),
          beatsRow),
        card('Розмір і підрозділ долі', 'straighten',
          h('div', { class: 'dk-row', style: { gap: '14px' } },
            h('span', { class: 'dk-row', style: { gap: '8px' } }, h('span', { style: { color: 'var(--dk-text)', fontSize: '13px' } }, 'Розмір'), sigSel),
            h('span', { class: 'dk-row', style: { gap: '6px' } }, h('span', { style: { color: 'var(--dk-text)', fontSize: '13px' } }, 'Підрозділ'), ...subBtns))),
        card('Звук', 'volume_up',
          h('div', { class: 'dk-row', style: { gap: '12px' } }, h('span', { style: { color: 'var(--dk-text)', fontSize: '13px' } }, 'Гучність'), volume,
            h('span', { style: { color: 'var(--dk-text)', fontSize: '12px' } }, 'Сильна доля — СОЛЬ2, слабкі — ДО2, підрозділи — тихе ДО. Пробіл — старт/стоп, ↑/↓ — темп.'))))));
  });
}
