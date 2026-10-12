// Тести імпорту CSV адмінки навчання (site/js/csv-import.js).
// Запуск: node --test scripts/site_tests/csv_import.test.mjs
// Якщо поруч є файли практики (PRACTICE_TESTS_DIR або
// D:/HuntingSignals/practice_docs/docs/practice/tests), перевіряються й вони.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import {
  parseCsvLine, csvLines, parseQuestionRow, parseCardRow, parseCsvFile, importId, bySortOrder,
} from '../../site/js/csv-import.js';

test('parseCsvLine: старі файли без лапок', () => {
  assert.deepEqual(parseCsvLine('а,б,в'), ['а', 'б', 'в']);
  assert.deepEqual(parseCsvLine('а,,в'), ['а', '', 'в']);
});

test('parseCsvLine: лапки за RFC 4180', () => {
  assert.deepEqual(parseCsvLine('"Ріжок, сурма",так'), ['Ріжок, сурма', 'так']);
  assert.deepEqual(parseCsvLine('"Він сказав ""Халалі""",x'), ['Він сказав "Халалі"', 'x']);
  assert.deepEqual(parseCsvLine('a,"b,c",d'), ['a', 'b,c', 'd']);
  assert.deepEqual(parseCsvLine('5"6,x'), ['5"6', 'x'], 'лапка в середині поля без лапок — звичайний символ');
});

test('csvLines: BOM, порожні рядки, заголовок, номери рядків файлу', () => {
  const text = '\uFEFFПитання,варіант1,в2,в3,в4,правильний\r\n\r\nQ1,a,b,c,d,0\n  \nQ2,a,b,c,d,1\n';
  assert.deepEqual(csvLines(text), [{ n: 3, line: 'Q1,a,b,c,d,0' }, { n: 5, line: 'Q2,a,b,c,d,1' }]);
  assert.equal(csvLines('question,answer\nQ,A').length, 1);
  assert.equal(csvLines('\uFEFFQ,a,b,c,d,0').length, 1, 'без заголовка перший рядок лишається');
  assert.deepEqual(csvLines(''), []);
});

test('parseQuestionRow: правильний рядок, пояснення з комами', () => {
  assert.deepEqual(parseQuestionRow('Що це?,А,Б,В,Г,2,Бо так, і все'),
    { row: { question: 'Що це?', options: ['А', 'Б', 'В', 'Г'], correctIndex: 2, explanation: 'Бо так, і все' } });
  assert.equal(parseQuestionRow('Q,a,b,c,d,0').row.explanation, null);
  assert.deepEqual(parseQuestionRow('"Ріжок, що це?","а, б",b,c,d,1').row.options, ['а, б', 'b', 'c', 'd']);
});

test('parseQuestionRow: помилки — correctIndex поза 0–3, мало полів, порожні', () => {
  assert.match(parseQuestionRow('Q,a,b,c,d,4').error, /не 0–3/);
  assert.match(parseQuestionRow('Q,a,b,c,d,').error, /не 0–3/);
  assert.match(parseQuestionRow('Q,a,b,c,d,x').error, /не 0–3/);
  assert.match(parseQuestionRow('Q,a,b,c,d,1.5').error, /не 0–3/);
  assert.match(parseQuestionRow('Q,a,b,c,1').error, /менше 6/);
  assert.match(parseQuestionRow(',a,b,c,d,1').error, /питання/);
  assert.match(parseQuestionRow('Q,a,,c,d,1').error, /варіант/);
});

test('parseCardRow: відповідь з комами без лапок — усе після першого поля', () => {
  assert.deepEqual(parseCardRow('Халалі,Сигнал завершення, полювання'), { row: { question: 'Халалі', answer: 'Сигнал завершення, полювання' } });
  assert.deepEqual(parseCardRow('"Ріжок, малий",Плесса').row, { question: 'Ріжок, малий', answer: 'Плесса' });
  assert.ok(parseCardRow('тільки питання').error);
});

test('parseCsvFile: рядки й пропущені з номерами', () => {
  const r = parseCsvFile('питання,в1,в2,в3,в4,п\nQ1,a,b,c,d,0\nQ2,a,b,c,d,7\nQ3,a,b,c,d,3', parseQuestionRow);
  assert.equal(r.rows.length, 2);
  assert.deepEqual(r.skipped.map((x) => x.n), [3]);
});

test('importId і bySortOrder: порядок рядків файлу зберігається', () => {
  assert.equal(importId('tq', 1700, 7), 'tq_1700_007');
  const ids = Array.from({ length: 12 }, (_, i) => importId('tq', 1, i));
  assert.deepEqual([...ids].sort(), ids, 'лексикографічний порядок = порядок рядків');
  // старі дані без sortOrder з id без нулів: _2 перед _10
  const old = ['tq_1_10', 'tq_1_2', 'tq_1_0', 'tq_1_1'].map((id) => ({ id }));
  assert.deepEqual(old.sort(bySortOrder).map((x) => x.id), ['tq_1_0', 'tq_1_1', 'tq_1_2', 'tq_1_10']);
  const mixed = [{ id: 'b', sortOrder: 1 }, { id: 'a', sortOrder: 2 }, { id: 'c', order: 0 }];
  assert.deepEqual(mixed.sort(bySortOrder).map((x) => x.id), ['c', 'b', 'a']);
});

const DIR = process.env.PRACTICE_TESTS_DIR || 'D:/HuntingSignals/practice_docs/docs/practice/tests';
test('файли практики імпортуються повністю', { skip: !existsSync(DIR) && 'немає папки з CSV практики' }, () => {
  const expect = { '01_prakt_t1.csv': 9, '02_prakt_t2.csv': 8, '03_prakt_t3.csv': 10, '04_prakt_t4.csv': 6,
    '05_prakt_t5.csv': 11, '06_prakt_t6.csv': 12, '07_prakt_final.csv': 20, '08_flashcards_glossary.csv': 30 };
  for (const f of readdirSync(DIR).filter((x) => x.endsWith('.csv'))) {
    const text = readFileSync(join(DIR, f), 'utf8');
    const r = parseCsvFile(text, f.startsWith('08_') ? parseCardRow : parseQuestionRow);
    assert.deepEqual(r.skipped, [], `${f}: пропущені рядки`);
    if (expect[f]) assert.equal(r.rows.length, expect[f], f);
  }
});
