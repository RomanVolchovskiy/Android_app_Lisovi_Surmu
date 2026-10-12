// Розбір CSV для імпорту питань тестів і флеш-карток (адмінка навчання).
// Чисті функції без DOM — тести: scripts/site_tests/csv_import.test.mjs.

/**
 * Рядок CSV з комою-роздільником (RFC 4180): поле в лапках "…" може містити
 * коми, а "" усередині — це лапка (так зберігає Excel). Поля без лапок — як
 * раніше, тож старі файли імпортуються так само.
 */
export function parseCsvLine(line) {
  const out = [];
  let cur = '', quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quoted) {
      if (c === '"' && line[i + 1] === '"') { cur += '"'; i++; } else if (c === '"') quoted = false; else cur += c;
    } else if (c === '"' && !cur.trim()) { quoted = true; cur = ''; } else if (c === ',') { out.push(cur); cur = ''; } else cur += c;
  }
  out.push(cur);
  return out;
}

const HEADER = new Set(['питання', 'question']);

/**
 * Непорожні рядки файлу з номерами (з 1, як у редакторі): без BOM і без
 * рядка заголовка (перше поле «питання» або «question»).
 */
export function csvLines(text) {
  const lines = String(text ?? '').replace(/^﻿/, '').split(/\r?\n/)
    .map((line, i) => ({ n: i + 1, line: line.trim() }))
    .filter((x) => x.line);
  if (lines.length && HEADER.has(parseCsvLine(lines[0].line)[0].trim().toLowerCase())) lines.shift();
  return lines;
}

/** Рядок тесту: питання,варіант1..4,правильний(0-3)[,пояснення] → { row } або { error }. */
export function parseQuestionRow(line) {
  const p = parseCsvLine(line);
  if (p.length < 6) return { error: 'менше 6 полів' };
  const question = p[0].trim();
  const options = p.slice(1, 5).map((o) => o.trim());
  if (!question) return { error: 'порожнє питання' };
  if (options.some((o) => !o)) return { error: 'порожній варіант' };
  const idx = p[5].trim();
  if (!/^[0-3]$/.test(idx)) return { error: `правильний «${idx}» не 0–3` };
  const explanation = p.length > 6 ? p.slice(6).join(',').trim() || null : null;
  return { row: { question, options, correctIndex: Number(idx), explanation } };
}

/** Рядок картки: питання,відповідь — відповідь без лапок може містити коми. */
export function parseCardRow(line) {
  const [first, ...rest] = parseCsvLine(line);
  const question = (first ?? '').trim();
  const answer = rest.join(',').trim();
  if (!question || !answer) return { error: 'немає питання або відповіді' };
  return { row: { question, answer } };
}

/** Увесь файл: { rows, skipped: [{ n, error }] }. */
export function parseCsvFile(text, parseRow) {
  const rows = [];
  const skipped = [];
  for (const { n, line } of csvLines(text)) {
    const r = parseRow(line);
    if (r.row) rows.push(r.row); else skipped.push({ n, error: r.error });
  }
  return { rows, skipped };
}

/** id з доповненням нулями: лексикографічний порядок збігається з порядком рядків. */
export const importId = (prefix, ts, i) => `${prefix}_${ts}_${String(i).padStart(3, '0')}`;

/** Порядок елементів навчання: sortOrder/order, далі id з урахуванням чисел (tq_…_2 < tq_…_10). */
export function bySortOrder(a, b) {
  return ((a.sortOrder ?? a.order ?? 0) - (b.sortOrder ?? b.order ?? 0))
    || String(a.id ?? a._doc ?? '').localeCompare(String(b.id ?? b._doc ?? ''), 'en', { numeric: true });
}
