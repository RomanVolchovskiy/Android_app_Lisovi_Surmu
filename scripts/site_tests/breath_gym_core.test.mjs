// Тести логіки дихального тренажера сайту (site/js/breath-gym-core.js).
// Запуск: node --test scripts/site_tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  EXERCISES, BY_ID, BLOCKS, PROGRAMS, defaults, settingsFor, buildTimeline, stepEnd, estimateSeconds,
  estimateProgramSeconds, BreathEngine, StopwatchSession, FreeTimer, ProgramRun, weekCounts, weekStart,
  currentStreak, longestStreak, chartPoints, bestOf, fmt,
} from '../../site/js/breath-gym-core.js';

const fake = () => { const c = { t: 0 }; c.now = () => c.t; return c; };
const tl = (id, over = {}) => buildTimeline(BY_ID[id], { ...defaults(BY_ID[id]), ...over });

test('каталог: 17 вправ, блоки 1–5, програми посилаються на наявні', () => {
  assert.equal(EXERCISES.length, 17);
  assert.equal(Object.keys(BY_ID).length, 17);
  for (const e of EXERCISES) assert.ok(BLOCKS[e.block], e.id);
  for (const p of PROGRAMS) for (const id of p.exerciseIds) assert.ok(BY_ID[id], `${p.id}: ${id}`);
  assert.deepEqual(PROGRAMS.find((p) => p.id === 'daily').exerciseIds,
    ['stretch_breath', 'str_palms', 'str_epaulettes', 'str_pump', 'flow_studies', 'hiss_exhale', 'long_tones']);
});

test('розтяжка: 6 × (вдих 4, видих 4) при 60 bpm = 48 с; повтори з налаштувань', () => {
  const t = tl('stretch_breath');
  assert.equal(t.length, 12);
  assert.deepEqual(t.slice(0, 2).map((s) => [s.type, s.beats, s.duration]), [['inhale', 4, 4000], ['exhale', 4, 4000]]);
  assert.equal(stepEnd(t[11]), 48000);
  assert.equal(tl('stretch_breath', { repeats: 2 }).length, 4);
});

test('Стрельникова: 3 серії по 8 вдихів, між серіями 4 с; до 12 серій; bpm 60–120', () => {
  const t = tl('str_palms');
  assert.equal(t.length, 26);
  assert.deepEqual(t.filter((s) => s.isSeriesRest).map((s) => [s.index, s.duration, s.beats]), [[8, 4000, 0], [17, 4000, 0]]);
  assert.ok(t.filter((s) => !s.isSeriesRest).every((s) => s.type === 'inhale' && s.beats === 1));
  assert.ok(Math.abs(stepEnd(t[t.length - 1]) - 24000) < 1e-6);
  const max = tl('str_pump', { series: 20 });
  assert.equal(max.filter((s) => s.type === 'inhale').length, 96);
  assert.equal(tl('str_hug', { bpm: 300 })[0].duration, 500);
});

test('«Кішка»: підказки чергуються', () => {
  const t = tl('str_cat').filter((s) => !s.isSeriesRest);
  t.forEach((s, i) => assert.equal(s.hint, i % 2 ? 'присід з поворотом вліво' : 'присід з поворотом вправо'));
});

test('Flow Studies: 4/4 → 3/5 → 2/6 → 1/7 → 1/8, кожна пара двічі, без пауз', () => {
  const t = tl('flow_studies');
  assert.deepEqual(t.map((s) => s.beats), [4, 4, 4, 4, 3, 5, 3, 5, 2, 6, 2, 6, 1, 7, 1, 7, 1, 8, 1, 8]);
  for (let i = 1; i < t.length; i++) assert.equal(t[i].start, stepEnd(t[i - 1]));
  assert.deepEqual(t.filter((s) => s.hint === 'так дихаємо під час гри').map((s) => s.beats), [7, 7, 8, 8]);
  assert.equal(stepEnd(t[t.length - 1]), 82000);
});

test('«Собачка», «Повітряні ноти», «Довгі ноти»', () => {
  const p = tl('panting');
  const first = p.filter((s) => s.series === 1);
  assert.ok(Math.abs(stepEnd(first[first.length - 1]) / 1000 - 15) < 0.5);
  assert.equal(p.filter((s) => s.isSeriesRest).length, 1);
  assert.equal(tl('air_notes', { syllable: 'ху' })[1].hint, 'ху');
  assert.deepEqual(tl('long_tones').filter((s) => s.type === 'exhale').map((s) => s.swell), [false, false, false, false, true, true, true, true]);
  assert.equal(estimateSeconds(BY_ID.breathing_bag), 120);
  assert.equal(estimateProgramSeconds(PROGRAMS.find((x) => x.id === 'strelnikova')), 6 * 24 + 30);
});

test('налаштування: биті й поза діапазоном значення', () => {
  const s = settingsFor(BY_ID.str_palms, { bpm: 500, series: 40, repeats: 9, syllable: 7 });
  assert.deepEqual(s, { bpm: 120, series: 12, repeats: null, syllable: 'ту' });
  assert.equal(settingsFor(BY_ID.stretch_breath, 'сміття').bpm, 60);
});

