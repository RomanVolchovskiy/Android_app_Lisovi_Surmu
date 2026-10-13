import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart' show nextSortOrder;
import 'package:hunting_signals/utils/csv_import.dart';

void main() {
  group('parseCsvLine', () {
    test('коми в лапках і подвоєні лапки', () {
      expect(parseCsvLine('a,"b, c","d ""e"""'), ['a', 'b, c', 'd "e"']);
    });
    test('поля без лапок — як раніше', () {
      expect(parseCsvLine('a,b,,c'), ['a', 'b', '', 'c']);
    });
  });

  group('csvLines', () {
    test('BOM, заголовок, порожні рядки й номери', () {
      final l = csvLines('\uFEFFПитання,Відповідь\r\n\r\nx,y\nz,w\n');
      expect(l.map((x) => x.n), [3, 4]);
      expect(l.first.line, 'x,y');
    });
  });

  group('parseQuestionRow', () {
    test('правильний рядок з поясненням, що містить коми', () {
      final r = parseQuestionRow('Q,a,b,c,d,2,пояснення, з комою').row!;
      expect(r.options, ['a', 'b', 'c', 'd']);
      expect(r.correctIndex, 2);
      expect(r.explanation, 'пояснення, з комою');
    });
    test('помилки', () {
      expect(parseQuestionRow('Q,a,b,c,d').error, 'менше 6 полів');
      expect(parseQuestionRow('Q,a,,c,d,1').error, 'порожній варіант');
      expect(parseQuestionRow('Q,a,b,c,d,4').error, contains('не 0–3'));
      expect(parseQuestionRow(',a,b,c,d,1').error, 'порожнє питання');
    });
  });

  test('parseCardRow: відповідь без лапок з комами', () {
    final r = parseCardRow('Загін,Спосіб полювання, під час якого').row!;
    expect(r.question, 'Загін');
    expect(r.answer, 'Спосіб полювання, під час якого');
    expect(parseCardRow('лише питання').error, isNotNull);
  });

  test('importId і порядок з урахуванням чисел', () {
    expect(importId('tq', 5, 7), 'tq_5_007');
    final ids = ['tq_1_10', 'tq_1_2', 'tq_1_1'];
    ids.sort(compareNatural);
    expect(ids, ['tq_1_1', 'tq_1_2', 'tq_1_10']);
    expect(compareBySortOrder(1, 'b', 0, 'a') > 0, isTrue);
    expect(compareBySortOrder(null, 'x_2', null, 'x_10') < 0, isTrue);
  });

  test('nextSortOrder — у кінець списку', () {
    expect(nextSortOrder([]), 0);
    expect(nextSortOrder([null, null]), 2);
    expect(nextSortOrder([0, 7, null]), 8);
  });

  test('EducationTopic: hidden і testTopicIds переживають toJson/fromJson', () {
    final t = EducationTopic.fromJson({'id': 'p1', 'name': 'День 1', 'hidden': true, 'testTopicIds': ['t1', 't2'], 'sortOrder': 3});
    expect(t.hidden, isTrue);
    expect(t.testTopicIds, ['t1', 't2']);
    final back = EducationTopic.fromJson(t.copyWith(name: 'День 1а').toJson());
    expect(back.name, 'День 1а');
    expect(back.sortOrder, 3);
    expect(back.hidden, isTrue);
    expect(back.testTopicIds, ['t1', 't2']);
    expect(EducationTopic.fromJson({'id': 'x'}).hidden, isFalse);
  });

  // Реальні CSV практики (ТЗ): усі рядки мають розпізнаватися.
  final dir = Directory(r'D:\HuntingSignals\practice_docs\docs\practice\tests');
  test('реальні CSV практики', () {
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.csv')).toList()..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);
    for (final f in files) {
      final text = f.readAsStringSync();
      final cards = f.uri.pathSegments.last.startsWith('08');
      final parsed = cards ? parseCsvFile(text, parseCardRow) : parseCsvFile(text, parseQuestionRow);
      expect(parsed.skipped.map((s) => '${s.n}: ${s.error}'), isEmpty, reason: f.path);
      expect(parsed.rows, isNotEmpty, reason: f.path);
    }
  }, skip: dir.existsSync() ? false : 'немає папки з CSV практики');
}
