// «Дихальний тренажер» для духовиків — сайт. Той самий каталог, програми й
// правила, що в застосунку (логіка — ../breath-gym-core.js). Результати й
// налаштування — лише в цьому браузері (localStorage).
import { h, icon, toast, pushScreen, appBar, confirmDialog, openDialog, clear } from '../ui.js';
import { playTone } from '../horn-synth.js';
import {
  EXERCISES, BY_ID, BLOCKS, ROMANS, PROGRAMS, INTRO, STRELNIKOVA_WARNING, MODE, MODE_LABEL, PHASE_LABEL, PHASE_SPOKEN,
  defaults, settingsFor, bpmAdjustable, seriesAdjustable, buildTimeline, stepEnd, estimateSeconds, estimateProgramSeconds,
  BreathEngine, StopwatchSession, FreeTimer, ProgramRun, weekCounts, currentStreak, longestStreak, chartPoints, bestOf, fmt,
} from '../breath-gym-core.js';

/** append без null/false — DOM-метод append вивів би їх як текст «null». */
const put = (el, ...kids) => { el.append(...kids.flat(Infinity).filter((k) => k != null && k !== false)); return el; };

// ── Збереження ──────────────────────────────────────────────────────────
const K = { attempts: 'bgym_attempts', sessions: 'bgym_sessions', settings: 'bgym_settings', intro: 'bgym_intro_seen', ex: 'bgym_ex_' };
const load = (key, fallback) => { try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; } catch { return fallback; } };
const save = (key, v) => { try { localStorage.setItem(key, JSON.stringify(v)); } catch { /* приватний режим тощо */ } };

const attempts = () => (Array.isArray(load(K.attempts, [])) ? load(K.attempts, []) : []).filter((a) => a && typeof a.seconds === 'number');
const sessions = () => (Array.isArray(load(K.sessions, [])) ? load(K.sessions, []) : []).filter((s) => s && typeof s.at === 'number');
const addAttempt = (a) => save(K.attempts, [...attempts(), a]);
const addSession = (exerciseId, seconds) => save(K.sessions, [...sessions(), { exerciseId, at: Date.now(), seconds, completed: true }].slice(-2000));
const recordOf = (id) => bestOf(attempts().filter((a) => a.exerciseId === id));

const DEFAULT_SETTINGS = { metronome: true, volume: 0.8, vibration: true, voice: false };
const settings = () => ({ ...DEFAULT_SETTINGS, ...load(K.settings, {}) });
const exSettings = (e) => settingsFor(e, load(K.ex + e.id, null));

// ── Звук, вібрація, голос ───────────────────────────────────────────────
const NOTE = { inhale: 659.25, exhale: 261.63, accent: 783.99, beat: 523.25, sub: 261.63, end: 783.99 };
const tone = (f, sec, gain) => { try { playTone(f, sec, null, gain * settings().volume); } catch { /* аудіо недоступне */ } };
const vibrate = (ms) => { if (settings().vibration) try { navigator.vibrate?.(ms); } catch { /* немає */ } };

function ukVoice() {
  try { return speechSynthesis.getVoices().find((v) => /^uk/i.test(v.lang)) || null; } catch { return null; }
}
function say(text) {
  const v = ukVoice();
  if (!v) return;
  try {
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.voice = v; u.lang = v.lang; u.rate = 1;
    speechSynthesis.speak(u);
  } catch { /* немає синтезу */ }
}
const MIN_SPOKEN_MS = 1500; // коротші фази не озвучуються — голос не встигне

const sound = {
  phase(step) {
    vibrate(30);
    const s = settings();
    if (s.voice && step.duration >= MIN_SPOKEN_MS) say(PHASE_SPOKEN[step.type]);
  },
  beat(step, b) {
    const s = settings();
    if (!s.metronome || step.isSeriesRest) return;
    if (b === 0) {
      if (s.voice && step.duration >= MIN_SPOKEN_MS && ukVoice()) return;
      if (step.type === 'inhale') tone(NOTE.inhale, 0.35, 0.8);
      else if (step.type === 'exhale') tone(NOTE.exhale, 0.35, 0.8);
      else if (step.type === 'rest') tone(NOTE.sub, 0.07, 0.35);
      else tone(NOTE.accent, 0.2, 1);
      return;
    }
    if (step.type === 'rest') tone(NOTE.sub, 0.07, 0.35);
    else tone(NOTE.beat, 0.15, step.type === 'action' ? 1 : 0.7);
  },
  cue(type) {
    vibrate(30);
    const s = settings();
    if (s.voice && ukVoice()) { say(PHASE_SPOKEN[type]); return; }
    if (s.metronome) tone(type === 'inhale' ? NOTE.inhale : NOTE.exhale, 0.35, 0.8);
  },
  countdown(last) { if (settings().metronome) tone(last ? NOTE.accent : NOTE.beat, last ? 0.2 : 0.15, 0.8); },
  timeUp() { vibrate(200); if (settings().voice) say('Час вийшов'); if (settings().metronome) tone(NOTE.end, 0.7, 1); },
};

/** Екран не гасне, поки відкрита вправа. */
function keepAwake() {
  let lock = null, released = false;
  const req = () => { try { navigator.wakeLock?.request('screen').then((l) => { if (released) l.release(); else lock = l; }).catch(() => {}); } catch { /* немає */ } };
  req();
  const onVis = () => { if (document.visibilityState === 'visible' && !released) req(); };
  document.addEventListener('visibilitychange', onVis);
  return () => { released = true; document.removeEventListener('visibilitychange', onVis); try { lock?.release(); } catch { /* ок */ } };
}

