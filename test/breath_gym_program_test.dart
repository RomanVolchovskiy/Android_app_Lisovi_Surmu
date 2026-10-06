import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/services/breath_gym_program.dart';

ProgramRun run(String id) => ProgramRun(breathGymPrograms.firstWhere((p) => p.id == id));

void main() {
  test('щоденна розминка: 1, 4, 5, 6, 10, 11, 17', () {
    final r = run('daily');
    expect(r.exercises.map((e) => e.id),
        ['stretch_breath', 'str_palms', 'str_epaulettes', 'str_pump', 'flow_studies', 'hiss_exhale', 'long_tones']);
  });

  test('повний комплекс — усі 17, «Перед виступом» — 2, 10, 12, 13, 17', () {
    expect(run('full').exercises, hasLength(17));
    expect(run('pre_performance').exercises.map((e) => e.id),
        ['rag_doll', 'flow_studies', 'panting', 'air_notes', 'long_tones']);
  });

  test('виконання, зупинка й пропуск', () {
    final r = run('pre_performance');
    r.complete(true);
    r.skip();
    r.complete(false);
    expect(r.current!.id, 'air_notes');
    expect(r.statuses.take(3), [ProgramItemStatus.done, ProgramItemStatus.skipped, ProgramItemStatus.stopped]);
    r.complete(true);
    r.complete(true);
    expect(r.finished, isTrue);
    expect(r.current, isNull);
    expect(r.count(ProgramItemStatus.done), 3);
    r.skip(); // після кінця нічого не змінює
    expect(r.count(ProgramItemStatus.skipped), 1);
  });

  test('попередження Стрельникової — один раз перед блоком II', () {
    final r = run('daily');
    expect(r.needsStrelnikovaWarning, isFalse); // розтяжка
    r.complete(true);
    expect(r.needsStrelnikovaWarning, isTrue); // «Долоньки»
    r.markStrelnikovaWarned();
    r.complete(true);
    expect(r.current!.id, 'str_epaulettes');
    expect(r.needsStrelnikovaWarning, isFalse);
  });

  test('дострокове завершення — решта пропущені', () {
    final r = run('strelnikova');
    r.complete(true);
    r.abort();
    expect(r.finished, isTrue);
    expect(r.count(ProgramItemStatus.done), 1);
    expect(r.count(ProgramItemStatus.skipped), 5);
  });

  test('тривалість програми враховує паузи між вправами', () {
    final p = breathGymPrograms.firstWhere((p) => p.id == 'strelnikova');
    // 6 вправ × 24 с + 6 × 5 с.
    expect(estimateProgramSeconds(p), 6 * 24 + 30);
  });
}
