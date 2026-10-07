// Дихальний тренажер для духовиків — логіка без DOM (той самий каталог і
// правила, що в застосунку: lib/data/breath_gym_catalog.dart,
// lib/services/breath_gym_*.dart). Час — мілісекунди монотонного годинника
// (performance.now), у тестах підміняється.

// ── Каталог ──────────────────────────────────────────────────────────────
export const SRC = {
  gym: 'The Breathing Gym (Pilafian & Sheridan)',
  strelnikova: 'Гімнастика О. Стрельникової',
  jacobs: 'A. Jacobs',
  classic: 'Класична методика',
};

export const BLOCKS = {
  1: 'Підготовка',
  2: 'Гімнастика Стрельникової',
  3: 'Ігрове дихання',
  4: 'Вправи з предметами (A. Jacobs)',
  5: 'На інструменті',
};
export const ROMANS = ['I', 'II', 'III', 'IV', 'V'];

export const STRELNIKOVA_WARNING = 'Короткий вдих носом тут тренувальний. Ігровий вдих — ротом, '
  + 'глибокий і безшумний. Якщо паморочиться в голові — зупинись.';
export const DIZZINESS_WARNING = 'Якщо паморочиться в голові — зупинись і подихай спокійно.';
export const PLAY_TIPS = ['Плечі не піднімаються', 'Горло відкрите, вдих наче на «о»'];
export const INTRO = 'Вправи взято з методик A. Jacobs, The Breathing Gym і О. Стрельникової, '
  + 'які використовують у музичних школах і вишах. Навантаження збільшуй поступово.';

export const MODE = { guided: 'guided', stopwatch: 'stopwatch', freeTimer: 'freeTimer' };

const ph = (type, beats, hint = '', swell = false) => ({ type, beats, seconds: 0, hint, swell });
const inh = (b, h) => ph('inhale', b, h);
const exh = (b, h, swell) => ph('exhale', b, h, swell);

/** Значення за замовчуванням для полів вправи. */
function ex(e) {
  return {
    groups: [], series: 1, seriesMin: 1, seriesMax: 1, restBetweenSeriesSec: 0, repeatsAdjustable: false,
    defaultBpm: 60, bpmMin: 60, bpmMax: 60, totalSeconds: 0, warning: '', needsItem: '', hasSyllable: false,
    tips: [], benchmark: '', ...e,
  };
}

/** Стрельникова: серія — 8 коротких вдихів по долі, між серіями 4 с. */
function strelnikova(id, title, description, hints) {
  return ex({
    id, block: 2, title, source: SRC.strelnikova, description, mode: MODE.guided,
    groups: [{ phases: hints.map((h) => inh(1, h)), repeats: 8 / hints.length }],
    series: 3, seriesMin: 1, seriesMax: 12, restBetweenSeriesSec: 4,
    defaultBpm: 90, bpmMin: 60, bpmMax: 120, warning: STRELNIKOVA_WARNING,
  });
}

const flowPair = (i, e) => ({ phases: [inh(i, 'вдих ротом'), exh(e, i === 1 ? 'так дихаємо під час гри' : 'видих')], repeats: 2 });

