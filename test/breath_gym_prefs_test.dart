import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/breath_gym_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('налаштування вправи', () {
    test('JSON туди-назад', () {
      final ex = breathGymById['air_notes']!;
      final s = ex.defaults.copyWith(bpm: 95, repeats: 6, syllable: 'ху');
      final back = ExerciseSettings.fromJson(s.toJson(), ex);
      expect((back.bpm, back.series, back.repeats, back.syllable), (95, 1, 6, 'ху'));
    });

    test('поза діапазоном — обмежується; биті поля — значення вправи', () {
      final ex = breathGymById['str_palms']!;
      final s = ExerciseSettings.fromJson({'bpm': 500, 'series': 40, 'repeats': 9, 'syllable': 7}, ex);
      expect(s.bpm, 120);
      expect(s.series, 12);
      expect(s.repeats, isNull); // у Стрельниковій повтори не налаштовуються
      expect(s.syllable, 'ту');
      expect(ExerciseSettings.fromJson('сміття', ex).bpm, ex.defaultBpm);
    });
  });

  group('загальні налаштування', () {
    test('за замовчуванням і биті значення', () {
      final d = BreathGymSettings.fromJson(null);
      expect((d.metronome, d.volume, d.vibration, d.voice), (true, 0.8, true, false));
      final s = BreathGymSettings.fromJson({'metronome': false, 'volume': 3, 'vibration': 'так', 'voice': true});
      expect((s.metronome, s.volume, s.vibration, s.voice), (false, 1.0, true, true));
    });
  });

  group('збереження', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('налаштування вправи зберігаються й діють у таймлайні', () async {
      final ex = breathGymById['stretch_breath']!;
      expect((await BreathGymPrefs.exercise(ex)).repeats, isNull);
      await BreathGymPrefs.saveExercise(ex, ex.defaults.copyWith(repeats: 2, bpm: 80));
      final s = await BreathGymPrefs.exercise(ex);
      expect(buildTimeline(ex, s), hasLength(4));
      expect(s.bpm, 80);
    });

    test('скидання повертає всі вправи до стандартних', () async {
      final a = breathGymById['stretch_breath']!, b = breathGymById['str_pump']!;
      await BreathGymPrefs.saveExercise(a, a.defaults.copyWith(repeats: 2));
      await BreathGymPrefs.saveExercise(b, b.defaults.copyWith(series: 7));
      await BreathGymPrefs.resetExercises();
      expect((await BreathGymPrefs.exercise(a)).repeats, isNull);
      expect((await BreathGymPrefs.exercise(b)).series, 3);
    });
  });
}
