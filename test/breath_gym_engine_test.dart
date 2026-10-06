import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';

class FakeClock implements BreathClock {
  int t = 0;
  @override
  int get nowUs => t;
  void advanceMs(num ms) => t += (ms * 1000).round();
}

Exercise ex(String id) => breathGymById[id]!;

void main() {
  group('каталог', () {
    test('17 вправ з унікальними id, блоки 1–5', () {
      expect(breathGymExercises, hasLength(17));
      expect(breathGymById, hasLength(17));
      for (final e in breathGymExercises) {
        expect(breathGymBlocks.containsKey(e.block), isTrue, reason: e.id);
        if (e.mode == ExerciseMode.guided) expect(e.groups, isNotEmpty, reason: e.id);
        expect(e.defaultBpm, inInclusiveRange(e.bpmMin, e.bpmMax), reason: e.id);
      }
    });

    test('програми посилаються лише на наявні вправи', () {
      for (final p in breathGymPrograms) {
        for (final id in p.exerciseIds) {
          expect(breathGymById.containsKey(id), isTrue, reason: '${p.id}: $id');
        }
      }
      expect(breathGymPrograms.firstWhere((p) => p.id == 'full').exerciseIds.toSet(), breathGymById.keys.toSet());
    });
  });

  group('timeline', () {
    test('розтяжка: 6 × (вдих 4, видих 4) при 60 bpm = 48 с', () {
      final t = buildTimeline(ex('stretch_breath'), ex('stretch_breath').defaults);
      expect(t, hasLength(12));
      for (var i = 0; i < 12; i++) {
        expect(t[i].type, i.isEven ? PhaseType.inhale : PhaseType.exhale);
        expect(t[i].beats, 4);
        expect(t[i].durationUs, 4000000);
        expect(t[i].repeat, i ~/ 2 + 1);
        expect(t[i].repeatsTotal, 6);
      }
      expect(t[1].hint, 'руки вниз');
      expect(t.last.endUs, 48000000);
    });

    test('налаштування повторів змінює кількість проходів', () {
      final e = ex('stretch_breath');
      expect(buildTimeline(e, e.defaults.copyWith(repeats: 2)), hasLength(4));
    });

    test('ганчір\'яна лялька: видих 4 → пауза 2 → вдих 6', () {
      final t = buildTimeline(ex('rag_doll'), ex('rag_doll').defaults);
      expect(t.take(3).map((s) => (s.type, s.beats)).toList(),
          [(PhaseType.exhale, 4), (PhaseType.hold, 2), (PhaseType.inhale, 6)]);
      expect(t, hasLength(9));
    });

    test('Стрельникова: 3 серії по 8 вдихів, між серіями 4 с', () {
      final e = ex('str_palms');
      final t = buildTimeline(e, e.defaults);
      expect(t, hasLength(3 * 8 + 2));
      final rests = t.where((s) => s.isSeriesRest).toList();
      expect(rests, hasLength(2));
      expect(rests.map((s) => s.index), [8, 17]);
      for (final r in rests) {
        expect(r.type, PhaseType.rest);
        expect(r.beats, 0);
        expect(r.durationUs, 4000000);
      }
      final inhales = t.where((s) => !s.isSeriesRest).toList();
      expect(inhales.every((s) => s.type == PhaseType.inhale && s.beats == 1), isTrue);
      expect(inhales.where((s) => s.series == 2), hasLength(8));
      // 90 bpm: доля = 2/3 с; 24 долі + 8 с відпочинку = 24 с.
      expect(t.last.endUs, 24000000);
      expect(t.first.seriesTotal, 3);
    });

    test('Стрельникова: серії налаштовуються до 12, не більше', () {
      final e = ex('str_pump');
      final t = buildTimeline(e, e.defaults.copyWith(series: 20));
      expect(t.where((s) => s.isSeriesRest), hasLength(11));
      expect(t.where((s) => s.type == PhaseType.inhale), hasLength(96));
      expect(buildTimeline(e, e.defaults.copyWith(series: 1)).where((s) => s.isSeriesRest), isEmpty);
    });

    test('«Кішка»: підказки чергуються вправо/вліво', () {
      final t = buildTimeline(ex('str_cat'), ex('str_cat').defaults).where((s) => !s.isSeriesRest).toList();
      for (var i = 0; i < t.length; i++) {
        expect(t[i].hint, i.isEven ? 'присід з поворотом вправо' : 'присід з поворотом вліво');
      }
    });

    test('bpm поза діапазоном Стрельникової обмежується 60–120', () {
      final e = ex('str_hug');
      final t = buildTimeline(e, e.defaults.copyWith(bpm: 300));
      expect(t.first.durationUs, 500000); // 120 bpm
    });

    test('Flow Studies: 4/4 → 3/5 → 2/6 → 1/7 → 1/8, кожна пара двічі, без пауз', () {
      final t = buildTimeline(ex('flow_studies'), ex('flow_studies').defaults);
      expect(t.map((s) => s.beats).toList(), [4, 4, 4, 4, 3, 5, 3, 5, 2, 6, 2, 6, 1, 7, 1, 7, 1, 8, 1, 8]);
      expect(t.every((s) => s.type == PhaseType.inhale || s.type == PhaseType.exhale), isTrue);
      for (var i = 1; i < t.length; i++) {
        expect(t[i].startUs, t[i - 1].endUs);
      }
      expect(t.where((s) => s.hint == 'так дихаємо під час гри').map((s) => s.beats), [7, 7, 8, 8]);
      expect(t.last.endUs, 82000000); // 2 × (8 + 8 + 8 + 8 + 9) долей при 60 bpm
      expect(t.last.repeat, 10);
    });

    test('«Собачка»: серія 15 с по колу, 2 серії з відпочинком 10 с', () {
      final e = ex('panting');
      final t = buildTimeline(e, e.defaults); // 140 bpm
      final first = t.takeWhile((s) => s.series == 1).toList();
      expect(first.length.isEven, isTrue);
      final dur = first.last.endUs / 1e6;
      expect(dur, closeTo(15, 0.5));
      final rest = t.firstWhere((s) => s.isSeriesRest);
      expect(rest.durationUs, 10000000);
      expect(t.where((s) => s.isSeriesRest), hasLength(1));
    });

    test('«Повітряні ноти»: вдих 1 → 7 імпульсів зі складом із налаштувань', () {
      final e = ex('air_notes');
      final t = buildTimeline(e, e.defaults.copyWith(syllable: 'ху'));
      expect(t, hasLength(8));
      expect(t[1].type, PhaseType.action);
      expect(t[1].beats, 7);
      expect(t[1].hint, 'ху');
      expect(buildTimeline(e, e.defaults)[1].hint, 'ту');
    });

    test('«Довгі ноти»: 4 рівні + 4 crescendo – diminuendo', () {
      final t = buildTimeline(ex('long_tones'), ex('long_tones').defaults);
      expect(t, hasLength(24));
      final exhales = t.where((s) => s.type == PhaseType.exhale).toList();
      expect(exhales.map((s) => s.swell), [false, false, false, false, true, true, true, true]);
      expect(t[2].type, PhaseType.rest);
      expect(t.last.repeat, 8);
    });

    test('не-GUIDED вправи не мають кроків', () {
      expect(buildTimeline(ex('hiss_exhale'), ex('hiss_exhale').defaults), isEmpty);
      expect(estimateSeconds(ex('breathing_bag')), 120);
    });

    test('при 90 bpm похибка не накопичується', () {
      final e = ex('str_palms');
      final t = buildTimeline(e, e.defaults.copyWith(series: 12));
      for (var i = 1; i < t.length; i++) {
        expect(t[i].startUs, t[i - 1].endUs);
      }
      // 96 долей по 2/3 с + 11 × 4 с.
      expect(t.last.endUs, 64000000 + 44000000);
    });
  });

  group('рушій', () {
    late FakeClock clock;
    late BreathEngine engine;
    late List<String> events;

    setUp(() {
      clock = FakeClock();
      final e = ex('stretch_breath');
      engine = BreathEngine(buildTimeline(e, e.defaults.copyWith(repeats: 2)), clock: clock);
      events = [];
      engine.onPhaseStart = (s) => events.add('phase ${s.index} ${s.type.name}');
      engine.onBeat = (s, b) => events.add('beat ${s.index}.$b');
      engine.onFinished = (done) => events.add('finished $done');
    });

    test('фази й долі за годинником', () {
      engine.start();
      expect(engine.status, EngineStatus.running);
      expect(events, ['phase 0 inhale', 'beat 0.0']);
      clock.advanceMs(999);
      engine.tick();
      expect(engine.beat, 0);
      clock.advanceMs(1);
      engine.tick();
      expect(engine.beat, 1);
      clock.advanceMs(3000);
      engine.tick();
      expect(engine.stepIndex, 1);
      expect(engine.current!.type, PhaseType.exhale);
      expect(events.sublist(2), ['beat 0.1', 'phase 1 exhale', 'beat 1.0']);
      expect(engine.usUntilNextEvent, 1000000);
    });

    test('пропущені кадри не накопичують зсув', () {
      engine.start();
      clock.advanceMs(10500); // одним стрибком у середину 3-ї фази
      engine.tick();
      expect(engine.stepIndex, 2);
      expect(engine.beat, 2);
      expect(engine.stepProgress, closeTo(0.625, 1e-9));
    });

    test('пауза заморожує час', () {
      engine.start();
      clock.advanceMs(1500);
      engine.pause();
      clock.advanceMs(60000);
      engine.tick();
      expect(engine.elapsedUs, 1500000);
      engine.resume();
      clock.advanceMs(500);
      engine.tick();
      expect(engine.elapsedUs, 2000000);
      expect(engine.beat, 2);
    });

    test('пропуск переходить на початок наступної фази', () {
      engine.start();
      clock.advanceMs(1200);
      engine.skip();
      expect(engine.stepIndex, 1);
      expect(engine.elapsedUs, 4000000);
      expect(events.last, 'beat 1.0');
    });

    test('кінець вправи і стоп', () {
      engine.start();
      clock.advanceMs(16000);
      engine.tick();
      expect(engine.status, EngineStatus.finished);
      expect(engine.completed, isTrue);
      expect(events.last, 'finished true');
      expect(engine.progress, 1.0);

      final other = BreathEngine(engine.steps, clock: clock)..start();
      other.stop();
      expect(other.status, EngineStatus.finished);
      expect(other.completed, isFalse);
    });

    test('пропуск останньої фази завершує вправу', () {
      engine.start();
      for (var i = 0; i < 4; i++) {
        engine.skip();
      }
      expect(engine.status, EngineStatus.finished);
      expect(engine.completed, isTrue);
    });

    test('Стрельникова: відпочинок між серіями без долей', () {
      final e = ex('str_palms');
      final eng = BreathEngine(buildTimeline(e, e.defaults), clock: clock);
      final beats = <int>[];
      eng.onBeat = (s, b) => beats.add(s.index);
      eng.start();
      for (var i = 0; i < 26 * 10; i++) {
        clock.advanceMs(100);
        eng.tick();
      }
      expect(eng.status, EngineStatus.finished);
      expect(beats, hasLength(24));
      expect(beats.contains(8), isFalse);
    });
  });
}