export const EXERCISES = [
  ex({
    id: 'stretch_breath', block: 1, title: 'Розтяжка з диханням', source: SRC.gym, mode: MODE.guided,
    description: 'Стань рівно, ноги на ширині плечей. На вдиху плавно піднімай руки через сторони вгору, '
      + 'на видиху опускай. Рух і дихання тривають однаково довго — на всі 4 долі.',
    groups: [{ phases: [inh(4, 'руки через сторони вгору'), exh(4, 'руки вниз')], repeats: 6 }],
    repeatsAdjustable: true, bpmMin: 40, bpmMax: 90,
  }),
  ex({
    id: 'rag_doll', block: 1, title: 'Ганчір\'яна лялька', source: SRC.gym, mode: MODE.guided,
    description: 'На видиху вільно, без зусилля опусти корпус донизу, руки висять. Зачекай, розслаб плечі й шию, '
      + 'потім на повільному вдиху випрямляйся хребець за хребцем.',
    groups: [{ phases: [exh(4, 'вільно опусти корпус донизу'), ph('hold', 2, 'розслаб плечі й шию'), inh(6, 'повільно випрямляйся')], repeats: 3 }],
    repeatsAdjustable: true, bpmMin: 40, bpmMax: 90,
    warning: 'Випрямляйся повільно, особливо якщо паморочиться в голові.',
  }),
  ex({
    id: 'book_on_belly', block: 1, title: 'Дихання лежачи з книгою', source: SRC.classic, mode: MODE.guided,
    description: 'Ляж на спину, поклади книгу на живіт. Дихай так, щоб на вдиху книга піднімалася, а на видиху '
      + 'опускалася; груди й плечі майже нерухомі. Так відчувається робота діафрагми.',
    groups: [{ phases: [inh(4, 'книга піднімається'), exh(6, 'книга опускається')], repeats: 8 }],
    repeatsAdjustable: true, bpmMin: 40, bpmMax: 90, needsItem: 'книга',
  }),
  strelnikova('str_palms', 'Долоньки',
    'Стань рівно, зігнуті в ліктях руки долонями від себе. На кожен короткий шумний вдих носом стискай кулаки, '
    + 'видих пасивний — кулаки розтискаються самі.', ['стисни кулаки']),
  strelnikova('str_epaulettes', 'Погончики',
    'Кулаки притиснуті до пояса. На кожен короткий вдих носом різко штовхай руки вниз, розтискаючи кулаки; '
    + 'на пасивному видиху повертай їх до пояса.', ['руки різко вниз, розтисни кулаки']),
  strelnikova('str_pump', 'Насос',
    'Легкий нахил уперед, руки опущені, спина кругла. Короткий вдих носом — у нижній точці нахилу, '
    + 'на пасивному видиху трохи випрямляйся, не до кінця.', ['нахил уперед, вдих у нижній точці']),
  strelnikova('str_cat', 'Кішка',
    'Ноги на ширині плечей. Легкий присід з поворотом корпусу то вправо, то вліво, руки роблять хапальний рух. '
    + 'На кожен присід — короткий вдих носом.', ['присід з поворотом вправо', 'присід з поворотом вліво']),
  strelnikova('str_hug', 'Обійми плечі',
    'Руки зігнуті в ліктях на рівні плечей. На кожен короткий вдих носом зустрічним рухом обіймай себе за плечі, '
    + 'руки йдуть паралельно, не навхрест.', ['обійми плечі зустрічним рухом']),
  strelnikova('str_pendulum', 'Великий маятник',
    'Поєднання «Насоса» й «Обійми плечі»: нахил уперед — вдих, прогин назад з обійманням плечей — вдих. '
    + 'Видих пасивний між рухами.', ['нахил уперед', 'прогин назад, обійми плечі']),
  ex({
    id: 'flow_studies', block: 3, title: 'Flow Studies', source: SRC.gym, mode: MODE.guided,
    description: 'Безперервне дихання без пауз: вдих ротом плавно переходить у видих. Вдих поступово коротшає '
      + '(4 → 1 доля), видих довшає (4 → 8). Пари 1/7 і 1/8 — так дихаємо під час гри.',
    groups: [flowPair(4, 4), flowPair(3, 5), flowPair(2, 6), flowPair(1, 7), flowPair(1, 8)],
    repeatsAdjustable: true, bpmMin: 40, bpmMax: 90, tips: PLAY_TIPS,
  }),
  ex({
    id: 'hiss_exhale', block: 3, title: 'Видих на «с-с-с»', source: SRC.classic, mode: MODE.stopwatch,
    description: 'Після відліку зроби глибокий вдих ротом за 3 секунди, потім видихай рівно й тонко на «с-с-с». '
      + 'Натисни «Стоп», коли повітря закінчиться. Струмінь має бути рівним від початку до кінця.',
    tips: PLAY_TIPS, benchmark: 'Орієнтири: початківець — 20–25 с, просунутий — 40–60+ с.',
  }),
  ex({
    id: 'panting', block: 3, title: 'Собачка', source: SRC.gym, mode: MODE.guided,
    description: 'Швидке поверхневе дихання ротом, як у собаки після бігу: вдих і видих по одній долі. '
      + 'Рухається тільки живіт, плечі й груди спокійні. Активізує діафрагму.',
    groups: [{ phases: [inh(1, 'вдих'), exh(1, 'видих')], repeats: 1 }],
    totalSeconds: 15, series: 2, seriesMin: 1, seriesMax: 4, restBetweenSeriesSec: 10,
    defaultBpm: 140, bpmMin: 120, bpmMax: 160, warning: DIZZINESS_WARNING,
  }),
  ex({
    id: 'air_notes', block: 3, title: 'Повітряні ноти', source: SRC.classic, mode: MODE.guided,
    description: 'Швидкий вдих ротом на одну долю, потім сім коротких поштовхів повітря без інструмента — '
      + 'по одному на долю. «Ту» тренує атаку язиком, «ху» — чистий поштовх діафрагмою без атаки.',
    groups: [{ phases: [inh(1, 'вдих ротом'), ph('action', 7, 'ту')], repeats: 4 }],
    repeatsAdjustable: true, defaultBpm: 80, bpmMin: 60, bpmMax: 100, hasSyllable: true, tips: PLAY_TIPS,
  }),
  ex({
    id: 'candle', block: 4, title: 'Свічка', source: SRC.jacobs, mode: MODE.stopwatch,
    description: 'Тримай запалену свічку на відстані 20–30 см. Після вдиху дми тонким рівним струменем на полум\'я: '
      + 'воно відхиляється, але не гасне. Натисни «Стоп», коли струмінь урветься.',
    needsItem: 'свічка', warning: 'Обережно з вогнем: не нахиляйся до полум\'я.',
  }),
  ex({
    id: 'paper_wall', block: 4, title: 'Аркуш на стіні', source: SRC.jacobs, mode: MODE.stopwatch,
    description: 'Приклади аркуш паперу до стіни й відпусти, утримуючи його тільки видихом. Чим рівніший струмінь, '
      + 'тим довше аркуш тримається. Натисни «Стоп», коли він упаде.',
    needsItem: 'аркуш паперу',
  }),
  ex({
    id: 'breathing_bag', block: 4, title: 'Дихальний мішок', source: SRC.jacobs, mode: MODE.freeTimer,
    description: 'Робиш повний вдих із мішка й повний видих у мішок, горло без напруги. Обсяг мішка показує, '
      + 'скільки повітря ти рухаєш. Дихай спокійно, не форсуй.',
    totalSeconds: 120, needsItem: 'мішок 5–6 л або трубка', warning: DIZZINESS_WARNING,
  }),
  ex({
    id: 'long_tones', block: 5, title: 'Довгі ноти', source: SRC.classic, mode: MODE.guided,
    description: 'Візьми ріжок чи валторну. Вдих на одну долю, нота на вісім долей рівним звуком, дві долі відпочинку. '
      + 'Потім ще чотири ноти з crescendo – diminuendo: голосніше до середини видиху, тихіше до кінця.',
    groups: [
      { phases: [inh(1, 'вдих ротом'), exh(8, 'рівна нота'), ph('rest', 2, 'відпочинок')], repeats: 4 },
      { phases: [inh(1, 'вдих ротом'), exh(8, 'crescendo – diminuendo', true), ph('rest', 2, 'відпочинок')], repeats: 4 },
    ],
    repeatsAdjustable: true, bpmMin: 40, bpmMax: 80, tips: PLAY_TIPS,
  }),
];

