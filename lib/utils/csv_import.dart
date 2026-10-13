// Розбір CSV для імпорту питань тестів і флеш-карток (адмінка навчання).
// Та сама логіка, що в site/js/csv-import.js; тести — test/csv_import_test.dart.

/// Рядок CSV з комою-роздільником (RFC 4180): поле в лапках "…" може містити
/// коми, а "" усередині — це лапка (так зберігає Excel).
List<String> parseCsvLine(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quoted) {
      if (c == '"' && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        cur.write(c);
      }
    } else if (c == '"' && cur.toString().trim().isEmpty) {
      quoted = true;
      cur.clear();
    } else if (c == ',') {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString());
  return out;
}

class CsvLine {
  final int n; // номер рядка з 1, як у редакторі
  final String line;
  const CsvLine(this.n, this.line);
}

const _header = {'питання', 'question'};

/// Непорожні рядки файлу без BOM і без рядка заголовка.
List<CsvLine> csvLines(String text) {
  final lines = <CsvLine>[];
  final raw = text.replaceFirst(RegExp('^﻿'), '').split(RegExp(r'\r?\n'));
  for (var i = 0; i < raw.length; i++) {
    final l = raw[i].trim();
    if (l.isNotEmpty) lines.add(CsvLine(i + 1, l));
  }
  if (lines.isNotEmpty && _header.contains(parseCsvLine(lines.first.line).first.trim().toLowerCase())) {
    lines.removeAt(0);
  }
  return lines;
}

class QuestionRow {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  const QuestionRow(this.question, this.options, this.correctIndex, this.explanation);
}

class CardRow {
  final String question;
  final String answer;
  const CardRow(this.question, this.answer);
}

/// Результат розбору рядка: або [row], або [error].
class RowResult<T> {
  final T? row;
  final String? error;
  const RowResult.ok(T this.row) : error = null;
  const RowResult.fail(String this.error) : row = null;
}

/// питання,варіант1..4,правильний(0-3)[,пояснення]
RowResult<QuestionRow> parseQuestionRow(String line) {
  final p = parseCsvLine(line);
  if (p.length < 6) return const RowResult.fail('менше 6 полів');
  final question = p[0].trim();
  final options = p.sublist(1, 5).map((o) => o.trim()).toList();
  if (question.isEmpty) return const RowResult.fail('порожнє питання');
  if (options.any((o) => o.isEmpty)) return const RowResult.fail('порожній варіант');
  final idx = p[5].trim();
  if (!RegExp(r'^[0-3]$').hasMatch(idx)) return RowResult.fail('правильний «$idx» не 0–3');
  final exp = p.length > 6 ? p.sublist(6).join(',').trim() : '';
  return RowResult.ok(QuestionRow(question, options, int.parse(idx), exp.isEmpty ? null : exp));
}

/// питання,відповідь — відповідь без лапок може містити коми.
RowResult<CardRow> parseCardRow(String line) {
  final p = parseCsvLine(line);
  final question = p.first.trim();
  final answer = p.skip(1).join(',').trim();
  if (question.isEmpty || answer.isEmpty) return const RowResult.fail('немає питання або відповіді');
  return RowResult.ok(CardRow(question, answer));
}

class CsvSkip {
  final int n;
  final String error;
  const CsvSkip(this.n, this.error);
}

class CsvParsed<T> {
  final List<T> rows;
  final List<CsvSkip> skipped;
  const CsvParsed(this.rows, this.skipped);
}

CsvParsed<T> parseCsvFile<T>(String text, RowResult<T> Function(String) parseRow) {
  final rows = <T>[];
  final skipped = <CsvSkip>[];
  for (final l in csvLines(text)) {
    final r = parseRow(l.line);
    if (r.row != null) {
      rows.add(r.row as T);
    } else {
      skipped.add(CsvSkip(l.n, r.error!));
    }
  }
  return CsvParsed(rows, skipped);
}

/// id з доповненням нулями: лексикографічний порядок збігається з порядком рядків.
String importId(String prefix, int ts, int i) => '${prefix}_${ts}_${i.toString().padLeft(3, '0')}';
