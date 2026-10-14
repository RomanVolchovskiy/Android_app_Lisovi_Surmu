// Дзеркало scripts/site_tests/practice_core.test.mjs — логіка має збігатися з сайтом.
import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/services/practice_core.dart';

void main() {
  PracticeStep s(String id) => practiceStepById[id]!;

  test('сума максимальних балів = 100 (60 поточних + 40 залік)', () {
    expect(maxCurrent, 60);
    expect(maxExam, 40);
    expect(allPracticeSteps.where((s) => s.group == 'pr').length, 4);
    expect(allPracticeSteps.where((s) => s.group == 'sr').length, 4);
  });

  test('id кроків унікальні, кроків 36 — як на сайті', () {
    expect(allPracticeSteps.map((s) => s.id).toSet().length, allPracticeSteps.length);
    expect(allPracticeSteps.length, 36);
    expect(practiceStages.length, 7);
  });

  test('submit: не виконано → на перевірці → оцінено', () {
    final step = s('d1_sr');
    expect(stepStatus(step, {}, {}).state, PracticeState.todo);
    final work = {
      'steps': {'d1_sr': {'done': true, 'files': [{'name': 'a.jpg'}]}},
    };
    final r = stepStatus(step, work, {});
    expect(r.state, PracticeState.review);
    expect(r.label, contains('На перевірці: максимальна кількість балів за завдання 6 балів'));
    final g = stepStatus(step, work, {'d1_sr': {'points': 5, 'status': 'graded'}});
    expect(g.state, PracticeState.graded);
    expect(g.points, 5);
    expect(g.label, contains('5 з 6'));
  });

  test('submit: на доопрацювання, після повторної здачі — знову на перевірці', () {
    final grades = {'d2_sr': {'status': 'revise', 'comment': 'мало', 'gradedAt': 1000}};
    expect(stepStatus(s('d2_sr'), {'steps': {'d2_sr': {'done': true, 'submittedAt': 500}}}, grades).state, PracticeState.revise);
    expect(stepStatus(s('d2_sr'), {'steps': {'d2_sr': {'done': true, 'submittedAt': 2000}}}, grades).state, PracticeState.review);
  });

  test('quiz і retest рахуються з quiz_results', () {
    final qr = [
      {'kind': 'theory', 'topicName': 'Практика. Тема 2. Мисливський ріжок', 'correct': 7, 'total': 10, 'percent': 70},
      {'kind': 'theory', 'topicName': 'Практика. Тема 3. Музична грамота', 'correct': 9, 'total': 10, 'percent': 90},
      {'kind': 'theory', 'topicName': 'Практика. Тема 2. Мисливський ріжок', 'correct': 9, 'total': 10, 'percent': 90},
      {'kind': 'audio', 'topicName': 'сигнали практики', 'correct': 5, 'total': 6, 'percent': 83},
    ];
    final ctx = PracticeCtx(quizResults: qr);
    expect(bestByTopic(qr), {2: 90, 3: 90});
    expect(stepStatus(s('d2_quiz'), {}, {}, ctx).state, PracticeState.done);
    expect(stepStatus(s('d1_quiz'), {}, {}, ctx).state, PracticeState.todo);
    expect(stepStatus(s('w_retest'), {}, {}, ctx).state, PracticeState.todo);
    expect(stepStatus(s('d3_audio'), {}, {}, ctx).label, 'Спроб: 1 з 3');
    expect(topicNumber('Підсумковий тест'), isNull);
  });

  test('щоденник, дихання, сигнали', () {
    expect(stepStatus(s('d1_diary'), {'diary': {'d1': {'aud': 'x', 'self': 'y', 'concl': ''}}}, {}).state, PracticeState.todo);
    expect(stepStatus(s('d1_diary'), {'diary': {'d1': {'aud': 'x', 'self': 'y', 'concl': 'z'}}}, {}).state, PracticeState.review);
    final breath = {for (final d in breathDates) d: {'ex': [true, false, false, false], 'sec': 20}};
    expect(stepStatus(s('d2_breath'), {'breath': breath}, {}).state, PracticeState.review);
    breath.remove('03.10');
    expect(stepStatus(s('d2_breath'), {'breath': breath}, {}).label, contains('4 з 5'));
    final signals = {for (final x in trackedSignals) x: {'know': true}};
    expect(stepStatus(s('d3_signals'), {'signals': signals}, {}).state, PracticeState.review);
  });

  test('іспит: автоматичні бали, правка викладача має перевагу', () {
    final exam = bestExam([
      {'sessionId': 'S1', 'uid': 'u', 'status': 'submitted', 'theory': {'points': 15}, 'audio': {'points': 4}},
      {'sessionId': 'S2', 'uid': 'u', 'status': 'in_progress', 'theory': {'points': 20}},
    ], [
      {'id': 'S1_u', 'adminTheoryPoints': 17},
    ]);
    expect(exam?.theory, 17);
    expect(exam?.audio, 4);
    expect(stepStatus(s('e_theory'), {}, {}, PracticeCtx(exam: exam)).points, 17);
    expect(stepStatus(s('e_theory'), {}, {'e_theory': {'points': 19}}, PracticeCtx(exam: exam)).points, 19);
    expect(stepStatus(s('e_signal'), {}, {}).state, PracticeState.teacher);
  });

  test('підсумок, допуск і оцінка', () {
    final grades = <String, dynamic>{
      for (final id in ['d1_pr', 'd2_pr', 'd3_pr', 'd4_pr', 'd1_sr', 'd2_sr', 'd3_sr', 'd4_sr']) id: {'points': 5},
      'w_report': {'points': 10},
      'e_signal': {'points': 7},
      'e_rhythm': {'points': 5},
    };
    final t = practiceTotals({}, grades, const PracticeCtx(exam: (theory: 18, audio: 5)));
    expect(t.current, 50);
    expect(t.exam, 35);
    expect(t.total, 85);
    expect(t.admitted, isTrue);
    expect(t.grade.ects, 'B');
    expect(ectsGrade(60).ects, 'E');
    expect(ectsGrade(34).ects, 'F');
    expect(nextPracticeStep({}, {})?.id, 'prep_profile');
  });

  test('аудіобал іспиту з дробом (правильних × 0,6)', () {
    final st = stepStatus(s('e_audio'), {}, {}, const PracticeCtx(exam: (theory: null, audio: 4.8)));
    expect(st.points, 4.8);
    expect(st.label, 'Автоматично: 4.8 з 6 балів');
  });

  test('check: відмітка студента → очікування підтвердження → підтверджено / не підтверджено', () {
    final step = s('d1_safety');
    expect(stepStatus(step, {}, {}).state, PracticeState.todo);
    final work = {'steps': {'d1_safety': {'done': true, 'doneAt': 500}}};
    final r = stepStatus(step, work, {});
    expect(r.state, PracticeState.review);
    expect(r.label, 'Очікування на підтвердження');
    expect(stepStatus(step, work, {'d1_safety': {'points': 0, 'status': 'graded'}}).label, 'Виконано · Підтверджено');
    final no = {'d1_safety': {'points': null, 'status': 'revise', 'gradedAt': 1000}};
    expect(stepStatus(step, work, no).state, PracticeState.revise);
    expect(stepStatus(step, {'steps': {'d1_safety': {'done': true, 'doneAt': 2000}}}, no).state, PracticeState.review);
    expect(practiceTotals(work, {}).review, 1);
  });

  test('скинута оцінка (status none, points null) не рахується як 0 балів', () {
    final st = stepStatus(s('d1_pr'), {'steps': {'d1_pr': {'done': true}}}, {'d1_pr': {'points': null, 'status': 'none'}});
    expect(st.state, PracticeState.review);
    expect(st.points, isNull);
    expect(stepStatus(s('e_signal'), {}, {'e_signal': {'points': null, 'status': 'none'}}).state, PracticeState.teacher);
  });

  test('щоденник і таблиці: підтвердження викладача, «не підтверджено» → виправлено → знову очікує', () {
    final step = s('d2_diary');
    final full = {'aud': 'a', 'self': 'b', 'concl': 'c'};
    final work = {'diary': {'d2': full}, 'steps': {'d2_diary': {'submittedAt': 500}}};
    expect(stepStatus(step, work, {}).label, 'Очікування на підтвердження');
    expect(stepStatus(step, work, {'d2_diary': {'points': 0, 'status': 'graded'}}).label, 'Виконано · Підтверджено');
    final no = {'d2_diary': {'points': null, 'status': 'revise', 'gradedAt': 1000, 'comment': 'мало'}};
    expect(stepStatus(step, work, no).state, PracticeState.revise);
    expect(stepStatus(step, {...work, 'steps': {'d2_diary': {'submittedAt': 2000}}}, no).state, PracticeState.review);
    expect(stepStatus(step, {'diary': {'d2': {'aud': 'a'}}}, {}).state, PracticeState.todo);
    expect(stepStatus(s('prep_profile'), {}, {}, const PracticeCtx(fullName: 'a', group: 'b')).state, PracticeState.done);
  });
}
