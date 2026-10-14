// node --test scripts/site_tests/practice_core.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  STAGES, ALL_STEPS, STEP_BY_ID, MAX_CURRENT, MAX_EXAM, stepStatus, totals, ectsGrade, bestByTopic,
  bestExam, nextStep, BREATH_DATES, TRACKED_SIGNALS, topicNumber,
} from '../../site/js/practice-core.js';

test('сума максимальних балів = 100 (60 поточних + 40 залік)', () => {
  assert.equal(MAX_CURRENT, 60);
  assert.equal(MAX_EXAM, 40);
  const pr = ALL_STEPS.filter((s) => s.group === 'pr');
  const sr = ALL_STEPS.filter((s) => s.group === 'sr');
  assert.equal(pr.length, 4);
  assert.equal(sr.length, 4);
});

test('id кроків унікальні', () => {
  assert.equal(new Set(ALL_STEPS.map((s) => s.id)).size, ALL_STEPS.length);
  assert.ok(STAGES.length >= 7);
});

test('submit: не виконано → на перевірці → оцінено', () => {
  const step = STEP_BY_ID.d1_sr;
  assert.equal(stepStatus(step, {}, {}).state, 'todo');
  const work = { steps: { d1_sr: { done: true, files: [{ name: 'a.jpg' }] } } };
  const r = stepStatus(step, work, {});
  assert.equal(r.state, 'review');
  assert.match(r.label, /На перевірці: максимальна кількість балів за завдання 6 балів/);
  const g = stepStatus(step, work, { d1_sr: { points: 5, status: 'graded' } });
  assert.equal(g.state, 'graded');
  assert.equal(g.points, 5);
  assert.match(g.label, /5 з 6/);
});

test('submit: на доопрацювання, після повторної здачі — знову на перевірці', () => {
  const step = STEP_BY_ID.d2_sr;
  const grades = { d2_sr: { status: 'revise', comment: 'мало', gradedAt: 1000 } };
  assert.equal(stepStatus(step, { steps: { d2_sr: { done: true, submittedAt: 500 } } }, grades).state, 'revise');
  assert.equal(stepStatus(step, { steps: { d2_sr: { done: true, submittedAt: 2000 } } }, grades).state, 'review');
});

test('quiz і retest рахуються з quiz_results', () => {
  const qr = [
    { kind: 'theory', topicName: 'Практика. Тема 2. Мисливський ріжок', correct: 7, total: 10, percent: 70 },
    { kind: 'theory', topicName: 'Практика. Тема 3. Музична грамота', correct: 9, total: 10, percent: 90 },
    { kind: 'theory', topicName: 'Практика. Тема 2. Мисливський ріжок', correct: 9, total: 10, percent: 90 },
    { kind: 'audio', topicName: 'сигнали практики', correct: 5, total: 6, percent: 83 },
  ];
  assert.deepEqual(bestByTopic(qr), { 2: 90, 3: 90 });
  assert.equal(stepStatus(STEP_BY_ID.d2_quiz, {}, {}, { quizResults: qr }).state, 'done');
  assert.equal(stepStatus(STEP_BY_ID.d1_quiz, {}, {}, { quizResults: qr }).state, 'todo');
  assert.equal(stepStatus(STEP_BY_ID.w_retest, {}, {}, { quizResults: qr }).state, 'todo');
  assert.equal(stepStatus(STEP_BY_ID.d3_audio, {}, {}, { quizResults: qr }).label, 'Спроб: 1 з 3');
  assert.equal(topicNumber('Підсумковий тест'), null);
});