export const BY_ID = Object.fromEntries(EXERCISES.map((e) => [e.id, e]));

export const PROGRAMS = [
  { id: 'daily', title: 'Щоденна розминка', durationLabel: '8–10 хв',
    description: 'Розтяжка, три вправи Стрельникової, ігрове дихання й довгі ноти.',
    exerciseIds: ['stretch_breath', 'str_palms', 'str_epaulettes', 'str_pump', 'flow_studies', 'hiss_exhale', 'long_tones'] },
  { id: 'full', title: 'Повний комплекс', durationLabel: '25–30 хв', description: 'Усі 17 вправ від підготовки до інструмента.',
    exerciseIds: EXERCISES.map((e) => e.id) },
  { id: 'pre_performance', title: 'Перед виступом', durationLabel: '≈7 хв',
    description: 'Розслаблення, активізація діафрагми й довгі ноти перед виходом на сцену.',
    exerciseIds: ['rag_doll', 'flow_studies', 'panting', 'air_notes', 'long_tones'] },
  { id: 'strelnikova', title: 'Стрельникова', durationLabel: '5–7 хв', description: 'Усі шість вправ гімнастики О. Стрельникової.',
    exerciseIds: ['str_palms', 'str_epaulettes', 'str_pump', 'str_cat', 'str_hug', 'str_pendulum'] },
];

