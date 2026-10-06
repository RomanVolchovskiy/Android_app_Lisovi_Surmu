import 'package:flutter/services.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/horn_synth.dart';

/// Звук і вібрація дихального тренажера поверх наявного [HornSynth]
/// (SoundPool через PlayerMode.lowLatency).
///
/// Перша доля фази: вдих — нота МІ2, видих — ДО, пауза й імпульс —
/// акцентний клік. Інші долі — звичайний клік; REST усередині проходу —
/// тихий; відпочинок між серіями — без звуку.
class BreathGymSound {
  static const _inhaleNote = 3; // МІ2
  static const _exhaleNote = 0; // ДО

  final _synth = HornSynth();
  bool metronome = true;
  bool vibration = true;

  Future<void> ensureReady() => Future.wait([_synth.ensureReady(), _synth.ensureClicksReady()]);

  void phaseStarted(BreathStep step) {
    if (vibration) HapticFeedback.mediumImpact();
  }

  void beat(BreathStep step, int beat) {
    if (!metronome || step.isSeriesRest) return;
    if (beat == 0) {
      switch (step.type) {
        case PhaseType.inhale:
          _synth.play(_inhaleNote, volume: 0.8);
        case PhaseType.exhale:
          _synth.play(_exhaleNote, volume: 0.8);
        case PhaseType.hold || PhaseType.action:
          _synth.click(HornSynth.clickAccent);
        case PhaseType.rest:
          _synth.click(HornSynth.clickSub);
      }
      return;
    }
    _synth.click(step.type == PhaseType.rest ? HornSynth.clickSub : HornSynth.clickBeat,
        volume: step.type == PhaseType.action ? 1.0 : 0.7);
  }

  /// Сигнал початку вдиху чи видиху (секундомір) з вібрацією.
  void cue(PhaseType type) {
    if (vibration) HapticFeedback.mediumImpact();
    if (!metronome) return;
    switch (type) {
      case PhaseType.inhale:
        _synth.play(_inhaleNote, volume: 0.8);
      case PhaseType.exhale:
        _synth.play(_exhaleNote, volume: 0.8);
      default:
        _synth.click(HornSynth.clickAccent);
    }
  }

  /// Кінець таймера.
  void timeUp() {
    if (vibration) HapticFeedback.heavyImpact();
    if (metronome) _synth.play(4); // СОЛЬ2
  }

  /// Відлік перед стартом.
  void countdown(bool last) {
    if (metronome) _synth.click(last ? HornSynth.clickAccent : HornSynth.clickBeat);
  }

  Future<void> dispose() => _synth.dispose();
}
