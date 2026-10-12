// Тести спільної логіки тестів та іспитів сайту (site/js/quiz-core.js).
// Запуск: node --test scripts/site_tests/quiz_core.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  shuffle, permuteOptions, orderedOptions, pickTheory, signalPool, buildAudioItems, scorePart,
  countTheoryCorrect, countAudioCorrect, answeredCount, csvField, toCsv, fmtDateTime, examConfig, attemptDeadline,
} from '../../site/js/quiz-core.js';

// Детермінований генератор (mulberry32)
const rng = (seed = 1) => () => {
  seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

test('shuffle: та сама множина, вихідний масив не змінюється', () => {
  const a = [1, 2, 3, 4, 5, 6];
  const b = shuffle(a, rng(3));
  assert.deepEqual(a, [1, 2, 3, 4, 5, 6]);
  assert.deepEqual([...b].sort(), a);
});

test('shuffle: рівномірний (Fisher–Yates) — кожен елемент на кожній позиції ≈ 1/n', () => {
  const n = 4; const runs = 40000; const r = rng(7);
  const counts = Array.from({ length: n }, () => Array(n).fill(0));
  for (let k = 0; k < runs; k++) shuffle([0, 1, 2, 3], r).forEach((v, pos) => counts[v][pos]++);
  counts.flat().forEach((c) => assert.ok(Math.abs(c / runs - 1 / n) < 0.015, `частка ${c / runs}`));
});

test('permuteOptions: правильний варіант відстежується після перестановки', () => {
  const q = { options: ['А', 'Б', 'В', 'Г'], correctIndex: 2 };
  for (let s = 1; s < 50; s++) {
    const p = permuteOptions(q, rng(s));
    assert.equal(p.options[p.correct], 'В');
    assert.deepEqual(p.options, p.order.map((i) => q.options[i]));
  }
  assert.deepEqual(permuteOptions(q, rng(1), false).order, [0, 1, 2, 3]);
});

test('orderedOptions: без order або з неправильною довжиною — вихідний порядок', () => {
  const q = { options: ['А', 'Б', 'В'] };
  assert.deepEqual(orderedOptions(q, [2, 0, 1]), ['В', 'А', 'Б']);
  assert.deepEqual(orderedOptions(q, null), ['А', 'Б', 'В']);
  assert.deepEqual(orderedOptions(q, [0, 1]), ['А', 'Б', 'В']);
});

const pool = Array.from({ length: 25 }, (_, i) => ({ id: `q${i}`, options: ['a', 'b', 'c', 'd'], correctIndex: i % 4 }));

test('pickTheory: кількість, унікальність, без перемішування — порядок пулу', () => {
  const items = pickTheory(pool, { count: 20 }, rng(5));
  assert.equal(items.length, 20);
  assert.equal(new Set(items.map((x) => x.qid)).size, 20);
  items.forEach((x) => { assert.equal(x.answer, null); assert.equal(x.order.length, 4); });
  const plain = pickTheory(pool, { count: 3, shuffleQuestions: false, shuffleOptions: false }, rng(5));
  assert.deepEqual(plain.map((x) => x.qid), ['q0', 'q1', 'q2']);
  assert.deepEqual(plain[0].order, [0, 1, 2, 3]);
  assert.equal(pickTheory(pool, { count: 99 }).length, 25);
  assert.equal(pickTheory([{ id: 'x', options: ['один'] }], { count: 5 }).length, 0, 'питання з одним варіантом пропускається');
});

test('countTheoryCorrect: зважає на перестановку варіантів', () => {
  const byId = new Map(pool.map((q) => [q.id, q]));
  const items = pickTheory(pool, { count: 10 }, rng(11));
  items.forEach((it, k) => {
    const q = byId.get(it.qid);
    const shown = it.order.indexOf(q.correctIndex);
    it.answer = k < 7 ? shown : (shown + 1) % 4; // 7 правильних, 3 хибні
  });
  assert.equal(countTheoryCorrect(items, byId), 7);
  items[0].answer = null;
  assert.equal(countTheoryCorrect(items, byId), 6);
  assert.equal(countTheoryCorrect([{ qid: 'gone', order: [0, 1], answer: 0 }], byId), 0);
  assert.equal(answeredCount(items), 9);
});

const sig = (id, name, extra = {}) => ({ id, name, audioUrl: `https://x/${id}.mp3`, tags: [], ...extra });

test('signalPool: лише з аудіо, без дублікатів файлу; тег без регістру; явні id; рівень', () => {
  const all = [sig('a', 'A', { tags: ['Практика'] }), sig('b', 'B', { tags: ['практика'], difficulty: 'easy' }),
    { id: 'c', name: 'C', audioUrl: '', tags: ['практика'] }, { ...sig('a', 'A2'), id: 'd' }, sig('e', 'E', { difficulty: 'easy' })];
  assert.deepEqual(signalPool(all).map((s) => s.id), ['a', 'b', 'e']);
  assert.deepEqual(signalPool(all, { tag: 'практика' }).map((s) => s.id), ['a', 'b']);
  assert.deepEqual(signalPool(all, { signalIds: ['e', 'c'] }).map((s) => s.id), ['e']);
  assert.deepEqual(signalPool(all, { difficulty: 'easy' }).map((s) => s.id), ['b', 'e']);
  assert.deepEqual(signalPool(all, { signalIds: ['e'], tag: 'практика' }).map((s) => s.id), ['e'], 'явний список має пріоритет');
});

test('buildAudioItems: 4 різні варіанти з правильним; хибні — з пулу, якщо в ньому ≥ 4', () => {
  const practice = ['A', 'B', 'C', 'D', 'E'].map((n) => sig(n.toLowerCase(), n));
  const others = ['X', 'Y', 'Z'].map((n) => sig(n.toLowerCase(), n));
  const items = buildAudioItems(practice, 10, rng(2), [...practice, ...others]);
  assert.equal(items.length, 5, 'не більше за пул');
  items.forEach((it) => {
    const name = practice.find((s) => s.id === it.signalId).name;
    assert.equal(it.options.length, 4);
    assert.equal(new Set(it.options).size, 4);
    assert.ok(it.options.includes(name));
    it.options.forEach((o) => assert.ok('ABCDE'.includes(o), 'хибні — з того самого пулу'));
  });
  const small = buildAudioItems(practice.slice(0, 2), 2, rng(4), [...practice, ...others]);
  small.forEach((it) => assert.equal(it.options.length, 4, 'малий пул — хибні з усіх сигналів'));
});

test('countAudioCorrect: правильна назва — поточна назва сигналу', () => {
  const byId = new Map([['a', sig('a', 'Збір')], ['b', sig('b', 'Халалі')]]);
  const items = [{ signalId: 'a', options: ['Халалі', 'Збір'], answer: 1 }, { signalId: 'b', options: ['Халалі', 'Збір'], answer: 1 },
    { signalId: 'b', options: ['Халалі'], answer: null }, { signalId: 'gone', options: ['Збір'], answer: 0 }];
  assert.equal(countAudioCorrect(items, byId), 1);
});

test('scorePart: критерії ТЗ 5.8', () => {
  assert.equal(scorePart(17, 20, 20), 17);
  assert.equal(scorePart(8, 10, 6), 5); // round(4,8)
  assert.equal(scorePart(7, 10, 6), 4); // round(4,2)
  assert.equal(scorePart(10, 10, 6), 6);
  assert.equal(scorePart(0, 0, 6), 0);
  assert.equal(scorePart(5, 10, 0), 0);
});

test('CSV: BOM, роздільник ";", лапки за потреби', () => {
  assert.equal(csvField('просто'), 'просто');
  assert.equal(csvField('a;b'), '"a;b"');
  assert.equal(csvField('він сказав "так"'), '"він сказав ""так"""');
  assert.equal(csvField('два\nрядки'), '"два\nрядки"');
  assert.equal(csvField(null), '');
  const text = toCsv([['№', 'ПІБ'], [1, 'Коваль; Анна']]);
  assert.equal(text.charCodeAt(0), 0xFEFF);
  assert.equal(text.slice(1), '№;ПІБ\r\n1;"Коваль; Анна"');
});

test('fmtDateTime: dd.MM.yyyy HH:mm', () => {
  assert.equal(fmtDateTime(new Date(2026, 9, 5, 9, 7)), '05.10.2026 09:07');
  assert.equal(fmtDateTime(null), '');
});

test('examConfig: нова сесія сайту і стара сесія додатку', () => {
  const site = examConfig({ theoryEnabled: true, theoryTopicIds: ['t7'], theoryTopicId: 't7', theoryQuestionCount: 20, theoryMaxPoints: 20,
    theoryShuffleOptions: false, audioEnabled: true, audioTag: 'практика', audioQuestionCount: 10, audioMaxPoints: 6, timeLimitMin: 30, showReview: true });
  assert.deepEqual(site.theory, { topicIds: ['t7'], count: 20, shuffleQuestions: true, shuffleOptions: false, maxPoints: 20 });
  assert.deepEqual(site.audio, { signalIds: null, tag: 'практика', difficulty: null, count: 10, maxPoints: 6 });
  assert.equal(site.timeLimitMin, 30);
  assert.equal(site.showReview, true);
  assert.equal(site.file, null);
  const app = examConfig({ theoryEnabled: true, theoryTopicId: 'old', theoryMaxPoints: 40, audioEnabled: true, audioDifficulty: 'hard',
    audioMaxPoints: 30, fileEnabled: true, fileMaxPoints: 30, fileTaskDescription: 'Звіт' });
  assert.deepEqual(app.theory.topicIds, ['old']);
  assert.equal(app.theory.count, 10);
  assert.equal(app.audio.difficulty, 'hard');
  assert.deepEqual(app.file, { maxPoints: 30, description: 'Звіт' });
  assert.equal(app.timeLimitMin, 0);
  assert.equal(examConfig({}).theory, null);
});

test('attemptDeadline: старт + ліміт, але не пізніше дедлайну сесії', () => {
  const start = new Date('2026-10-05T09:00:00Z');
  assert.equal(attemptDeadline(start, 30, null).toISOString(), '2026-10-05T09:30:00.000Z');
  assert.equal(attemptDeadline(start, 30, new Date('2026-10-05T09:20:00Z')).toISOString(), '2026-10-05T09:20:00.000Z');
  assert.equal(attemptDeadline(start, 30, new Date('2026-10-05T12:00:00Z')).toISOString(), '2026-10-05T09:30:00.000Z');
  assert.equal(attemptDeadline(start, 0, null), null);
  assert.equal(attemptDeadline(start, 0, new Date('2026-10-05T12:00:00Z')).toISOString(), '2026-10-05T12:00:00.000Z');
});
