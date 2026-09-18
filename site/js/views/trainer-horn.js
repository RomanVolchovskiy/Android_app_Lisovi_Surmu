// Тренажер «Чарівна сурма» — ритмічна гра на кшталт Piano Tiles для сигналів,
// у 3D-перспективі: п'ять доріжок сходяться до горизонту, плитки-ноти летять
// назустріч і ростуть, наближаючись до золотої лінії.
//
// Доріжки — п'ять висот сурми (ДО, СОЛЬ, ДО2, МІ2, СОЛЬ2 — натуральний
// звукоряд рога). Плитки беруться з графічної нотації сигналу (notationData):
// довжина плитки — тривалість ноти. Влучив на лінії — звучить нота.
import { h, icon, pushScreen, appBar, openDialog, toast } from '../ui.js';
import { SITE } from '../config.js';

// Висота в notationData (0 = СОЛЬ2 … 4 = ДО) → доріжка зліва направо від
// низької до високої; частоти C4, G4, C5, E5, G5.
const PITCH_TO_LANE = [4, 3, 2, 1, 0];
const LANES = [
  { label: 'ДО', freq: 261.63 },
  { label: 'СОЛЬ', freq: 392.00 },
  { label: 'ДО2', freq: 523.25 },
  { label: 'МІ2', freq: 659.25 },
  { label: 'СОЛЬ2', freq: 783.99 },
];
// ── Клавіші для нот: свої зберігаються в браузері, типові — 1…5 ──
const DEFAULT_KEYS = ['1', '2', '3', '4', '5'];
const KEYS_STORAGE = 'horn_keys_v1';
function loadKeys() {
  try {
    const v = JSON.parse(localStorage.getItem(KEYS_STORAGE) || 'null');
    if (Array.isArray(v) && v.length === 5 && v.every((k) => typeof k === 'string' && k)) return v;
  } catch { /* ignore */ }
  return [...DEFAULT_KEYS];
}
function saveKeys(keys) { try { localStorage.setItem(KEYS_STORAGE, JSON.stringify(keys)); } catch { /* ignore */ } }
/** Назва клавіші для показу: пробіл, стрілки тощо. */
export function keyLabel(k) {
  const map = { ' ': 'Пробіл', ArrowLeft: '←', ArrowRight: '→', ArrowUp: '↑', ArrowDown: '↓', Enter: 'Enter', Tab: 'Tab', Escape: 'Esc' };
  return map[k] || (k.length === 1 ? k.toUpperCase() : k);
}
const BEATS = [4, 2, 1, 0.5, 0.25];
const FALL_SECONDS = 2.4;    // скільки секунд плитка летить від горизонту до лінії
const WINDOW_GOOD = 0.28;    // с — «добре»
const WINDOW_PERFECT = 0.10; // с — «ідеально»
const PERSPECTIVE = 0.9;     // «фокусна відстань» у секундах: менше — сильніша перспектива

// ── Синтез звуку сурми (Web Audio) ───────────────────────────────────────────
let actx = null;
function audioCtx() {
  if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
  if (actx.state === 'suspended') actx.resume();
  return actx;
}
function playTone(freq, seconds) {
  const c = audioCtx();
  const t = c.currentTime;
  const out = c.createGain();
  out.gain.setValueAtTime(0.0001, t);
  out.gain.exponentialRampToValueAtTime(0.5, t + 0.03);
  out.gain.setValueAtTime(0.5, t + Math.max(0.05, seconds - 0.12));
  out.gain.exponentialRampToValueAtTime(0.0001, t + seconds + 0.05);
  const lp = c.createBiquadFilter();
  lp.type = 'lowpass'; lp.frequency.value = 1400; lp.Q.value = 0.7;
  const saw = c.createOscillator(); saw.type = 'sawtooth'; saw.frequency.value = freq;
  const tri = c.createOscillator(); tri.type = 'triangle'; tri.frequency.value = freq;
  const vib = c.createOscillator(); vib.frequency.value = 5.5;
  const vibGain = c.createGain(); vibGain.gain.value = freq * 0.004;
  vib.connect(vibGain); vibGain.connect(saw.frequency); vibGain.connect(tri.frequency);
  const sawG = c.createGain(); sawG.gain.value = 0.35;
  const triG = c.createGain(); triG.gain.value = 0.65;
  saw.connect(sawG).connect(lp); tri.connect(triG).connect(lp);
  lp.connect(out).connect(c.destination);
  [saw, tri, vib].forEach((o) => { o.start(t); o.stop(t + seconds + 0.1); });
}