// ── Стилі (кольори фаз; темна палітра лише в екранах тренажера) ──────────
function ensureStyles() {
  if (document.getElementById('bgym-style')) return;
  document.head.append(h('style', { id: 'bgym-style' }, `
.bgym { --ph-inhale:#1565C0; --ph-exhale:#2E6B30; --ph-hold:#6D4C41; --ph-action:#B3261E; --ph-rest:#5F6368; --ph-on:#fff;
  --bg-bg:var(--bg); --bg-card:#fff; --bg-text:rgba(0,0,0,.87); --bg-muted:#5f5f5f; --bg-line:#d9d4cc; }
@media (prefers-color-scheme: dark) {
  .bgym.page { --ph-inhale:#90CAF9; --ph-exhale:#A5D6A7; --ph-hold:#BCAAA4; --ph-action:#FFB4AB; --ph-rest:#C4C7C5; --ph-on:#111;
    --bg-bg:#121a14; --bg-card:#1e2a21; --bg-text:#e3ebe3; --bg-muted:#a9b8a9; --bg-line:#3b4a3e; }
  .bgym.page .tile { background: var(--bg-card); color: var(--bg-text); }
  .bgym.page .tile .s, .bgym.page .sec-title { color: var(--bg-muted); }
  .bgym.page .btn.text { color: #A5D6A7; }
}
.bgym.page { background: var(--bg-bg); color: var(--bg-text); }
.bgym .muted { color: var(--bg-muted); font-size: 13px; }
.bgym .box { border-radius: 12px; padding: 12px; margin-top: 12px; display: flex; gap: 10px; align-items: flex-start; line-height: 1.45; }
.bgym .box.warn { background: rgba(198,40,40,.12); } .bgym .box.info { background: rgba(47,79,47,.1); }
.bgym .row { display: flex; align-items: center; gap: 10px; margin: 8px 0; }
.bgym .row > .lbl { width: 90px; flex: none; }
.bgym .stepper { display: inline-flex; align-items: center; gap: 4px; }
.bgym .stepper b { width: 36px; text-align: center; font-size: 18px; }
.bgym .seg { display: inline-flex; border: 1px solid var(--bg-line); border-radius: 20px; overflow: hidden; }
.bgym .seg button { padding: 8px 14px; } .bgym .seg button.on { background: rgba(47,79,47,.18); font-weight: 700; }
.bgym .ctl { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
.bgym .ctl button { min-height: 56px; border-radius: 28px; font-weight: 600; display: flex; flex-direction: column; align-items: center; justify-content: center; border: 1px solid var(--bg-line); }
.bgym .ctl button.fill { background: var(--primary); color: #fff; border: none; }
.bgym .ctl button:disabled { opacity: .4; }
.bgym .phase { font-size: clamp(36px, 11vw, 52px); font-weight: 900; letter-spacing: 2px; text-align: center; line-height: 1.1; }
.bgym .hint { font-size: clamp(18px, 5vw, 24px); text-align: center; margin-top: 4px; }
.bgym .stage { display: grid; place-items: center; margin: 12px auto; }
.bgym .circle { border-radius: 50%; display: grid; place-items: center; font-weight: 700; color: var(--ph-on); will-change: transform; }
.bgym .navcards { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin-bottom: 4px; }
.bgym .navcards .tile { margin: 0; flex-direction: column; align-items: flex-start; cursor: pointer; }
.bgym-tab .prog { background: #C8E6C9; cursor: pointer; }
`));
}
const phaseVar = (t) => `var(--ph-${t})`;

// ── Вкладка в «Навчальних тренажерах» ───────────────────────────────────
export function breathGymTrainer() {
  ensureStyles();
  if (!load(K.intro, false)) { save(K.intro, true); setTimeout(showIntro, 0); }
  const navTile = (ic, t, s, onClick) => h('div', { class: 'tile', role: 'button', tabindex: 0, onClick },
    h('div', { style: { display: 'flex', gap: '8px', alignItems: 'center' } }, icon(ic), h('div', { class: 't', style: { fontSize: '16px' } }, t)),
    h('div', { class: 's' }, s));
  const blocks = Object.entries(BLOCKS).map(([n, title]) => [
    h('div', { class: 'sec-title' }, `${ROMANS[n - 1]}. ${title}`),
    ...EXERCISES.filter((e) => e.block === Number(n)).map((e) => h('div', { class: 'tile', style: { cursor: 'pointer' }, onClick: () => openExercise(e) },
      icon(e.mode === MODE.guided ? 'air' : e.mode === MODE.stopwatch ? 'timer' : 'hourglass_bottom'),
      h('div', { class: 'grow' }, h('div', { class: 't' }, e.title),
        h('div', { class: 's' }, `${e.source} · ${fmt.approx(estimateSeconds(e, exSettings(e)))}`),
        e.needsItem ? h('div', { class: 's' }, `Потрібно: ${e.needsItem}`) : null),
      icon('chevron_right', ''))),
  ]).flat();
  return h('div', { class: 'bgym bgym-tab' },
    h('div', { class: 'navcards' },
      navTile('insights', 'Прогрес', 'Тиждень, серія днів, рекорди, історія', openProgress),
      navTile('settings', 'Налаштування', 'Звук, вібрація, голос, скидання даних', openSettings)),
    h('div', { style: { display: 'flex', alignItems: 'center' } },
      h('div', { class: 'sec-title grow', style: { flex: 1 } }, 'Програми'),
      h('button', { class: 'iconbtn dim', title: 'Про тренажер', 'aria-label': 'Про тренажер', onClick: showIntro }, icon('info'))),
    ...PROGRAMS.map((p) => h('div', { class: 'tile prog', style: { background: '#C8E6C9', cursor: 'pointer' }, onClick: () => openProgram(p) },
      icon('playlist_play'),
      h('div', { class: 'grow' }, h('div', { class: 't' }, p.title),
        h('div', { class: 's' }, `${p.durationLabel} · ${fmt.exercises(p.exerciseIds.length)}`), h('div', { class: 's' }, p.description)),
      icon('chevron_right', ''))),
    h('div', { class: 'sec-title' }, 'Вправи'),
    ...blocks);
}

function showIntro() {
  const d = openDialog(h('div', {},
    h('h3', { style: { margin: '0 0 12px' } }, 'Про тренажер'),
    h('div', { style: { lineHeight: 1.5 } }, INTRO),
    h('div', { style: { textAlign: 'right', marginTop: '16px' } }, h('button', { class: 'btn text', onClick: () => d.close() }, 'Зрозуміло'))));
}

/** Повноекранний екран тренажера; результат — через finish(value). */
function screen(title, build) {
  return new Promise((resolve) => {
    let result = false, cleanup = null;
    pushScreen((ctx) => {
      ctx.onPop = () => { cleanup?.(); resolve(result); };
      const api = { pop: ctx.pop, finish: (v) => { result = v; ctx.pop(); }, setResult: (v) => { result = v; }, onCleanup: (f) => { cleanup = f; } };
      const body = h('div', { class: 'body-inner', style: { maxWidth: '640px' } });
      build(body, api);
      return h('div', { class: 'page bgym' }, appBar(title, { back: ctx.pop, small: true }), h('div', { class: 'body' }, body));
    });
  });
}