// ── Налаштування вправи ─────────────────────────────────────────────────
export const defaults = (e) => ({ bpm: e.defaultBpm, series: e.series, repeats: null, syllable: 'ту' });
export const isTimed = (e) => e.mode === MODE.guided && e.totalSeconds > 0;
export const bpmAdjustable = (e) => e.mode === MODE.guided && e.bpmMax > e.bpmMin;
export const seriesAdjustable = (e) => e.mode === MODE.guided && e.seriesMax > e.seriesMin;
const clampN = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const int = (v) => (typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : null);

/** Збережені налаштування поверх значень вправи, обмежені діапазонами. */
export function settingsFor(e, saved) {
  const d = defaults(e);
  const s = saved && typeof saved === 'object' ? saved : {};
  return {
    bpm: clampN(int(s.bpm) ?? d.bpm, e.bpmMin, e.bpmMax),
    series: clampN(int(s.series) ?? d.series, e.seriesMin, e.seriesMax),
    repeats: e.repeatsAdjustable && int(s.repeats) != null ? clampN(int(s.repeats), 1, 20) : null,
    syllable: s.syllable === 'ху' ? 'ху' : 'ту',
  };
}

// ── Розгортання вправи в кроки ──────────────────────────────────────────
function groupRepeats(e, g, s) {
  if (isTimed(e)) {
    const beats = g.phases.reduce((a, p) => a + p.beats, 0);
    return beats ? Math.max(1, Math.round(e.totalSeconds * s.bpm / 60 / beats)) : 1;
  }
  return e.repeatsAdjustable && s.repeats != null ? s.repeats : g.repeats;
}

/**
 * Кроки GUIDED-вправи: { index, type, beats, start, duration (мс), hint, swell,
 * series, seriesTotal, repeat, repeatsTotal, isSeriesRest }. Початок кроку
 * рахується від загальної кількості долей і секунд — похибка не накопичується.
 */
export function buildTimeline(e, settings) {
  if (e.mode !== MODE.guided) return [];
  const s = settingsFor(e, settings);
  const beatMs = 60000 / s.bpm;
  const seriesTotal = seriesAdjustable(e) ? s.series : e.series;
  const reps = e.groups.map((g) => groupRepeats(e, g, s));
  const repeatsTotal = reps.reduce((a, b) => a + b, 0);
  const steps = [];
  let beats = 0, secMs = 0;
  const us = (x) => Math.round(x * 1000) / 1000; // до мікросекунди — без хвостів плаваючої коми
  const now = () => us(beats * beatMs + secMs);
  const add = (type, { b = 0, ms = 0, hint = '', swell = false, series, repeat, seriesRest = false }) => {
    const start = now();
    beats += b; secMs += ms;
    steps.push({ index: steps.length, type, beats: b, start, duration: us(now() - start), hint, swell,
      series, seriesTotal, repeat, repeatsTotal, isSeriesRest: seriesRest });
  };
  for (let series = 1; series <= seriesTotal; series++) {
    if (series > 1 && e.restBetweenSeriesSec > 0) {
      add('rest', { ms: e.restBetweenSeriesSec * 1000, hint: `відпочинок перед серією ${series}`, series, repeat: 0, seriesRest: true });
    }
    let repeat = 0;
    e.groups.forEach((g, gi) => {
      for (let r = 0; r < reps[gi]; r++) {
        repeat++;
        for (const p of g.phases) {
          add(p.type, { b: p.beats, ms: p.seconds * 1000, hint: e.hasSyllable && p.type === 'action' ? s.syllable : p.hint,
            swell: p.swell, series, repeat });
        }
      }
    });
  }
  return steps;
}

export const stepEnd = (st) => st.start + st.duration;

/** Орієнтовна тривалість, с. */
export function estimateSeconds(e, settings) {
  if (e.mode === MODE.stopwatch) return 60;
  if (e.mode === MODE.freeTimer) return e.totalSeconds;
  const t = buildTimeline(e, settings ?? defaults(e));
  return t.length ? Math.round(stepEnd(t[t.length - 1]) / 1000) : 0;
}

