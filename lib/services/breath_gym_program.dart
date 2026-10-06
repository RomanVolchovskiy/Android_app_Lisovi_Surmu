import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';

enum ProgramItemStatus { pending, done, stopped, skipped }

/// Проходження програми: вправи по черзі, кожну можна виконати,
/// зупинити або пропустити. Без UI — щоб тестувати.
class ProgramRun {
  ProgramRun(this.program)
      : exercises = [for (final id in program.exerciseIds) breathGymById[id]].whereType<Exercise>().toList() {
    statuses = List.filled(exercises.length, ProgramItemStatus.pending);
  }

  final Program program;
  final List<Exercise> exercises;
  late final List<ProgramItemStatus> statuses;
  int index = 0;
  bool _strelnikovaWarned = false;

  bool get finished => index >= exercises.length;
  Exercise? get current => finished ? null : exercises[index];

  /// Попередження Стрельникової — один раз, перед першою вправою блоку II.
  bool get needsStrelnikovaWarning => !_strelnikovaWarned && current?.block == 2;

  void markStrelnikovaWarned() => _strelnikovaWarned = true;

  /// Результат поточної вправи: `true` — виконано, `false` — зупинено.
  void complete(bool done) => _advance(done ? ProgramItemStatus.done : ProgramItemStatus.stopped);

  void skip() => _advance(ProgramItemStatus.skipped);

  /// Завершити програму достроково: решта — пропущені.
  void abort() {
    while (!finished) {
      skip();
    }
  }

  void _advance(ProgramItemStatus s) {
    if (finished) return;
    statuses[index] = s;
    index++;
  }

  int count(ProgramItemStatus s) => statuses.where((x) => x == s).length;
}

/// Орієнтовна тривалість програми з паузами між вправами, с.
int estimateProgramSeconds(Program p, {int transitionSec = 5}) {
  final list = [for (final id in p.exerciseIds) breathGymById[id]].whereType<Exercise>().toList();
  if (list.isEmpty) return 0;
  return list.fold<int>(0, (s, e) => s + estimateSeconds(e)) + transitionSec * list.length;
}