// ── Картка вправи ───────────────────────────────────────────────────────
function openExercise(e) {
  ensureStyles();
  screen(e.title, (body) => {
    let s = exSettings(e);
    const setS = (next) => {
      const norm = next.repeats === e.groups[0]?.repeats ? { ...next, repeats: null } : next;
      s = norm; save(K.ex + e.id, s); render();
    };
    const stepper = (label, value, min, max, on) => h('div', { class: 'row' }, h('span', { class: 'lbl' }, label),
      h('span', { class: 'stepper' },
        h('button', { class: 'iconbtn dim', 'aria-label': `${label}: менше`, disabled: value <= min, onClick: () => on(value - 1) }, icon('remove_circle_outline')),
        h('b', {}, String(value)),
        h('button', { class: 'iconbtn dim', 'aria-label': `${label}: більше`, disabled: value >= max, onClick: () => on(value + 1) }, icon('add_circle_outline'))));
    const render = () => {
      const rec = e.mode === MODE.stopwatch ? recordOf(e.id) : 0;
      const custom = JSON.stringify(s) !== JSON.stringify(defaults(e));
      const settingsRows = [];
      if (bpmAdjustable(e)) {
        settingsRows.push(h('div', { class: 'row' }, h('span', { class: 'lbl' }, 'Темп'),
          h('input', { type: 'range', min: e.bpmMin, max: e.bpmMax, value: s.bpm, style: { flex: 1 }, 'aria-label': 'Темп, ударів за хвилину',
            onInput: (ev) => { s = { ...s, bpm: Number(ev.target.value) }; bpmLbl.textContent = `${s.bpm} уд/хв`; },
            onChange: () => setS(s) }),
          bpmLbl));
      }
      if (seriesAdjustable(e)) settingsRows.push(stepper('Серії', s.series, e.seriesMin, e.seriesMax, (v) => setS({ ...s, series: v })));
      if (e.repeatsAdjustable) settingsRows.push(stepper('Повтори', s.repeats ?? e.groups[0].repeats, 1, 20, (v) => setS({ ...s, repeats: v })));
      if (e.hasSyllable) {
        settingsRows.push(h('div', { class: 'row' }, h('span', { class: 'lbl' }, 'Склад'), h('span', { class: 'seg', role: 'group' },
          ...[['ту', 'ту (з атакою)'], ['ху', 'ху (без атаки)']].map(([v, l]) => h('button', { class: s.syllable === v ? 'on' : '', 'aria-pressed': String(s.syllable === v), onClick: () => setS({ ...s, syllable: v }) }, l)))));
      }
      put(clear(body), 
        h('div', { class: 'chips-inline' },
          h('span', { class: 'chip' }, MODE_LABEL[e.mode]),
          h('span', { class: 'chip' }, fmt.approx(estimateSeconds(e, s))),
          h('span', { class: 'chip' }, `${ROMANS[e.block - 1]}. ${BLOCKS[e.block]}`),
          rec ? h('span', { class: 'chip' }, `Рекорд: ${fmt.sec(rec)}`) : null),
        h('div', { style: { fontSize: '17px', lineHeight: 1.5, marginTop: '8px' } }, e.description),
        h('div', { class: 'muted', style: { marginTop: '6px' } }, `Джерело: ${e.source}`),
        e.needsItem ? h('div', { class: 'box info' }, icon('backpack'), h('div', {}, h('b', {}, 'Потрібно: '), e.needsItem)) : null,
        e.warning ? h('div', { class: 'box warn' }, icon('warning'), h('div', {}, h('b', {}, 'Увага: '), e.warning)) : null,
        e.benchmark ? h('div', { class: 'box info' }, icon('emoji_events'), h('div', {}, e.benchmark)) : null,
        e.tips.length ? h('div', { class: 'box info' }, icon('lightbulb'), h('div', {}, h('b', {}, 'Підказки: '), e.tips.join('; '))) : null,
        settingsRows.length ? h('div', {},
          h('div', { style: { display: 'flex', alignItems: 'center', marginTop: '16px' } },
            h('div', { class: 'sec-title', style: { flex: 1, margin: 0 } }, 'Налаштування'),
            h('button', { class: 'btn text', disabled: !custom, onClick: () => setS(defaults(e)) }, 'За замовчуванням')),
          h('div', { class: 'muted' }, 'Налаштування запам\'ятовуються й діють і в програмах'),
          ...settingsRows) : null,
        h('button', { class: 'btn block', style: { padding: '16px', marginTop: '20px', fontSize: '17px' },
          onClick: async () => { await runExercise(e, s, { allowRepeat: true }); render(); } }, icon('play_arrow'), 'Почати'));
    };
    const bpmLbl = h('span', { style: { width: '72px', textAlign: 'right' } }, `${s.bpm} уд/хв`);
    render();
  });
}

/** Запускає вправу; true — виконано. */
function runExercise(e, s, opts = {}) {
  if (e.mode === MODE.stopwatch) return runStopwatch(e);
  if (e.mode === MODE.freeTimer) return runTimer(e);
  return runGuided(e, s, opts);
}

// ── Виконання GUIDED ────────────────────────────────────────────────────
const MIN_L = 0.45, MID_L = 0.68, MAX_L = 1;
const ease = (t) => { const x = Math.min(1, Math.max(0, t)); return x < 0.5 ? 2 * x * x : 1 - ((-2 * x + 2) ** 2) / 2; };