test('щоденник, дихання, сигнали', () => {
  assert.equal(stepStatus(STEP_BY_ID.d1_diary, { diary: { d1: { aud: 'x', self: 'y', concl: '' } } }).state, 'todo');
  assert.equal(stepStatus(STEP_BY_ID.d1_diary, { diary: { d1: { aud: 'x', self: 'y', concl: 'z' } } }).state, 'done');
  const breath = Object.fromEntries(BREATH_DATES.map((d) => [d, { ex: [true, false, false, false], sec: 20 }]));
  assert.equal(stepStatus(STEP_BY_ID.d2_breath, { breath }).state, 'done');
  delete breath['03.10'];
  assert.match(stepStatus(STEP_BY_ID.d2_breath, { breath }).label, /4 з 5/);
  const signals = Object.fromEntries(TRACKED_SIGNALS.map((s) => [s, { know: true }]));
  assert.equal(stepStatus(STEP_BY_ID.d3_signals, { signals }).state, 'done');
});

test('іспит: автоматичні бали, правка викладача має перевагу', () => {
  const exam = bestExam(
    [{ sessionId: 'S1', uid: 'u', status: 'submitted', theory: { points: 15 }, audio: { points: 4 } },
      { sessionId: 'S2', uid: 'u', status: 'in_progress', theory: { points: 20 } }],
    [{ id: 'S1_u', adminTheoryPoints: 17 }],
  );
  assert.deepEqual(exam, { theory: 17, audio: 4 });
  assert.equal(stepStatus(STEP_BY_ID.e_theory, {}, {}, { exam }).points, 17);
  assert.equal(stepStatus(STEP_BY_ID.e_theory, {}, { e_theory: { points: 19 } }, { exam }).points, 19);
  assert.equal(stepStatus(STEP_BY_ID.e_signal, {}, {}).state, 'teacher');
});

test('підсумок, допуск і оцінка', () => {
  const grades = {};
  ['d1_pr', 'd2_pr', 'd3_pr', 'd4_pr', 'd1_sr', 'd2_sr', 'd3_sr', 'd4_sr'].forEach((id) => { grades[id] = { points: 5 }; });
  grades.w_report = { points: 10 };
  grades.e_signal = { points: 7 };
  grades.e_rhythm = { points: 5 };
  const t = totals({}, grades, { exam: { theory: 18, audio: 5 } });
  assert.equal(t.current, 50);
  assert.equal(t.exam, 35);
  assert.equal(t.total, 85);
  assert.equal(t.admitted, true);
  assert.equal(t.grade.ects, 'B');
  assert.equal(ectsGrade(60).ects, 'E');
  assert.equal(ectsGrade(34).ects, 'F');
  assert.equal(nextStep({}, {}, {}).id, 'prep_profile');
});

test('check: відмітка студента → очікування підтвердження → підтверджено / не підтверджено', () => {
  const step = STEP_BY_ID.d1_safety;
  assert.equal(stepStatus(step, {}, {}).state, 'todo');
  const work = { steps: { d1_safety: { done: true, doneAt: 500 } } };
  const r = stepStatus(step, work, {});
  assert.equal(r.state, 'review');
  assert.equal(r.label, 'Очікування на підтвердження');
  assert.equal(stepStatus(step, work, { d1_safety: { points: 0, status: 'graded' } }).label, 'Виконано · Підтверджено');
  const no = { d1_safety: { points: null, status: 'revise', gradedAt: 1000 } };
  assert.equal(stepStatus(step, work, no).state, 'revise');
  assert.equal(stepStatus(step, { steps: { d1_safety: { done: true, doneAt: 2000 } } }, no).state, 'review');
  assert.equal(nextStep({ steps: { prep_rules: { done: true }, prep_diary: { done: true } } }, {}, { profile: { fullName: 'a', group: 'b' } }).id, 'd1_safety');
  assert.equal(totals(work, {}).review, 1);
});

test('скинута оцінка (status none, points null) не рахується як 0 балів', () => {
  const st = stepStatus(STEP_BY_ID.d1_pr, { steps: { d1_pr: { done: true } } }, { d1_pr: { points: null, status: 'none' } });
  assert.equal(st.state, 'review');
  assert.equal(st.points, null);
  assert.equal(stepStatus(STEP_BY_ID.e_signal, {}, { e_signal: { points: null, status: 'none' } }).state, 'teacher');
});