export function estimateProgramSeconds(p, transitionSec = 5) {
  const list = p.exerciseIds.map((id) => BY_ID[id]).filter(Boolean);
  return list.reduce((a, e) => a + estimateSeconds(e), 0) + transitionSec * list.length;
}

const monotonic = () => performance.now();

// ── Рушій GUIDED ────────────────────────────────────────────────────────
/**
 * Стан-машина виконання. Позиція — лише з монотонного годинника, тож
 * tick() можна викликати як завгодно часто: він визначає, де ми зараз,
 * і повідомляє про нові фази й долі через onPhase / onBeat.
 */
export class BreathEngine {
  constructor(steps, clock = monotonic) {
    this.steps = steps;
    this.clock = clock;
    this.status = 'ready'; // ready | running | paused | finished
    this.completed = false;
    this.base = 0; this.resumedAt = 0;
    this.stepIndex = -1; this.beat = -1;
    this.onPhase = null; this.onBeat = null; this.onFinish = null;
  }
  get total() { return this.steps.length ? stepEnd(this.steps[this.steps.length - 1]) : 0; }
  get elapsed() {
    const e = this.status === 'running' ? this.base + this.clock() - this.resumedAt : this.base;
    return Math.min(e, this.total);
  }
  get current() { return this.steps[this.stepIndex] ?? null; }
  get stepProgress() {
    const s = this.current;
    return !s || !s.duration ? 0 : clampN((this.elapsed - s.start) / s.duration, 0, 1);
  }
  get progress() { return this.total ? this.elapsed / this.total : 0; }
  get remainingInStep() { const s = this.current; return s ? clampN(stepEnd(s) - this.elapsed, 0, s.duration) : 0; }
  /** Мс до наступної долі чи межі фази — для точного таймера звуку. */
  get untilNextEvent() {
    const s = this.current;
    if (!s || this.status !== 'running') return 0;
    if (s.beats > 0) return Math.min(s.start + (this.beat + 1) * s.duration / s.beats, stepEnd(s)) - this.elapsed;
    return stepEnd(s) - this.elapsed;
  }
  start() {
    if (this.status !== 'ready') return;
    if (!this.steps.length) { this._finish(true); return; }
    this.base = 0; this.resumedAt = this.clock(); this.status = 'running';
    this._update();
  }
  pause() { if (this.status !== 'running') return; this.base = this.elapsed; this.status = 'paused'; }
  resume() { if (this.status !== 'paused') return; this.resumedAt = this.clock(); this.status = 'running'; this._update(); }
  toggle() { if (this.status === 'running') this.pause(); else this.resume(); }
  stop() { if (this.status === 'finished') return; this.base = this.elapsed; this._finish(false); }
  skip() {
    if (this.status !== 'running' && this.status !== 'paused') return;
    const next = this.stepIndex + 1;
    if (next >= this.steps.length) { this.base = this.total; this._finish(true); return; }
    this.base = this.steps[next].start; this.resumedAt = this.clock();
    this._update();
  }
  tick() { if (this.status === 'running') this._update(); }
  _update() {
    const e = this.elapsed;
    if (e >= this.total) { this.base = this.total; this._finish(true); return; }
    let i = Math.max(0, this.stepIndex);
    while (i < this.steps.length - 1 && e >= stepEnd(this.steps[i])) i++;
    const s = this.steps[i];
    const b = s.beats > 0 ? clampN(Math.floor((e - s.start) * s.beats / s.duration), 0, s.beats - 1) : -1;
    if (i !== this.stepIndex) {
      this.stepIndex = i; this.beat = b;
      this.onPhase?.(s);
      if (b >= 0) this.onBeat?.(s, b);
    } else if (b !== this.beat) {
      this.beat = b;
      this.onBeat?.(s, b);
    }
  }
  _finish(done) { this.status = 'finished'; this.completed = done; this.onFinish?.(done); }
}