test('рушій: фази й долі за годинником, пауза, пропуск, кінець', () => {
  const c = fake();
  const e = new BreathEngine(tl('stretch_breath', { repeats: 2 }), c.now);
  const ev = [];
  e.onPhase = (s) => ev.push(`phase ${s.index}`);
  e.onBeat = (s, b) => ev.push(`beat ${s.index}.${b}`);
  e.start();
  c.t = 1000; e.tick();
  c.t = 4000; e.tick();
  assert.deepEqual(ev, ['phase 0', 'beat 0.0', 'beat 0.1', 'phase 1', 'beat 1.0']);
  assert.equal(e.untilNextEvent, 1000);
  c.t = 10500; e.tick(); // стрибок у середину 3-ї фази
  assert.equal(e.stepIndex, 2); assert.equal(e.beat, 2);
  e.pause(); c.t = 70000; e.tick();
  assert.equal(e.elapsed, 10500);
  e.resume(); e.skip();
  assert.equal(e.stepIndex, 3); assert.equal(e.elapsed, 12000);
  c.t += 4000; e.tick();
  assert.equal(e.status, 'finished'); assert.equal(e.completed, true); assert.equal(e.progress, 1);
  const s = new BreathEngine(e.steps, c.now); s.start(); s.stop();
  assert.equal(s.completed, false);
});

test('секундомір: відлік → вдих → видих → стоп; запізнілий кадр; скасування', () => {
  const c = fake();
  const s = new StopwatchSession(c.now);
  const ev = [];
  s.onPhase = (p) => ev.push(p); s.onCountdown = (n) => ev.push(String(n));
  s.start();
  for (let i = 0; i < 30; i++) { c.t += 100; s.tick(); }
  assert.deepEqual(ev, ['countdown', '3', '2', '1', 'inhale']);
  c.t += 3000; s.tick();
  assert.equal(s.phase, 'exhale');
  c.t += 21400; s.stop();
  assert.ok(Math.abs(s.result - 21.4) < 1e-9);
  const late = new StopwatchSession(c.now); late.start(); c.t += 6500; late.tick();
  assert.equal(late.phase, 'exhale'); assert.ok(Math.abs(late.exhaleSeconds - 0.5) < 1e-9);
  const early = new StopwatchSession(c.now); early.start(); c.t += 1000; early.tick(); early.stop();
  assert.equal(early.phase, 'ready'); assert.equal(early.result, 0);
});

test('таймер: пауза й кінець часу', () => {
  const c = fake();
  const t = new FreeTimer(120, c.now);
  let up = 0; t.onTimeUp = () => up++;
  t.start(); c.t = 30000; t.tick();
  assert.equal(t.remainingSeconds, 90);
  t.pause(); c.t = 600000; t.tick();
  assert.equal(t.remainingSeconds, 90);
  t.start(); c.t += 90000; t.tick();
  assert.equal(t.status, 'done'); assert.equal(t.timeUp, true); assert.equal(up, 1);
});

test('програма: статуси, попередження Стрельникової один раз, дострокове завершення', () => {
  const r = new ProgramRun(PROGRAMS.find((p) => p.id === 'daily'));
  assert.equal(r.needsStrelnikovaWarning, false);
  r.complete(true);
  assert.equal(r.needsStrelnikovaWarning, true);
  r.warned = true; r.skip();
  assert.equal(r.needsStrelnikovaWarning, false);
  r.complete(false); r.abort();
  assert.equal(r.finished, true);
  assert.deepEqual([r.count('done'), r.count('stopped'), r.count('skipped')], [1, 1, 5]);
});

test('статистика: тиждень з понеділка, серія днів, найдовша серія, точки графіка', () => {
  const now = new Date(2026, 9, 6, 20).getTime(); // вівторок
  const s = (y, m, d, h = 9, completed = true) => ({ at: new Date(y, m, d, h).getTime(), completed });
  assert.equal(weekStart(now).getTime(), new Date(2026, 9, 5).getTime());
  assert.deepEqual(weekCounts([s(2026, 9, 5), s(2026, 9, 5, 10), s(2026, 9, 6), s(2026, 9, 6, 8, false), s(2026, 9, 4, 23)], now),
    [2, 1, 0, 0, 0, 0, 0]);
  const sun = new Date(2026, 9, 11, 10).getTime();
  assert.deepEqual(weekCounts([{ at: sun, completed: true }], sun), [0, 0, 0, 0, 0, 0, 1]);
  assert.equal(currentStreak([s(2026, 9, 3), s(2026, 9, 4), s(2026, 9, 5)], now), 3);
  assert.equal(currentStreak([s(2026, 9, 2), s(2026, 9, 4)], now), 0);
  assert.equal(currentStreak([s(2026, 8, 30), s(2026, 9, 1)], new Date(2026, 9, 1, 12).getTime()), 2);
  assert.equal(longestStreak([s(2026, 8, 1), s(2026, 8, 2), s(2026, 8, 3), s(2026, 8, 3, 18), s(2026, 8, 10)]), 3);
  const a = Array.from({ length: 40 }, (_, i) => ({ exerciseId: 'candle', seconds: i, at: i * 1000 })).reverse();
  const pts = chartPoints(a, 'candle');
  assert.equal(pts.length, 30); assert.equal(pts[0].seconds, 10); assert.equal(bestOf(pts), 39);
});

test('формат: множина українською', () => {
  assert.deepEqual([1, 2, 5, 11, 21, 22].map(fmt.exercises), ['1 вправа', '2 вправи', '5 вправ', '11 вправ', '21 вправа', '22 вправи']);
  assert.equal(fmt.sec(5.24), '5,2 с');
  assert.equal(fmt.clock(65), '1:05');
});