/** Нотація → плитки з часом (у секундах) та тривалістю. */
function buildTiles(notes, tempo) {
  const spb = 60 / tempo;
  let beat = 0;
  const tiles = [];
  for (const item of notes) {
    if ((item.t || 'n') === 'n') {
      const beats = BEATS[item.d | 0] ?? 1;
      tiles.push({ lane: PITCH_TO_LANE[item.p | 0] ?? 2, time: beat * spb, dur: beats * spb, hit: false, missed: false, judged: null });
      beat += beats;
    } else beat += 1; // вдих / пауза = 1 доля
  }
  return { tiles, total: beat * spb, spb };
}

export function openMagicHorn(signal) {
  pushScreen((ctx) => {
    const { pop, el: screen } = ctx;
    screen.classList.add('dark');
    const notes = signal.notationData || [];
    const baseTempo = signal.notationTempo || 90;
    let speed = 1, demo = false;
    let keys = loadKeys();
    const laneForKey = (k) => { const i = keys.indexOf(k); if (i >= 0) return i; const lower = k.length === 1 ? k.toLowerCase() : k; return keys.findIndex((x) => (x.length === 1 ? x.toLowerCase() : x) === lower); };

    // ── DOM ──
    const canvas = h('canvas', { style: { display: 'block', width: '100%', height: '100%', touchAction: 'none', cursor: 'pointer' } });
    const score = h('span', { style: { color: 'var(--gold)', fontWeight: 700, fontSize: '20px' } }, '0');
    const combo = h('span', { style: { color: '#fff', fontSize: '13px' } }, '');
    const status = h('div', { style: { position: 'absolute', left: 0, right: 0, top: '34%', textAlign: 'center', pointerEvents: 'none', fontSize: '44px', fontWeight: 700, color: 'var(--gold)', textShadow: '0 2px 8px rgba(0,0,0,.6)', transition: 'opacity .3s' } });
    const overlay = h('div', { style: { position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', background: 'rgba(20,31,22,.86)', padding: '16px', overflowY: 'auto' } });
    // клік по затемненню (поза карткою) у режимі очікування — вільна гра нотою тієї доріжки
    overlay.addEventListener('pointerdown', (e) => {
      if (e.target !== overlay || running) return;
      const r = canvas.getBoundingClientRect();
      tap(laneAt((e.clientX - r.left) * dpr, (e.clientY - r.top) * dpr));
    });
    const arena = h('div', { style: { position: 'relative', flex: 1, minHeight: 0, background: '#0f1811' } }, canvas, status, overlay);
    const info = h('span', { style: { color: 'var(--dk-text)', fontSize: '12px' } });
    const hud = h('div', { class: 'dk-row', style: { padding: '6px 12px', justifyContent: 'space-between', borderBottom: '1px solid var(--dk-border)' } },
      h('span', { class: 'dk-row', style: { gap: '6px' } }, icon('stars'), score, combo),
      h('button', { class: 'iconbtn', style: { width: '36px', height: '36px', color: 'var(--gold)' }, title: 'Пауза', onClick: () => pause() }, icon('pause')),
      info);

    // ── Стан ──
    let tiles = [], total = 0, spb = 0.6, t0 = 0, raf = 0, running = false, finished = false, pausedAt = null;
    let points = 0, streak = 0, best = 0, perfect = 0, good = 0, miss = 0, wrong = 0;
    const flashes = []; // {lane, until, color}

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const resize = () => {
      const r = arena.getBoundingClientRect();
      canvas.width = Math.max(1, Math.round(r.width * dpr));
      canvas.height = Math.max(1, Math.round(r.height * dpr));
      bg = null;
    };
    window.addEventListener('resize', resize);

    const now = () => ((pausedAt ?? performance.now()) - t0) / 1000;
    const tempo = () => baseTempo * speed;
    const updateInfo = () => { info.textContent = `${signal.name} · ${Math.round(tempo())} BPM${demo ? ' · демо' : ''}`; };
    updateInfo();

    const setStatus = (text, color = 'var(--gold)') => {
      status.textContent = text; status.style.color = color; status.style.opacity = '1';
      clearTimeout(status._t);
      status._t = setTimeout(() => { status.style.opacity = '0'; }, 500);
    };
    const updateHud = () => { score.textContent = `${points}`; combo.textContent = streak >= 2 ? `×${streak}` : ''; };

    // ── Перспектива ──
    // d — «глибина» в секундах до лінії удару (0 на лінії, більше — далі).
    // s(d) — масштаб: 1 на лінії, → 0 біля горизонту.
    const geom = () => {
      const w = canvas.width, hgt = canvas.height;
      return { w, hgt, horizonY: hgt * 0.10, hitY: hgt * 0.84, laneW: w / 5 };
    };
    const scaleAt = (d) => PERSPECTIVE / (Math.max(d, -0.35) + PERSPECTIVE);
    const project = (laneEdge, d, G) => {
      // laneEdge: 0..5 (межа доріжки); повертає екранні координати
      const s = scaleAt(d);
      const xNear = laneEdge * G.laneW;
      return { x: G.w / 2 + (xNear - G.w / 2) * s, y: G.hitY - (G.hitY - G.horizonY) * (1 - s), s };
    };
    const laneAt = (px, py) => {
      // з екранної точки — до доріжки: за y знаходимо масштаб, ним «розтискаємо» x
      const G = geom();
      const s = Math.min(1, Math.max(0.05, 1 - (G.hitY - py) / (G.hitY - G.horizonY)));
      const xNear = G.w / 2 + (px - G.w / 2) / s;
      return Math.min(4, Math.max(0, Math.floor(xNear / G.laneW)));
    };

    const judge = (tile, dt) => {
      tile.hit = true;
      if (Math.abs(dt) <= WINDOW_PERFECT) { tile.judged = 'perfect'; perfect++; points += 100 + streak * 10; setStatus('Ідеально!'); }
      else { tile.judged = 'good'; good++; points += 50 + streak * 5; setStatus('Добре', '#9CCC65'); }
      streak++; best = Math.max(best, streak);
      playTone(LANES[tile.lane].freq, Math.max(0.15, tile.dur));
      updateHud();
    };

    const tap = (lane) => {
      if (!running) { // вільна гра до старту: почути ноту й перевірити клавішу
        playTone(LANES[lane].freq, 0.4);
        flashes.push({ lane, until: performance.now() / 1000 + 0.25, color: 'rgba(212,160,23,.28)' });
        return;
      }
      if (demo || pausedAt != null) return;
      const t = now();
      let bestTile = null, bestDt = Infinity;
      for (const tile of tiles) {
        if (tile.lane !== lane || tile.hit || tile.missed) continue;
        const dt = t - tile.time;
        if (dt < -WINDOW_GOOD) break;
        if (Math.abs(dt) <= WINDOW_GOOD && Math.abs(dt) < bestDt) { bestTile = tile; bestDt = dt; }
      }
      if (bestTile) { judge(bestTile, bestDt); flashes.push({ lane, until: performance.now() / 1000 + 0.18, color: 'rgba(212,160,23,.28)' }); }
      else { wrong++; streak = 0; updateHud(); flashes.push({ lane, until: performance.now() / 1000 + 0.22, color: 'rgba(229,57,53,.25)' }); playTone(LANES[lane].freq * 0.5, 0.08); }
    };

    canvas.addEventListener('pointerdown', (e) => {
      const r = canvas.getBoundingClientRect();
      tap(laneAt((e.clientX - r.left) * dpr, (e.clientY - r.top) * dpr));
    });
    const onKey = (e) => {
      if (e.repeat || capturing) return;
      const l = laneForKey(e.key);
      if (l >= 0) { e.preventDefault(); tap(l); }
    };
    window.addEventListener('keydown', onKey);

    // ── Малювання ──
    const quad = (g, a, b, c, d) => { g.beginPath(); g.moveTo(a.x, a.y); g.lineTo(b.x, b.y); g.lineTo(c.x, c.y); g.lineTo(d.x, d.y); g.closePath(); };

    // ── Фон у мисливському стилі: небо на смерканні, місяць, силуети сосен,
    //    лісова стежка. Малюється один раз у кеш і перемальовується при resize.
    let bg = null, bgKey = '';
    const trees = Array.from({ length: 70 }, (_, i) => ({ x: (i * 0.0137 + 0.005) % 1, hgt: 0.55 + ((i * 7919) % 100) / 100 * 0.9, w: 0.6 + ((i * 104729) % 100) / 100 * 0.6 }));
    const buildBackground = (G) => {
      const { w, hgt, horizonY } = G;
      const c = document.createElement('canvas'); c.width = w; c.height = hgt;
      const g = c.getContext('2d');
      // небо: глибока зелень → бурштин заходу
      const sky = g.createLinearGradient(0, 0, 0, horizonY * 1.3);
      sky.addColorStop(0, '#0c1a10'); sky.addColorStop(0.6, '#24361f'); sky.addColorStop(1, '#6b4a17');
      g.fillStyle = sky; g.fillRect(0, 0, w, hgt);
      // зорі
      g.fillStyle = 'rgba(255,240,200,.55)';
      for (let i = 0; i < 40; i++) { const x = ((i * 977) % 1000) / 1000 * w, y = ((i * 631) % 1000) / 1000 * horizonY * 0.7; g.fillRect(x, y, 1.5 * dpr, 1.5 * dpr); }
      // місяць
      const mx = w * 0.8, my = horizonY * 0.45, mr = Math.min(w, hgt) * 0.045;
      const moon = g.createRadialGradient(mx, my, mr * 0.2, mx, my, mr * 3);
      moon.addColorStop(0, 'rgba(255,236,170,.9)'); moon.addColorStop(0.25, 'rgba(255,236,170,.35)'); moon.addColorStop(1, 'rgba(255,236,170,0)');
      g.fillStyle = moon; g.fillRect(mx - mr * 3, my - mr * 3, mr * 6, mr * 6);
      g.fillStyle = '#FFF1C1'; g.beginPath(); g.arc(mx, my, mr, 0, Math.PI * 2); g.fill();
      // світіння над стежкою біля горизонту
      const glow = g.createRadialGradient(w / 2, horizonY, 0, w / 2, horizonY, w * 0.45);
      glow.addColorStop(0, 'rgba(230,170,60,.45)'); glow.addColorStop(1, 'rgba(230,170,60,0)');
      g.fillStyle = glow; g.fillRect(0, 0, w, hgt);
      // два ряди сосен: дальній світліший, ближній темніший
      const drawTrees = (color, scale, yOff) => {
        g.fillStyle = color;
        for (const tr of trees) {
          const th = tr.hgt * horizonY * scale, tw = tr.w * horizonY * 0.55 * scale, x = tr.x * w, base = horizonY + yOff;
          g.beginPath(); g.moveTo(x - tw / 2, base); g.lineTo(x, base - th); g.lineTo(x + tw / 2, base); g.closePath(); g.fill();
          g.beginPath(); g.moveTo(x - tw * 0.36, base - th * 0.42); g.lineTo(x, base - th * 1.02); g.lineTo(x + tw * 0.36, base - th * 0.42); g.closePath(); g.fill();
        }
      };
      drawTrees('#1a2b1c', 0.8, 2 * dpr);
      drawTrees('#0b140d', 1.0, 6 * dpr);
      // лісова стежка: земля з боків
      const ground = g.createLinearGradient(0, horizonY, 0, hgt);
      ground.addColorStop(0, '#1c2a19'); ground.addColorStop(1, '#0f1a10');
      g.fillStyle = ground; g.fillRect(0, horizonY + 6 * dpr, w, hgt - horizonY);
      // доріжки — утоптана стежка, бурі відтінки
      for (let i = 0; i < 5; i++) {
        const a = project(i, 60, G), b = project(i + 1, 60, G), cc = project(i + 1, -0.35, G), d = project(i, -0.35, G);
        const grad = g.createLinearGradient(0, horizonY, 0, hgt);
        grad.addColorStop(0, i % 2 ? '#3a2d18' : '#33281a'); grad.addColorStop(1, i % 2 ? '#5a4326' : '#4e3a22');
        g.fillStyle = grad; quad(g, a, b, cc, d); g.fill();
      }
      // роздільники — мотузки
      g.strokeStyle = 'rgba(230,200,140,.35)'; g.lineWidth = 1.5 * dpr;
      for (let i = 0; i <= 5; i++) { const a = project(i, 60, G), b = project(i, -0.35, G); g.beginPath(); g.moveTo(a.x, a.y); g.lineTo(b.x, b.y); g.stroke(); }
      // серпанок біля горизонту — плитки виринають із туману
      const farY = project(0, FALL_SECONDS, G).y, fogEnd = farY + (hgt - farY) * 0.22;
      const fog = g.createLinearGradient(0, horizonY, 0, fogEnd);
      fog.addColorStop(0, 'rgba(70,75,45,.9)'); fog.addColorStop(0.5, 'rgba(50,50,30,.4)'); fog.addColorStop(1, 'rgba(50,50,30,0)');
      g.fillStyle = fog; g.fillRect(0, horizonY, w, fogEnd - horizonY);
      return c;
    };

    // Дерев'яна плитка з латунною облямівкою; стан: звичайна / влучено / промах
    const drawTile = (g, tile, a, b, c, d, alpha) => {
      g.globalAlpha = alpha;
      const lift = Math.max(2, 7 * c.s) * dpr;
      // торець дошки
      g.fillStyle = tile.missed ? '#4a1414' : '#3b2410';
      quad(g, d, c, { x: c.x, y: c.y + lift }, { x: d.x, y: d.y + lift }); g.fill();
      // верх дошки
      const grad = g.createLinearGradient(0, a.y, 0, c.y);
      if (tile.hit) { grad.addColorStop(0, tile.judged === 'perfect' ? '#FFE49A' : '#D9E8A8'); grad.addColorStop(1, tile.judged === 'perfect' ? '#D4A017' : '#8BC34A'); }
      else if (tile.missed) { grad.addColorStop(0, '#E57373'); grad.addColorStop(1, '#8E1B1B'); }
      else { grad.addColorStop(0, '#B07A3E'); grad.addColorStop(0.5, '#8B5A2B'); grad.addColorStop(1, '#6B4220'); }
      g.fillStyle = grad; quad(g, a, b, c, d); g.fill();
      // волокна деревини
      if (!tile.hit && !tile.missed) {
        g.strokeStyle = 'rgba(60,35,10,.35)'; g.lineWidth = 1 * dpr;
        for (const k of [0.25, 0.5, 0.75]) {
          const x1 = a.x + (b.x - a.x) * k, x2 = d.x + (c.x - d.x) * k;
          g.beginPath(); g.moveTo(x1, a.y + 2 * dpr); g.lineTo(x2, c.y - 2 * dpr); g.stroke();
        }
      }
      // латунна облямівка
      g.strokeStyle = tile.missed ? '#FF8A80' : tile.hit ? '#FFF3C4' : '#D4A017'; g.lineWidth = 1.6 * dpr;
      quad(g, a, b, c, d); g.stroke();
      // підпис ноти
      const fs = Math.round((9 + 6 * c.s) * dpr);
      if (c.y - a.y > fs * 1.2) {
        g.font = `bold ${fs}px Roboto, sans-serif`;
        g.fillStyle = tile.missed ? '#FFEBEE' : tile.hit ? 'rgba(0,0,0,.5)' : '#F5E6C8';
        g.fillText(tile.missed ? `\u2715 ${LANES[tile.lane].label}` : `\u266A ${LANES[tile.lane].label}`, (c.x + d.x) / 2, c.y - fs * 0.9);
      }
      g.globalAlpha = 1;
    };

    const draw = () => {
      const G = geom();
      const { w, hgt, hitY } = G;
      const g = canvas.getContext('2d');
      const t = running ? now() : -FALL_SECONDS;
      const dFar = FALL_SECONDS;
      const key = `${w}x${hgt}`;
      if (!bg || bgKey !== key) { bg = buildBackground(G); bgKey = key; }
      g.drawImage(bg, 0, 0);

      // ноти пливуть у небі над лісом, скрипковий ключ біля лінії удару
      {
        const wallT = performance.now() / 1000;
        g.font = `${Math.round(16 * dpr)}px serif`; g.textAlign = 'center'; g.textBaseline = 'middle';
        const glyphs = ['\u266A', '\u266B', '\u2669', '\u266C'];
        for (let i = 0; i < 7; i++) {
          const phase = (wallT * 0.05 + i / 7) % 1;
          const x = phase * w, y = G.horizonY * (0.25 + 0.5 * ((i * 37) % 10) / 10) + Math.sin(wallT * 1.2 + i) * 4 * dpr;
          g.fillStyle = `rgba(255,230,160,${(0.3 + 0.2 * Math.sin(wallT + i)).toFixed(2)})`;
          g.fillText(glyphs[i % 4], x, y);
        }
        g.font = `${Math.round(34 * dpr)}px serif`; g.fillStyle = 'rgba(212,160,23,.85)';
        g.fillText('\u{1D11E}', 18 * dpr, G.hitY - 2 * dpr);
      }
      // спалахи від дотиків (за «настінним» часом — працюють і до старту)
      const wall = performance.now() / 1000;
      for (const f of flashes) {
        if (f.until <= wall) continue;
        const a = project(f.lane, 60, G), b = project(f.lane + 1, 60, G), c = project(f.lane + 1, -0.35, G), d = project(f.lane, -0.35, G);
        g.fillStyle = f.color; quad(g, a, b, c, d); g.fill();
      }
      while (flashes.length && flashes[0].until <= wall) flashes.shift();
      // лінії долей, що біжать назустріч (ритм)
      if (running && spb > 0) {
        g.strokeStyle = 'rgba(255,230,180,.10)'; g.lineWidth = 1 * dpr;
        const first = Math.ceil(t / spb) * spb;
        for (let bt = first; bt < t + dFar; bt += spb) {
          const l = project(0, bt - t, G), r = project(5, bt - t, G);
          g.beginPath(); g.moveTo(l.x, l.y); g.lineTo(r.x, r.y); g.stroke();
        }
      }
      // зона та лінія удару — латунна смуга
      {
        const a = project(0, WINDOW_GOOD, G), b = project(5, WINDOW_GOOD, G), c = project(5, -WINDOW_GOOD * 0.8, G), d = project(0, -WINDOW_GOOD * 0.8, G);
        g.fillStyle = 'rgba(212,160,23,.13)'; quad(g, a, b, c, d); g.fill();
        const brass = g.createLinearGradient(0, hitY - 3 * dpr, 0, hitY + 3 * dpr);
        brass.addColorStop(0, '#FFE9A6'); brass.addColorStop(0.5, '#D4A017'); brass.addColorStop(1, '#8a6410');
        g.fillStyle = brass; g.shadowColor = 'rgba(212,160,23,.9)'; g.shadowBlur = 14 * dpr;
        g.fillRect(0, hitY - 3 * dpr, w, 6 * dpr);
        g.shadowBlur = 0;
      }
      // плитки — від дальніх до ближніх. Промахи завмирають на лінії ~1 с,
      // щоб було видно, яку ноту пропущено.
      g.textAlign = 'center'; g.textBaseline = 'middle';
      for (let i = tiles.length - 1; i >= 0; i--) {
        const tile = tiles[i];
        let dNear = tile.time - t, alpha = 1;
        if (tile.missed) {
          const since = t - tile.missedAt;
          if (since > 1.4) continue;
          dNear = Math.max(dNear, -0.08);
          alpha = since < 1.0 ? 1 : 1 - (since - 1.0) / 0.4;
        }
        const dFarEdge = dNear + tile.dur;
        if (dNear > dFar || dFarEdge < -0.35) continue;
        const dn = Math.max(dNear, -0.35), df = Math.min(dFarEdge, dFar);
        if (!tile.missed) alpha = Math.min(1, Math.max(0.15, (dFar - dn) / (dFar * 0.35)));
        const pad = 0.06;
        drawTile(g, tile,
          project(tile.lane + pad, df, G), project(tile.lane + 1 - pad, df, G),
          project(tile.lane + 1 - pad, dn, G), project(tile.lane + pad, dn, G), alpha);
      }
      // підписи доріжок на дерев'яній дошці внизу
      g.fillStyle = 'rgba(40,25,10,.85)'; g.fillRect(0, hgt - 26 * dpr, w, 26 * dpr);
      g.fillStyle = '#D4A017'; g.fillRect(0, hgt - 26 * dpr, w, 1.5 * dpr);
      g.font = `bold ${Math.round(12 * dpr)}px Roboto, sans-serif`; g.fillStyle = '#F5E6C8';
      for (let i = 0; i < 5; i++) g.fillText(`${LANES[i].label}  [${keyLabel(keys[i])}]`, (i + 0.5) * G.laneW, hgt - 13 * dpr);
      // промахи, демо, фініш
      if (running && pausedAt == null) {
        for (const tile of tiles) {
          if (tile.hit || tile.missed) continue;
          const dt = t - tile.time;
          if (demo && dt >= 0) { tile.hit = true; tile.judged = 'perfect'; playTone(LANES[tile.lane].freq, Math.max(0.15, tile.dur)); }
          else if (dt > WINDOW_GOOD) {
            tile.missed = true; tile.missedAt = t; miss++; streak = 0; updateHud(); setStatus('Промах', '#EF5350');
            flashes.push({ lane: tile.lane, until: performance.now() / 1000 + 0.3, color: 'rgba(229,57,53,.18)' });
          }
        }
        if (t > total + 1.6) finish();
      }
      raf = requestAnimationFrame(draw);
    };

    // ── Повзунок швидкості (спільний для стартового екрана і паузи) ──
    const speedControl = () => {
      const val = h('span', { class: 'tempo-val', style: { fontSize: '18px', minWidth: '84px' } });
      const upd = () => { val.textContent = `${speed.toFixed(1)}× · ${Math.round(tempo())} BPM`; updateInfo(); };
      const slider = h('input', { type: 'range', class: 'gold', min: 0.5, max: 2, step: 0.1, value: speed, style: { flex: 1, minWidth: '140px' },
        onInput: (e) => { speed = +e.target.value; upd(); } });
      upd();
      return h('div', {},
        h('div', { class: 'dk-row', style: { justifyContent: 'space-between', fontSize: '12px', color: 'var(--dk-text)' } }, h('span', {}, icon('speed'), ' Швидкість'), val),
        h('div', { class: 'dk-row' }, h('span', { class: 'tempo-lbl' }, 'повільно'), slider, h('span', { class: 'tempo-lbl' }, 'швидко')));
    };

    // ── Керування раундом ──
    const start = (isDemo) => {
      demo = isDemo;
      ({ tiles, total, spb } = buildTiles(notes, tempo()));
      points = streak = best = perfect = good = miss = wrong = 0; updateHud(); updateInfo();
      overlay.hidden = true; finished = false; pausedAt = null; running = false;
      audioCtx();
      let c = 3;
      status.style.opacity = '1'; status.textContent = `${c}`;
      const tick = () => {
        c--;
        if (c > 0) { status.textContent = `${c}`; setTimeout(tick, 700); }
        else { status.textContent = 'Грай!'; t0 = performance.now() + FALL_SECONDS * 1000; running = true; setTimeout(() => { status.style.opacity = '0'; }, 500); }
      };
      setTimeout(tick, 700);
    };

    const cardHead = () => h('div', { class: 'horn-card-head' },
      h('img', { src: 'assets/icon.png', alt: '' }),
      h('div', {}, h('div', { class: 'college' }, SITE.college), h('div', { class: 'ensemble' }, SITE.ensemble)));

    const finish = () => {
      running = false; finished = true;
      const hits = perfect + good, totalNotes = tiles.length;
      const acc = totalNotes ? Math.round(hits / totalNotes * 100) : 0;
      const stars = acc >= 95 ? '★★★' : acc >= 75 ? '★★☆' : acc >= 50 ? '★☆☆' : '☆☆☆';
      overlay.replaceChildren(h('div', { class: 'dk-card', style: { width: 'min(440px, 100%)', textAlign: 'center' } },
        cardHead(),
        h('div', { style: { fontSize: '30px', color: 'var(--gold)', letterSpacing: '4px' } }, stars),
        h('div', { style: { fontSize: '40px', fontWeight: 700, color: '#fff' } }, demo ? 'Демо' : `${points}`),
        h('div', { style: { color: 'var(--dk-text)', marginBottom: '12px' } }, demo ? 'Так звучить сигнал. Тепер спробуйте самі!' : `Точність ${acc}% · найдовша серія ×${best}`),
        demo ? null : h('div', { class: 'dk-row', style: { justifyContent: 'center', gap: '16px', fontSize: '13px', color: '#fff', marginBottom: '14px' } },
          h('span', {}, `Ідеально: ${perfect}`), h('span', {}, `Добре: ${good}`), h('span', {}, `Промахи: ${miss}`), h('span', {}, `Мимо: ${wrong}`)),
        h('div', { style: { margin: '0 0 14px', textAlign: 'left' } }, speedControl()),
        h('div', { class: 'dk-row', style: { justifyContent: 'center' } },
          h('button', { class: 'dk-btn fill', onClick: () => start(false) }, icon('replay'), 'Ще раз'),
          h('button', { class: 'dk-btn', onClick: () => start(true) }, icon('play_circle'), 'Демо'),
          h('button', { class: 'dk-btn', onClick: openKeysDialog }, icon('keyboard'), 'Клавіші'),
          h('button', { class: 'dk-btn', onClick: pop }, icon('list'), 'Інший сигнал'))));
      overlay.hidden = false;
    };

    // Пауза: кнопка або згорнута вкладка (rAF там не працює — усе було б пропущено).
    const pause = () => {
      if (!running || pausedAt != null || finished) return;
      pausedAt = performance.now();
      overlay.replaceChildren(h('div', { class: 'dk-card', style: { textAlign: 'center', width: 'min(400px, 100%)' } },
        h('div', { style: { fontSize: '20px', fontWeight: 700, color: 'var(--gold)', marginBottom: '12px' } }, 'Пауза'),
        h('div', { class: 'dk-row', style: { justifyContent: 'center' } },
          h('button', { class: 'dk-btn fill', onClick: resume }, icon('play_arrow'), 'Продовжити'),
          h('button', { class: 'dk-btn', onClick: () => { pausedAt = null; start(demo); } }, icon('replay'), 'Спочатку'))));
      overlay.hidden = false;
    };
    const resume = () => {
      if (pausedAt == null) return;
      t0 += performance.now() - pausedAt; pausedAt = null;
      overlay.hidden = true;
    };
    const onVisibility = () => { if (document.hidden) pause(); };
    document.addEventListener('visibilitychange', onVisibility);

    // ── Призначення клавіш ──
    let capturing = false;
    const openKeysDialog = () => {
      const draft = [...keys];
      const rows = LANES.map((lane, i) => {
        const badge = h('span', { style: { display: 'inline-block', minWidth: '64px', padding: '4px 10px', borderRadius: '6px', border: '1px solid var(--gold)', color: 'var(--gold)', fontWeight: 700, textAlign: 'center' } }, keyLabel(draft[i]));
        const btn = h('button', { class: 'dk-btn', style: { padding: '6px 10px', fontSize: '12px' }, onClick: () => {
          capturing = true; badge.textContent = '…'; btn.textContent = 'Натисніть клавішу';
          const onCapture = (e) => {
            e.preventDefault(); e.stopPropagation();
            if (e.key === 'Escape') { badge.textContent = keyLabel(draft[i]); }
            else {
              const dup = draft.findIndex((k, j) => j !== i && k === e.key);
              if (dup >= 0) { toast(`Клавіша вже призначена ноті ${LANES[dup].label}`, 'err'); badge.textContent = keyLabel(draft[i]); }
              else { draft[i] = e.key; badge.textContent = keyLabel(e.key); playTone(lane.freq, 0.3); }
            }
            btn.replaceChildren(icon('keyboard'), 'Змінити'); capturing = false;
            window.removeEventListener('keydown', onCapture, true);
          };
          window.addEventListener('keydown', onCapture, true);
        } }, icon('keyboard'), 'Змінити');
        return h('div', { class: 'dk-row', style: { justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px solid var(--dk-border)' } },
          h('span', { style: { color: '#fff', fontWeight: 600, minWidth: '64px' } }, lane.label), badge, btn);
      });
      const d = openDialog([
        h('h3', { style: { color: 'var(--gold)' } }, 'Клавіші для нот'),
        h('div', { style: { color: 'var(--dk-text)', fontSize: '13px', marginBottom: '10px' } }, 'Натисніть «Змінити» біля ноти, потім — бажану клавішу. Esc — скасувати.'),
        ...rows,
        h('div', { class: 'row' },
          h('button', { class: 'dk-btn', onClick: () => { keys = [...DEFAULT_KEYS]; saveKeys(keys); d.close(); toast('Клавіші скинуто до 1–5'); } }, 'Скинути'),
          h('button', { class: 'dk-btn', onClick: () => { capturing = false; d.close(); } }, 'Скасувати'),
          h('button', { class: 'dk-btn fill', onClick: () => { keys = draft; saveKeys(keys); capturing = false; d.close(); toast('Клавіші збережено', 'ok'); } }, 'Зберегти')),
      ], { dark: true, dismissible: false });
    };

    // ── Стартовий екран ──
    overlay.append(h('div', { class: 'dk-card', style: { width: 'min(460px, 100%)', textAlign: 'center' } },
      cardHead(),
      h('div', { style: { fontSize: '40px' } }, '📯'),
      h('div', { style: { fontSize: '20px', fontWeight: 700, color: 'var(--gold)', fontFamily: '"Playfair Display", Georgia, serif' } }, 'Чарівна сурма'),
      h('div', { style: { color: '#fff', fontWeight: 600, margin: '6px 0' } }, signal.name),
      h('div', { style: { color: 'var(--dk-text)', fontSize: '13px', lineHeight: 1.5, margin: '8px 0 14px' } },
        'Плитки — ноти сигналу — летять назустріч п’ятьма доріжками за висотою звуку. Торкніться доріжки, коли плитка дійде до золотої лінії, і сурма заграє ноту. До старту можна вільно грати ноти доріжками або клавішами.'),
      h('div', { style: { margin: '0 0 14px', textAlign: 'left' } }, speedControl()),
      h('div', { class: 'dk-row', style: { justifyContent: 'center' } },
        h('button', { class: 'dk-btn fill', onClick: () => start(false) }, icon('play_arrow'), 'Почати'),
        h('button', { class: 'dk-btn', onClick: () => start(true) }, icon('play_circle'), 'Демо'),
        h('button', { class: 'dk-btn', onClick: openKeysDialog }, icon('keyboard'), 'Клавіші'))));

    ctx.onPop = () => { cancelAnimationFrame(raf); window.removeEventListener('resize', resize); window.removeEventListener('keydown', onKey); document.removeEventListener('visibilitychange', onVisibility); running = false; };
    setTimeout(() => { resize(); draw(); }, 0);

    return h('div', { class: 'page dark' },
      appBar('Чарівна сурма', { back: pop, cls: 'dark', small: true }),
      h('div', { class: 'horn-plaque' },
        h('img', { src: 'assets/icon.png', alt: '' }),
        h('div', {}, h('div', { class: 'college' }, SITE.college), h('div', { class: 'ensemble' }, SITE.ensemble)),
        h('span', { class: 'notes' }, '\u{1D11E} \u266A \u266B \u2669 \u266C')),
      hud,
      arena);
  });
}