function runGuided(e, s, { allowRepeat = false } = {}) {
  return screen(e.title, (body, api) => {
    const steps = buildTimeline(e, s);
    const engine = new BreathEngine(steps);
    // Рівень кола на початку кожного кроку, ціль вдиху, «короткий вдих», номер у серії.
    const startL = [], target = [], sniff = [], countLbl = [];
    let level = steps[0]?.type !== 'inhale' ? MAX_L : MIN_L, inhaleNo = 0;
    const perSeries = steps.filter((x) => x.series === 1 && x.type === 'inhale').length;
    steps.forEach((st, i) => {
      const next = steps[i + 1];
      startL[i] = level;
      sniff[i] = st.type === 'inhale' && (!next || next.type === 'inhale' || next.isSeriesRest);
      target[i] = next?.swell ? MID_L : MAX_L;
      level = st.type === 'inhale' ? (sniff[i] ? MID_L : target[i]) : st.type === 'exhale' ? MIN_L : st.type === 'rest' ? MID_L : level;
      if (st.isSeriesRest) { inhaleNo = 0; countLbl[i] = ''; }
      else if (e.block === 2) { if (st.type === 'inhale') inhaleNo++; countLbl[i] = `Вдих ${inhaleNo} / ${perSeries}`; }
      else countLbl[i] = `Повтор ${st.repeat} / ${st.repeatsTotal}`;
    });
    const scaleOf = (st) => {
      const p = engine.stepProgress, a = startL[st.index];
      switch (st.type) {
        case 'inhale': return sniff[st.index]
          ? (p < 0.4 ? a + (MAX_L - a) * ease(p / 0.4) : MAX_L + (MID_L - MAX_L) * ease((p - 0.4) / 0.6))
          : a + (target[st.index] - a) * ease(p);
        case 'exhale': return st.swell
          ? (p < 0.5 ? a + (MAX_L - a) * ease(p / 0.5) : MAX_L + (MIN_L - MAX_L) * ease((p - 0.5) / 0.5))
          : a + (MIN_L - a) * ease(p);
        case 'rest': return a + (MID_L - a) * ease(p);
        case 'action': return a * (1 + 0.14 * (1 - ((p * st.beats) % 1)) ** 2);
        default: return a;
      }
    };

    const D = 'min(78vw, 40vh, 340px)';
    const inCircle = h('div', { style: { fontSize: '44px' } });
    const circle = h('div', { class: 'circle', style: { width: D, height: D, background: phaseVar('rest'), transform: `scale(${MIN_L})` } }, inCircle);
    const phaseEl = h('div', { class: 'phase', 'aria-live': 'polite' });
    const hintEl = h('div', { class: 'hint' });
    const beatEl = h('div', { class: 'muted', style: { textAlign: 'center', fontSize: '16px', marginTop: '6px' } });
    const seriesEl = h('span', { class: 'muted' }), countEl = h('span', { class: 'muted' });
    const bar = h('div', { style: { height: '6px', background: 'var(--primary)', width: '0%', borderRadius: '3px' } });
    const remainEl = h('div', { class: 'muted', style: { textAlign: 'center', marginTop: '4px' } });
    const pauseBtn = h('button', { class: 'fill' }), stopBtn = h('button', {}, icon('stop'), 'Стоп'), skipBtn = h('button', {}, icon('skip_next'), 'Пропустити');
    const runView = h('div', {},
      h('div', { style: { display: 'flex', justifyContent: 'space-between' } }, seriesEl, countEl),
      h('div', { style: { background: 'var(--bg-line)', borderRadius: '3px', marginTop: '8px' } }, bar), remainEl,
      h('div', { class: 'stage', style: { width: D, height: D } }, circle),
      phaseEl, hintEl, beatEl,
      h('div', { class: 'ctl', style: { marginTop: '20px' } }, pauseBtn, stopBtn, skipBtn));
    put(body, runView);

    let count = 3, countTimer = null, beatTimer = null, raf = 0;
    const release = keepAwake();
    const schedule = () => {
      clearTimeout(beatTimer);
      if (engine.status !== 'running') return;
      beatTimer = setTimeout(() => { engine.tick(); schedule(); draw(); }, Math.max(0, engine.untilNextEvent) + 1);
    };
    engine.onPhase = sound.phase;
    engine.onBeat = sound.beat;
    engine.onFinish = (done) => {
      clearTimeout(beatTimer);
      if (done) addSession(e.id, Math.round(engine.elapsed / 1000));
      api.setResult(done);
      showFinished();
    };
    const startCountdown = () => {
      clearInterval(countTimer);
      count = 3; sound.countdown(false); draw();
      countTimer = setInterval(() => {
        count--;
        if (count <= 0) { clearInterval(countTimer); count = null; engine.start(); schedule(); } else sound.countdown(count === 1);
        draw();
      }, 1000);
    };
    const togglePause = () => {
      if (engine.status === 'ready') { if (count == null) startCountdown(); return; }
      engine.toggle(); schedule(); draw();
    };
    const stopAsk = async () => {
      if (engine.status === 'running') { engine.pause(); clearTimeout(beatTimer); }
      if (count != null) { clearInterval(countTimer); count = null; }
      draw();
      if (await confirmDialog('Зупинити вправу?', 'Прогрес цієї спроби не буде враховано.', { okLabel: 'Стоп', cancelLabel: 'Скасувати' })) {
        engine.stop(); api.finish(false);
      }
    };
    pauseBtn.onclick = togglePause; stopBtn.onclick = stopAsk; skipBtn.onclick = () => { engine.skip(); schedule(); draw(); };

    // Згорнули вкладку чи вікно — пауза.
    const onVis = () => {
      if (document.visibilityState === 'visible') return;
      if (count != null) { clearInterval(countTimer); count = null; }
      if (engine.status === 'running') { engine.pause(); clearTimeout(beatTimer); }
      draw();
    };
    document.addEventListener('visibilitychange', onVis);
    api.onCleanup(() => {
      cancelAnimationFrame(raf); clearTimeout(beatTimer); clearInterval(countTimer);
      document.removeEventListener('visibilitychange', onVis); release();
      try { speechSynthesis.cancel(); } catch { /* ок */ }
      if (engine.status !== 'finished') engine.stop();
    });

    function draw() {
      if (engine.status === 'finished') return;
      const st = engine.current;
      const waiting = !st;
      const paused = engine.status === 'paused' || (waiting && count == null);
      const shown = st || steps[0];
      const color = waiting ? phaseVar('rest') : phaseVar(st.type);
      circle.style.background = color;
      circle.style.opacity = paused ? 0.5 : 1;
      circle.style.transform = `scale(${waiting ? MIN_L : scaleOf(st)})`;
      inCircle.textContent = waiting ? (count ?? '') : st.beats > 0 ? String(engine.beat + 1) : String(Math.ceil(engine.remainingInStep / 1000));
      phaseEl.textContent = waiting ? 'Приготуйся' : PHASE_LABEL[st.type];
      phaseEl.style.color = color;
      hintEl.textContent = shown?.hint || '';
      beatEl.textContent = [!waiting && st.beats > 1 ? `Доля ${engine.beat + 1} / ${st.beats}` : '', paused ? 'Пауза — натисни «Продовжити»' : ''].filter(Boolean).join(' · ');
      seriesEl.textContent = shown && shown.seriesTotal > 1 ? `Серія ${shown.series} / ${shown.seriesTotal}` : '';
      countEl.textContent = !waiting ? countLbl[st.index] : '';
      bar.style.width = `${engine.progress * 100}%`;
      remainEl.textContent = `Залишилось ${fmt.clock(Math.ceil((engine.total - engine.elapsed) / 1000))}`;
      clear(pauseBtn).append(icon(paused ? 'play_arrow' : 'pause'), paused ? 'Продовжити' : 'Пауза');
      pauseBtn.disabled = count != null;
      skipBtn.disabled = waiting;
    }
    const loop = () => { engine.tick(); draw(); raf = requestAnimationFrame(loop); };
    raf = requestAnimationFrame(loop);
    startCountdown();

    function showFinished() {
      cancelAnimationFrame(raf);
      const sec = Math.round(engine.elapsed / 1000);
      put(clear(body), h('div', { style: { textAlign: 'center', padding: '24px 0' } },
        h('div', { style: { fontSize: '96px', color: 'var(--primary)' } }, icon('check_circle')),
        h('h2', {}, engine.completed ? 'Вправу завершено' : 'Вправу зупинено'),
        h('div', { class: 'muted', style: { fontSize: '16px' } }, fmt.duration(sec)),
        h('div', { style: { display: 'flex', gap: '12px', justifyContent: 'center', marginTop: '24px' } },
          allowRepeat ? h('button', { class: 'btn text', onClick: () => { api.pop(); setTimeout(() => runGuided(e, s, { allowRepeat }), 0); } }, icon('replay'), 'Ще раз') : null,
          h('button', { class: 'btn', onClick: () => api.finish(engine.completed) }, icon('done'), 'Готово'))));
    }
  });
}