// ── Секундомір видиху ──────────────────────────────────────────────────
/** Спроба: відлік → вдих → секундомір видиху → «Стоп». */
export class StopwatchSession {
  constructor(clock = monotonic, countdownSec = 3, inhaleSec = 3) {
    this.clock = clock; this.countdownSec = countdownSec; this.inhaleSec = inhaleSec;
    this.phase = 'ready'; // ready | countdown | inhale | exhale | done
    this.phaseStart = 0; this.lastCount = 0; this.result = 0;
    this.onPhase = null; this.onCountdown = null;
  }
  get inPhase() { return this.clock() - this.phaseStart; }
  get secondsLeft() {
    const total = this.phase === 'countdown' ? this.countdownSec : this.phase === 'inhale' ? this.inhaleSec : 0;
    const left = total - this.inPhase / 1000;
    return left <= 0 ? 0 : Math.ceil(left);
  }
  get inhaleProgress() { return this.phase === 'inhale' ? clampN(this.inPhase / (this.inhaleSec * 1000), 0, 1) : 0; }
  get exhaleSeconds() { return this.phase === 'exhale' ? this.inPhase / 1000 : this.phase === 'done' ? this.result : 0; }
  start() {
    if (this.phase !== 'ready' && this.phase !== 'done') return;
    this.result = 0;
    this._enter(this.countdownSec > 0 ? 'countdown' : 'inhale');
    if (this.phase === 'countdown') { this.lastCount = this.countdownSec; this.onCountdown?.(this.countdownSec); }
  }
  /** «Стоп» на видиху фіксує результат; раніше — скасовує спробу. */
  stop() {
    if (this.phase === 'exhale') { this.result = this.inPhase / 1000; this._enter('done'); }
    else if (this.phase === 'countdown' || this.phase === 'inhale') this.cancel();
  }
  cancel() { if (this.phase === 'ready') return; this.result = 0; this._enter('ready'); }
  tick() {
    if (this.phase === 'countdown') {
      if (this.inPhase >= this.countdownSec * 1000) { this._enter('inhale', this.phaseStart + this.countdownSec * 1000); this.tick(); return; }
      const left = this.secondsLeft;
      if (left !== this.lastCount) { this.lastCount = left; this.onCountdown?.(left); }
    } else if (this.phase === 'inhale' && this.inPhase >= this.inhaleSec * 1000) {
      this._enter('exhale', this.phaseStart + this.inhaleSec * 1000);
    }
  }
  /** at — точний момент межі фази, щоб запізнілий кадр не з'їдав час. */
  _enter(p, at) { this.phase = p; this.phaseStart = at ?? this.clock(); this.onPhase?.(p); }
}

// ── Таймер ─────────────────────────────────────────────────────────────
export class FreeTimer {
  constructor(totalSeconds, clock = monotonic) {
    this.totalMs = totalSeconds * 1000; this.clock = clock;
    this.status = 'ready'; // ready | running | paused | done
    this.base = 0; this.resumedAt = 0; this.timeUp = false; this.onTimeUp = null;
  }
  get elapsed() { return Math.min(this.status === 'running' ? this.base + this.clock() - this.resumedAt : this.base, this.totalMs); }
  get remainingSeconds() { return Math.ceil((this.totalMs - this.elapsed) / 1000); }
  get progress() { return this.totalMs ? this.elapsed / this.totalMs : 1; }
  start() { if (this.status === 'ready' || this.status === 'paused') { this.resumedAt = this.clock(); this.status = 'running'; } }
  pause() { if (this.status !== 'running') return; this.base = this.elapsed; this.status = 'paused'; }
  toggle() { if (this.status === 'running') this.pause(); else this.start(); }
  finish() { if (this.status === 'done') return; this.base = this.elapsed; this.status = 'done'; }
  tick() {
    if (this.status !== 'running' || this.elapsed < this.totalMs) return;
    this.base = this.totalMs; this.timeUp = true; this.status = 'done'; this.onTimeUp?.();
  }
}

// ── Програма ────────────────────────────────────────────────────────────
export class ProgramRun {
  constructor(program) {
    this.program = program;
    this.exercises = program.exerciseIds.map((id) => BY_ID[id]).filter(Boolean);
    this.statuses = this.exercises.map(() => 'pending'); // pending | done | stopped | skipped
    this.index = 0; this.warned = false;
  }
  get finished() { return this.index >= this.exercises.length; }
  get current() { return this.finished ? null : this.exercises[this.index]; }
  /** Попередження Стрельникової — один раз, перед першою вправою блоку II. */
  get needsStrelnikovaWarning() { return !this.warned && this.current?.block === 2; }
  complete(done) { this._advance(done ? 'done' : 'stopped'); }
  skip() { this._advance('skipped'); }
  abort() { while (!this.finished) this.skip(); }
  count(s) { return this.statuses.filter((x) => x === s).length; }
  _advance(s) { if (this.finished) return; this.statuses[this.index] = s; this.index++; }
}

