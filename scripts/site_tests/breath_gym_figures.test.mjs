// Тести анімованих фігурок тренажера (site/js/breath-gym-figures.js).
// Запуск: node --test scripts/site_tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { FIGURE_IDS, figureFrame, demoState, stepVariant } from '../../site/js/breath-gym-figures.js';
import { EXERCISES, BY_ID, buildTimeline, defaults } from '../../site/js/breath-gym-core.js';

const finite = (pt) => Number.isFinite(pt[0]) && Number.isFinite(pt[1]);
const JOINTS = ['hip', 'neck', 'head', 'lSh', 'rSh', 'lEl', 'lHand', 'rEl', 'rHand', 'lKnee', 'lFoot', 'rKnee', 'rFoot', 'mouth', 'nose'];

test('фігурка є для кожної вправи каталогу', () => {
  assert.deepEqual([...FIGURE_IDS].sort(), EXERCISES.map((e) => e.id).sort());
});

test('кадри коректні в усіх фазах: суглоби в межах полотна, фігура на підлозі', () => {
  for (const id of FIGURE_IDS) {
    for (const type of ['inhale', 'exhale', 'hold', 'action', 'rest']) {
      for (const progress of [0, 0.3, 0.5, 1]) {
        const f = figureFrame(id, { type, progress, beats: 7, variant: 1, swell: true });
        for (const k of JOINTS) {
          assert.ok(finite(f.j[k]), `${id} ${type} ${k}`);
          assert.ok(f.j[k][0] > -5 && f.j[k][0] < 205 && f.j[k][1] > -5 && f.j[k][1] <= 186.01, `${id} ${type} ${k} ${f.j[k]}`);
        }
        assert.ok(f.breath >= 0 && f.breath <= 1, `${id} ${type} breath`);
      }
    }
  }
});

test('вдих наповнює живіт, видих спорожнює', () => {
  for (const id of ['flow_studies', 'stretch_breath', 'book_on_belly', 'hiss_exhale']) {
    assert.ok(figureFrame(id, { type: 'inhale', progress: 1 }).breath > figureFrame(id, { type: 'inhale', progress: 0 }).breath, id);
    assert.ok(figureFrame(id, { type: 'exhale', progress: 1 }).breath < figureFrame(id, { type: 'exhale', progress: 0 }).breath, id);
  }
});

test('«Кішка» й «Маятник»: варіант із підказки кроку, пози різні', () => {
  for (const id of ['str_cat', 'str_pendulum']) {
    const steps = buildTimeline(BY_ID[id], defaults(BY_ID[id])).filter((s) => s.type === 'inhale');
    assert.equal(stepVariant(BY_ID[id], steps[0]), 0);
    assert.equal(stepVariant(BY_ID[id], steps[1]), 1);
    const a = figureFrame(id, { type: 'inhale', progress: 0.32, variant: 0 }).pose;
    const b = figureFrame(id, { type: 'inhale', progress: 0.32, variant: 1 }).pose;
    assert.notDeepEqual(a, b);
  }
  // для решти вправ варіант завжди 0
  const st = buildTimeline(BY_ID.str_palms, defaults(BY_ID.str_palms))[1];
  assert.equal(stepVariant(BY_ID.str_palms, st), 0);
});

test('демо-цикл зациклюється й повертає стан у межах', () => {
  for (const id of FIGURE_IDS) {
    for (const t of [0, 1.234, 17.5, 999]) {
      const s = demoState(id, t);
      assert.ok(['inhale', 'exhale', 'hold', 'action', 'rest'].includes(s.type), id);
      assert.ok(s.progress >= 0 && s.progress <= 1, id);
    }
  }
});