// ── Секундомір ──────────────────────────────────────────────────────────
function runStopwatch(e) {
  return screen(e.title, (body, api) => {
    const session = new StopwatchSession();
    let list = attempts().filter((a) => a.exerciseId === e.id).sort((a, b) => b.at - a.at);
    let record = bestOf(list), prevRecord = 0, thisRun = 0, raf = 0;
    const release = keepAwake();
    session.onCountdown = (n) => sound.countdown(n === 1);
    session.onPhase = (p) => {
      if (p === 'inhale') sound.cue('inhale');
      else if (p === 'exhale') sound.cue('exhale');
      else if (p === 'done') {
        thisRun++; prevRecord = record;
        const a = { exerciseId: e.id, seconds: session.result, at: Date.now() };
        addAttempt(a); list = [a, ...list]; record = Math.max(record, a.seconds);
        api.setResult(true);
      }
      render();
    };
    const onVis = () => { if (document.visibilityState !== 'visible' && session.phase !== 'done') session.cancel(); };
    document.addEventListener('visibilitychange', onVis);
    api.onCleanup(() => {
      cancelAnimationFrame(raf); release(); document.removeEventListener('visibilitychange', onVis);
      if (thisRun > 0) addSession(e.id, 60);
    });

    const recordLine = () => h('div', { class: 'row', style: { fontWeight: 600 } }, icon('emoji_events'),
      record > 0 ? `Рекорд: ${fmt.sec(record)}` : 'Рекорду ще немає');
    const bigEl = h('div', { style: { fontSize: '60px', fontVariantNumeric: 'tabular-nums' } });
    const circle = h('div', { class: 'circle', style: { width: '260px', height: '260px' } }, bigEl);
    const label = h('div', { class: 'phase' }), sub = h('div', { class: 'hint', style: { fontSize: '17px' } });
    const stopBtn = h('button', { class: 'btn block', style: { minHeight: '96px', fontSize: '24px', marginTop: '16px' }, onClick: () => session.stop() });

    function render() {
      cancelAnimationFrame(raf);
      const p = session.phase;
      if (p === 'ready' || p === 'done') {
        const result = p === 'done' ? session.result : null;
        const isRecord = result != null && result >= record && result > prevRecord;
        put(clear(body), recordLine(),
          e.benchmark ? h('div', { class: 'muted' }, e.benchmark) : null,
          result == null ? h('div', { style: { fontSize: '17px', lineHeight: 1.5, margin: '16px 0' } }, e.description)
            : h('div', { style: { textAlign: 'center', margin: '16px 0' }, 'aria-live': 'polite' },
              h('div', { class: 'muted', style: { fontSize: '16px' } }, 'Результат'),
              h('div', { style: { fontSize: '72px', fontWeight: 700 } }, fmt.sec(result)),
              isRecord ? h('span', { class: 'chip' }, icon('emoji_events'), prevRecord > 0 ? 'Новий рекорд!' : 'Перший результат') : null),
          h('button', { class: 'btn block', style: { padding: '16px', fontSize: '17px' }, onClick: () => session.start() },
            icon(result == null ? 'play_arrow' : 'replay'), result == null ? 'Почати спробу' : 'Ще спроба'),
          result != null ? h('button', { class: 'btn text block', style: { marginTop: '8px' }, onClick: () => api.finish(true) }, icon('done'), 'Готово') : null,
          list.length ? h('div', {}, h('div', { class: 'sec-title' }, 'Останні спроби'),
            ...list.slice(0, 10).map((a) => h('div', { class: 'row' }, icon(a.seconds >= record ? 'emoji_events' : 'timer'),
              h('b', { style: { flex: 1 } }, fmt.sec(a.seconds)), h('span', { class: 'muted' }, fmt.dateTime(a.at))))) : null);
        return;
      }
      put(clear(body), recordLine(), h('div', { class: 'stage', style: { width: '260px', height: '260px' } }, circle), label, sub, stopBtn);
      const loop = () => {
        session.tick();
        const ph = session.phase;
        if (ph === 'ready' || ph === 'done') return;
        const exhaling = ph === 'exhale';
        const color = ph === 'countdown' ? phaseVar('rest') : ph === 'inhale' ? phaseVar('inhale') : phaseVar('exhale');
        circle.style.background = color;
        circle.style.transform = `scale(${ph === 'inhale' ? 0.45 + 0.55 * ease(session.inhaleProgress) : exhaling ? 1 : 0.45})`;
        bigEl.textContent = exhaling ? fmt.secNumber(session.exhaleSeconds) : String(session.secondsLeft);
        label.textContent = ph === 'countdown' ? 'Приготуйся' : ph === 'inhale' ? 'ВДИХ' : 'ВИДИХ';
        label.style.color = color;
        sub.textContent = ph === 'countdown' ? 'Зараз буде вдих ротом' : ph === 'inhale' ? 'Глибокий безшумний вдих ротом' : 'Видихай рівно. Натисни «Стоп», коли закінчиться повітря';
        clear(stopBtn).append(icon(exhaling ? 'stop' : 'close'), exhaling ? 'Стоп' : 'Скасувати');
        stopBtn.classList.toggle('danger', exhaling);
        raf = requestAnimationFrame(loop);
      };
      loop();
    }
    render();
  });
}