// ── Статистика ──────────────────────────────────────────────────────────
export const dayOf = (t) => { const d = new Date(t); return new Date(d.getFullYear(), d.getMonth(), d.getDate()); };
const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
/** Понеділок поточного тижня. */
export const weekStart = (now) => { const d = dayOf(now); return addDays(d, -((d.getDay() + 6) % 7)); };

/** Виконані вправи по днях поточного тижня [пн … нд]. sessions: { at (мс), completed }. */
export function weekCounts(sessions, now) {
  const start = weekStart(now);
  const counts = Array(7).fill(0);
  for (const s of sessions) {
    if (!s.completed) continue;
    const d = Math.round((dayOf(s.at) - start) / 86400000);
    if (d >= 0 && d < 7) counts[d]++;
  }
  return counts;
}

/** Днів поспіль із тренуванням; сьогодні ще без тренування — рахуємо від учора. */
export function currentStreak(sessions, now) {
  const days = new Set(sessions.filter((s) => s.completed).map((s) => dayOf(s.at).getTime()));
  let d = dayOf(now);
  if (!days.has(d.getTime())) d = addDays(d, -1);
  let n = 0;
  while (days.has(d.getTime())) { n++; d = addDays(d, -1); }
  return n;
}

export function longestStreak(sessions) {
  const days = [...new Set(sessions.filter((s) => s.completed).map((s) => dayOf(s.at).getTime()))].sort((a, b) => a - b);
  let best = 0, run = 0, prev = null;
  for (const t of days) {
    run = prev != null && addDays(new Date(prev), 1).getTime() === t ? run + 1 : 1;
    best = Math.max(best, run);
    prev = t;
  }
  return best;
}

export const bestOf = (attempts) => attempts.reduce((m, a) => Math.max(m, a.seconds), 0);

/** Останні limit спроб вправи за часом — для графіка. attempts: { exerciseId, seconds, at }. */
export function chartPoints(attempts, exerciseId, limit = 30) {
  const list = attempts.filter((a) => a.exerciseId === exerciseId).sort((a, b) => a.at - b.at);
  return list.slice(-limit);
}

// ── Формат ─────────────────────────────────────────────────────────────
const plural = (n, one, few, many) => {
  const m10 = n % 10, m100 = n % 100;
  return m10 === 1 && m100 !== 11 ? one : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? few : many;
};
export const fmt = {
  duration: (sec) => (sec >= 60 ? `${Math.floor(sec / 60)} хв${sec % 60 ? ` ${sec % 60} с` : ''}` : `${sec} с`),
  approx: (sec) => `≈ ${fmt.duration(sec)}`,
  clock: (sec) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`,
  secNumber: (s) => s.toFixed(1).replace('.', ','),
  sec: (s) => `${fmt.secNumber(s)} с`,
  exercises: (n) => `${n} ${plural(n, 'вправа', 'вправи', 'вправ')}`,
  days: (n) => `${n} ${plural(n, 'день', 'дні', 'днів')}`,
  attempts: (n) => `${n} ${plural(n, 'спроба', 'спроби', 'спроб')}`,
  dateTime: (t) => {
    const d = new Date(t), two = (v) => String(v).padStart(2, '0');
    return `${two(d.getDate())}.${two(d.getMonth() + 1)} ${two(d.getHours())}:${two(d.getMinutes())}`;
  },
};

export const PHASE_LABEL = { inhale: 'ВДИХ', exhale: 'ВИДИХ', hold: 'ПАУЗА', action: 'ІМПУЛЬС', rest: 'ВІДПОЧИНОК' };
export const PHASE_SPOKEN = { inhale: 'Вдих', exhale: 'Видих', hold: 'Пауза', action: 'Імпульс', rest: 'Відпочинок' };
export const MODE_LABEL = { guided: 'Під метроном', stopwatch: 'Секундомір', freeTimer: 'Таймер' };