// ── Таймер ──────────────────────────────────────────────────────────────
function runTimer(e) {
  return screen(e.title, (body, api) => {
    const timer = new FreeTimer(e.totalSeconds);
    const release = keepAwake();
    let raf = 0, logged = false;
    timer.onTimeUp = sound.timeUp;
    const onVis = () => { if (document.visibilityState !== 'visible') { timer.pause(); draw(); } };
    document.addEventListener('visibilitychange', onVis);
    api.onCleanup(() => { cancelAnimationFrame(raf); release(); document.removeEventListener('visibilitychange', onVis); });

    const R = 108, C = 2 * Math.PI * R;
    const timeEl = h('div', { style: { position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', fontSize: '56px', fontWeight: 700, fontVariantNumeric: 'tabular-nums' } });
    const fg = svgEl('circle', { cx: 120, cy: 120, r: R, fill: 'none', stroke: 'var(--ph-exhale)', 'stroke-width': 12, 'stroke-linecap': 'round', transform: 'rotate(-90 120 120)', 'stroke-dasharray': C });
    const svg = svgEl('svg', { viewBox: '0 0 240 240', width: 240, height: 240 });
    svg.append(svgEl('circle', { cx: 120, cy: 120, r: R, fill: 'none', stroke: 'var(--bg-line)', 'stroke-width': 12 }), fg);
    const doneLbl = h('h2', { style: { textAlign: 'center' } });
    const mainBtn = h('button', { class: 'btn block', style: { padding: '16px', fontSize: '17px', marginTop: '24px' }, onClick: () => { timer.toggle(); draw(); } });
    const doneBtn = h('button', { class: 'btn text block', style: { marginTop: '8px', fontSize: '17px' },
      onClick: () => { if (timer.status === 'done') api.finish(true); else { timer.finish(); draw(); } } });

    put(body, 
      h('div', { style: { fontSize: '17px', lineHeight: 1.5 } }, e.description),
      e.needsItem ? h('div', { class: 'box info' }, icon('backpack'), h('div', {}, h('b', {}, 'Потрібно: '), e.needsItem)) : null,
      e.warning ? h('div', { class: 'box warn' }, icon('warning'), h('div', {}, e.warning)) : null,
      h('div', { style: { position: 'relative', width: '240px', height: '240px', margin: '28px auto 0' }, role: 'timer', 'aria-label': 'Залишилось часу' }, svg, timeEl),
      doneLbl, mainBtn, doneBtn);

    function draw() {
      const done = timer.status === 'done';
      if (done && !logged) { logged = true; addSession(e.id, Math.round(timer.elapsed / 1000)); api.setResult(true); }
      fg.setAttribute('stroke-dashoffset', String(C * timer.progress));
      timeEl.replaceChildren(done ? icon('check_circle') : fmt.clock(timer.remainingSeconds));
      timeEl.style.color = done ? 'var(--ph-exhale)' : '';
      doneLbl.textContent = done ? (timer.timeUp ? 'Час вийшов' : 'Вправу виконано') : '';
      mainBtn.style.display = done ? 'none' : '';
      clear(mainBtn).append(icon(timer.status === 'running' ? 'pause' : 'play_arrow'),
        timer.status === 'running' ? 'Пауза' : timer.status === 'paused' ? 'Продовжити' : 'Почати');
      clear(doneBtn).append(icon('done'), 'Готово');
      doneBtn.disabled = timer.status === 'ready';
    }
    const loop = () => { timer.tick(); draw(); raf = requestAnimationFrame(loop); };
    raf = requestAnimationFrame(loop);
  });
}

// ── Програма ────────────────────────────────────────────────────────────
function openProgram(p) {
  ensureStyles();
  screen(p.title, (body, api) => {
    const run = new ProgramRun(p);
    let started = false, left = null, timer = null, opening = false;
    const STATUS = { done: ['check_circle', 'виконано'], stopped: ['stop_circle', 'зупинено'], skipped: ['skip_next', 'пропущено'] };
    const row = (e, i) => {
      const [ic, lbl] = STATUS[run.statuses[i]] || [e.mode === MODE.guided ? 'air' : e.mode === MODE.stopwatch ? 'timer' : 'hourglass_bottom', ''];
      return h('div', { class: 'row', style: { fontWeight: started && i === run.index ? 700 : 400 } }, icon(ic),
        h('div', { style: { flex: 1 } }, h('div', {}, `${i + 1}. ${e.title}`),
          h('div', { class: 'muted' }, [fmt.approx(estimateSeconds(e, exSettings(e))), e.needsItem ? `Потрібно: ${e.needsItem}` : '', lbl].filter(Boolean).join(' · '))));
    };
    const onVis = () => { if (document.visibilityState !== 'visible' && timer) { clearInterval(timer); timer = null; left = null; render(); } };
    document.addEventListener('visibilitychange', onVis);
    api.onCleanup(() => { clearInterval(timer); document.removeEventListener('visibilitychange', onVis); });

    async function transition() {
      clearInterval(timer); timer = null;
      if (run.finished) { left = null; render(); return; }
      if (run.needsStrelnikovaWarning) {
        left = null; render();
        await new Promise((res) => {
          const d = openDialog(h('div', {},
            h('h3', { style: { margin: '0 0 12px' } }, icon('warning'), ` ${BLOCKS[2]}`),
            h('div', { style: { lineHeight: 1.5 } }, STRELNIKOVA_WARNING),
            h('div', { style: { textAlign: 'right', marginTop: '16px' } }, h('button', { class: 'btn', onClick: () => { d.close(); res(); } }, 'Зрозуміло'))),
          { dismissible: false });
        });
        run.warned = true;
      }
      left = 5; render();
      timer = setInterval(() => { left--; if (left <= 0) openCurrent(); else render(); }, 1000);
    }
    async function openCurrent() {
      clearInterval(timer); timer = null; left = null;
      const e = run.current;
      if (!e || opening) return;
      opening = true; render();
      const done = await runExercise(e, exSettings(e));
      opening = false;
      run.complete(done === true);
      transition();
    }
    async function endAsk() {
      clearInterval(timer); timer = null; left = null; render();
      if (await confirmDialog('Завершити програму?', 'Решту вправ буде пропущено.', { okLabel: 'Завершити програму', cancelLabel: 'Скасувати' })) { run.abort(); render(); }
      else transition();
    }
    function render() {
      if (!started) {
        put(clear(body), 
          h('div', { style: { fontSize: '17px', lineHeight: 1.5 } }, p.description),
          h('div', { class: 'muted', style: { margin: '8px 0 12px' } }, `${fmt.exercises(run.exercises.length)} · ${p.durationLabel} · ${fmt.approx(estimateProgramSeconds(p))}`),
          ...run.exercises.map(row),
          h('button', { class: 'btn block', style: { padding: '16px', fontSize: '17px', marginTop: '16px' }, onClick: () => { started = true; transition(); } }, icon('play_arrow'), 'Почати програму'));
        return;
      }
      if (run.finished) {
        put(clear(body), h('div', { style: { textAlign: 'center' } },
          h('div', { style: { fontSize: '72px', color: 'var(--primary)' } }, icon('emoji_events')),
          h('h2', {}, 'Програму завершено'),
          h('div', { style: { fontWeight: 600 } }, [`Виконано: ${run.count('done')}`, run.count('stopped') ? `зупинено: ${run.count('stopped')}` : '', `пропущено: ${run.count('skipped')}`].filter(Boolean).join(' · '))),
        h('div', { style: { marginTop: '16px' } }, ...run.exercises.map(row)),
        h('button', { class: 'btn block', style: { padding: '16px', fontSize: '17px', marginTop: '16px' }, onClick: () => api.finish(true) }, icon('done'), 'Готово'));
        return;
      }
      const e = run.current, n = run.exercises.length;
      put(clear(body), 
        h('div', { style: { height: '4px', background: 'var(--bg-line)', borderRadius: '2px' } }, h('div', { style: { height: '4px', width: `${run.index / n * 100}%`, background: 'var(--primary)', borderRadius: '2px' } })),
        h('div', { style: { fontWeight: 600, marginTop: '12px' } }, `Вправа ${run.index + 1} з ${n}`),
        h('div', { class: 'muted' }, 'Наступна вправа'),
        h('h2', { style: { margin: '4px 0 8px' } }, e.title),
        h('div', { class: 'chips-inline' }, h('span', { class: 'chip' }, MODE_LABEL[e.mode]), h('span', { class: 'chip' }, fmt.approx(estimateSeconds(e, exSettings(e)))),
          e.needsItem ? h('span', { class: 'chip' }, e.needsItem) : null),
        h('div', { style: { fontSize: '17px', lineHeight: 1.5 } }, e.description),
        ...e.tips.map((t) => h('div', { class: 'muted' }, `• ${t}`)),
        e.warning && e.block !== 2 ? h('div', { class: 'box warn' }, icon('warning'), h('div', {}, e.warning)) : null,
        left != null ? h('div', { style: { textAlign: 'center', fontSize: '22px', margin: '20px 0 0' }, 'aria-live': 'polite' }, `Автостарт через ${left} с`) : null,
        h('button', { class: 'btn block', style: { padding: '16px', fontSize: '17px', marginTop: '20px' }, onClick: openCurrent }, icon('play_arrow'), 'Далі'),
        h('div', { style: { display: 'flex', gap: '8px', marginTop: '8px' } },
          h('button', { class: 'btn text', style: { flex: 1 }, onClick: () => { run.skip(); transition(); } }, icon('skip_next'), 'Пропустити вправу'),
          h('button', { class: 'btn text', style: { flex: 1 }, onClick: endAsk }, icon('close'), 'Завершити програму')));
    }
    render();
  });
}

// ── Прогрес ─────────────────────────────────────────────────────────────
const SVG = 'http://www.w3.org/2000/svg';
const svgEl = (tag, attrs = {}, text) => {
  const el = document.createElementNS(SVG, tag);
  Object.entries(attrs).forEach(([k, v]) => el.setAttribute(k, v));
  if (text != null) el.textContent = text;
  return el;
};
const WEEKDAYS = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

/** Стовпчики «вправ за день» пн–нд; значення підписані над ненульовими. */
function weekChart(counts, today) {
  const W = 320, H = 140, base = H - 22, top = 18, slot = W / 7, bw = Math.min(28, slot * 0.55), max = Math.max(1, ...counts);
  const svg = svgEl('svg', { viewBox: `0 0 ${W} ${H}`, width: '100%', role: 'img',
    'aria-label': `Цього тижня: ${counts.map((c, i) => `${WEEKDAYS[i]} ${c}`).join(', ')}` });
  svg.append(svgEl('line', { x1: 0, x2: W, y1: base, y2: base, stroke: 'var(--bg-line)' }));
  counts.forEach((v, i) => {
    const cx = slot * i + slot / 2;
    if (v > 0) {
      const hh = Math.max(4, (base - top) * v / max);
      svg.append(svgEl('path', { d: `M${cx - bw / 2},${base} v${-hh + 4} q0,-4 4,-4 h${bw - 8} q4,0 4,4 v${hh - 4} z`, fill: 'var(--ph-exhale)' }));
      svg.append(svgEl('text', { x: cx, y: base - hh - 4, 'text-anchor': 'middle', 'font-size': 12, 'font-weight': 600, fill: 'currentColor' }, String(v)));
    }
    svg.append(svgEl('text', { x: cx, y: H - 4, 'text-anchor': 'middle', 'font-size': 12, 'font-weight': i === today ? 700 : 400,
      fill: i === today ? 'currentColor' : 'var(--bg-muted)' }, WEEKDAYS[i]));
  });
  return svg;
}

/** Лінія спроб; рекорд підписаний; дотик/наведення показує спробу. */
function recordChart(points, onSelect) {
  const W = 320, H = 140, L = 30, R = 10, T = 18, B = 6;
  const vals = points.map((a) => a.seconds), max = Math.max(...vals);
  const step = max <= 10 ? 2 : max <= 25 ? 5 : max <= 60 ? 10 : 20, top = Math.max(step, Math.ceil(max / step) * step);
  const x = (i) => (points.length === 1 ? L + (W - L - R) / 2 : L + (W - L - R) * i / (points.length - 1));
  const y = (v) => T + (H - T - B) * (1 - v / top);
  const svg = svgEl('svg', { viewBox: `0 0 ${W} ${H}`, width: '100%', role: 'img', 'aria-label': vals.map(fmt.sec).join(', ') });
  for (let v = 0; v <= top + 1e-9; v += step) {
    svg.append(svgEl('line', { x1: L, x2: W - R, y1: y(v), y2: y(v), stroke: 'var(--bg-line)' }));
    svg.append(svgEl('text', { x: L - 6, y: y(v) + 4, 'text-anchor': 'end', 'font-size': 11, fill: 'var(--bg-muted)' }, String(v)));
  }
  if (points.length > 1) svg.append(svgEl('polyline', { points: points.map((a, i) => `${x(i)},${y(a.seconds)}`).join(' '), fill: 'none', stroke: 'var(--ph-exhale)', 'stroke-width': 2, 'stroke-linejoin': 'round' }));
  const ri = vals.indexOf(max);
  const cursor = svgEl('line', { y1: T, y2: H - B, stroke: 'var(--bg-muted)', visibility: 'hidden' });
  svg.append(cursor);
  const dots = points.map((a, i) => {
    const big = i === ri;
    svg.append(svgEl('circle', { cx: x(i), cy: y(a.seconds), r: (big ? 6 : 4) + 2, fill: 'var(--bg-card)' }));
    const d = svgEl('circle', { cx: x(i), cy: y(a.seconds), r: big ? 6 : 4, fill: 'var(--ph-exhale)' });
    svg.append(d);
    return d;
  });
  const lx = Math.min(W - 24, Math.max(24, x(ri)));
  svg.append(svgEl('text', { x: lx, y: Math.max(12, y(max) - 10), 'text-anchor': 'middle', 'font-size': 12, 'font-weight': 600, fill: 'currentColor' }, fmt.sec(max)));
  const pick = (ev) => {
    const r = svg.getBoundingClientRect();
    const px = (ev.clientX - r.left) * W / r.width;
    let best = 0;
    points.forEach((_, i) => { if (Math.abs(x(i) - px) < Math.abs(x(best) - px)) best = i; });
    cursor.setAttribute('x1', x(best)); cursor.setAttribute('x2', x(best)); cursor.setAttribute('visibility', 'visible');
    dots.forEach((d, i) => d.setAttribute('r', i === best || i === ri ? 6 : 4));
    onSelect(points[best]);
  };
  svg.addEventListener('pointerdown', pick);
  svg.addEventListener('pointermove', (ev) => { if (ev.pointerType === 'mouse') pick(ev); });
  svg.style.touchAction = 'pan-y';
  return svg;
}

function openProgress() {
  ensureStyles();
  screen('Прогрес', (body) => {
    const ss = sessions(), all = attempts(), now = Date.now();
    const week = weekCounts(ss, now), weekDays = week.filter((c) => c > 0).length;
    const tile = (label, value, caption) => h('div', { class: 'tile', style: { flexDirection: 'column', alignItems: 'flex-start', margin: 0 } },
      h('div', { class: 's', style: { marginTop: 0 } }, label), h('div', { style: { fontSize: '22px', fontWeight: 700 } }, value), h('div', { class: 's' }, caption));
    const history = ss.filter((s) => s.completed).sort((a, b) => b.at - a.at);
    put(body, 
      h('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' } },
        tile('Цього тижня', fmt.exercises(week.reduce((a, b) => a + b, 0)), fmt.days(weekDays)),
        tile('Серія', fmt.days(currentStreak(ss, now)), `Найдовша серія: ${fmt.days(longestStreak(ss))}`)),
      h('div', { style: { marginTop: '16px' } }, weekChart(week, (new Date().getDay() + 6) % 7)),
      h('div', { class: 'sec-title' }, 'Рекорди видиху'),
      ...['hiss_exhale', 'candle', 'paper_wall'].map((id) => {
        const pts = chartPoints(all, id), rec = bestOf(pts);
        const caption = h('div', { class: 's' }, pts.length ? `${fmt.attempts(pts.length)} · Торкнися точки, щоб побачити спробу` : 'Ще немає спроб — зроби першу на картці вправи');
        return h('div', { class: 'tile', style: { flexDirection: 'column', alignItems: 'stretch' } },
          h('div', { style: { display: 'flex', justifyContent: 'space-between', fontWeight: 700 } }, BY_ID[id].title, rec ? h('span', {}, icon('emoji_events'), ` ${fmt.sec(rec)}`) : null),
          caption,
          pts.length ? recordChart(pts, (a) => { caption.textContent = `${fmt.sec(a.seconds)} · ${fmt.dateTime(a.at)}`; }) : null);
      }),
      h('div', { class: 'sec-title' }, 'Історія'),
      history.length ? null : h('div', { class: 'muted' }, 'Тут з\'являться виконані вправи'),
      ...history.slice(0, 30).map((s) => h('div', { class: 'row' }, icon('check_circle'),
        h('div', { style: { flex: 1 } }, h('div', {}, BY_ID[s.exerciseId]?.title || s.exerciseId), h('div', { class: 'muted' }, fmt.duration(s.seconds || 0))),
        h('span', { class: 'muted' }, fmt.dateTime(s.at)))));
  });
}

// ── Налаштування ────────────────────────────────────────────────────────
function openSettings() {
  ensureStyles();
  screen('Налаштування тренажера', (body) => {
    const update = (patch) => { save(K.settings, { ...settings(), ...patch }); render(); };
    const sw = (label, sub, value, on, disabled = false) => h('label', { class: 'row', style: { justifyContent: 'space-between', cursor: disabled ? 'default' : 'pointer', opacity: disabled ? 0.5 : 1 } },
      h('div', {}, h('div', { style: { fontSize: '16px' } }, label), sub ? h('div', { class: 'muted' }, sub) : null),
      h('input', { type: 'checkbox', role: 'switch', checked: value, disabled, style: { width: '22px', height: '22px' }, onChange: (ev) => on(ev.target.checked) }));
    function render() {
      const s = settings(), voiceOk = !!ukVoice();
      put(clear(body), 
        h('div', { class: 'sec-title' }, 'Звук і вібрація'),
        sw('Метроном і тони фаз', 'Клік на кожну долю, окремі тони вдиху й видиху', s.metronome, (v) => update({ metronome: v })),
        h('div', { class: 'row', style: { opacity: s.metronome ? 1 : 0.5 } }, h('span', { class: 'lbl' }, 'Гучність'),
          h('input', { type: 'range', min: 0, max: 1, step: 0.1, value: s.volume, disabled: !s.metronome, style: { flex: 1 }, 'aria-label': 'Гучність',
            onChange: (ev) => { update({ volume: Number(ev.target.value) }); tone(NOTE.beat, 0.15, 0.7); } })),
        sw('Вібрація на початку фази', 'Працює на телефонах з Android у Chrome', s.vibration, (v) => update({ vibration: v })),
        sw('Голосові підказки', voiceOk ? 'Вимовляти «Вдих», «Видих»… українською'
          : 'У цьому браузері немає українського голосу. Його можна додати в налаштуваннях синтезу мовлення системи.',
          s.voice && voiceOk, (v) => update({ voice: v }), !voiceOk),
        voiceOk ? h('button', { class: 'btn text', onClick: () => say('Вдих. Видих.') }, icon('record_voice_over'), 'Перевірити голос') : null,
        h('div', { class: 'sec-title' }, 'Дані'),
        h('div', { class: 'muted' }, 'Результати й налаштування зберігаються лише в цьому браузері.'),
        h('button', { class: 'btn text', onClick: () => {
          try { Object.keys(localStorage).filter((k) => k.startsWith(K.ex)).forEach((k) => localStorage.removeItem(k)); } catch { /* ок */ }
          toast('Налаштування вправ повернуто до стандартних');
        } }, icon('tune'), 'Скинути налаштування вправ'),
        h('button', { class: 'btn text', style: { color: '#C62828' }, onClick: async () => {
          if (!await confirmDialog('Очистити історію та рекорди', 'Усі спроби, рекорди й журнал тренувань у цьому браузері буде видалено.', { okLabel: 'Очистити', cancelLabel: 'Скасувати', danger: true })) return;
          save(K.attempts, []); save(K.sessions, []); toast('Історію очищено');
        } }, icon('delete'), 'Очистити історію та рекорди'));
    }
    render();
    // Голоси в Chrome підвантажуються асинхронно.
    try { speechSynthesis.addEventListener?.('voiceschanged', render, { once: true }); } catch { /* немає синтезу */ }
  });
}
