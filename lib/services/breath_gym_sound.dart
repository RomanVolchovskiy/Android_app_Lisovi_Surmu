import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/models/breath_gym_models.dart';
import 'package:hunting_signals/services/breath_gym_engine.dart';
import 'package:hunting_signals/services/breath_gym_prefs.dart';
import 'package:hunting_signals/services/horn_synth.dart';

/// Голосові підказки українською через системний синтезатор мовлення.
/// Немає українського голосу — [available] повертає false і підказки
/// вимикаються.
class BreathGymVoice {
  static const _lang = 'uk-UA';
  static final _tts = FlutterTts();
  static Future<bool>? _available;

  static Future<bool> available() => _available ??= _init();

  static Future<bool> _init() async {
    if (kIsWeb) return false;
    try {
      if (await _tts.isLanguageAvailable(_lang) != true) return false;
      await _tts.setLanguage(_lang);
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      return true;
    } catch (e) {
      debugPrint('BreathGymVoice: $e');
      return false;
    }
  }

  static Future<void> say(String text) async {
    if (!await available()) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('BreathGymVoice: $e');
    }
  }

  static Future<void> stop() async {
    if (_available == null) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Звук і вібрація тренажера поверх наявного [HornSynth] (SoundPool через
/// PlayerMode.lowLatency). Налаштування — [BreathGymPrefs.settings].
///
/// Перша доля фази: вдих — нота МІ2, видих — ДО, пауза й імпульс —
/// акцентний клік. Інші долі — звичайний клік; REST усередині проходу —
/// тихий; відпочинок між серіями — без звуку. З голосом тон першої долі
/// замінює назва фази (якщо фаза достатньо довга, щоб її вимовити).
class BreathGymSound {
  static const _inhaleNote = 3; // МІ2
  static const _exhaleNote = 0; // ДО

  /// Коротші фази не озвучуються — голос не встигне.
  static const _minSpokenUs = 1500000;

  final _synth = HornSynth();

  BreathGymSettings get _s => BreathGymPrefs.settings.value;

  Future<void> ensureReady() async {
    await BreathGymPrefs.load();
    if (_s.voice) BreathGymVoice.available();
    await Future.wait([_synth.ensureReady(), _synth.ensureClicksReady()]);
  }

  bool _speaks(BreathStep step) => _s.voice && step.durationUs >= _minSpokenUs;

  void phaseStarted(BreathStep step) {
    if (_s.vibration) HapticFeedback.mediumImpact();
    if (_speaks(step)) BreathGymVoice.say(BgStrings.phaseSpoken(step.type));
  }

  void beat(BreathStep step, int beat) {
    if (!_s.metronome || step.isSeriesRest) return;
    final v = _s.volume;
    if (beat == 0) {
      if (_speaks(step)) return;
      switch (step.type) {
        case PhaseType.inhale:
          _synth.play(_inhaleNote, volume: 0.8 * v);
        case PhaseType.exhale:
          _synth.play(_exhaleNote, volume: 0.8 * v);
        case PhaseType.hold || PhaseType.action:
          _synth.click(HornSynth.clickAccent, volume: v);
        case PhaseType.rest:
          _synth.click(HornSynth.clickSub, volume: v);
      }
      return;
    }
    _synth.click(
      step.type == PhaseType.rest ? HornSynth.clickSub : HornSynth.clickBeat,
      volume: (step.type == PhaseType.action ? 1.0 : 0.7) * v,
    );
  }

  /// Сигнал початку вдиху чи видиху (секундомір) з вібрацією.
  void cue(PhaseType type) {
    if (_s.vibration) HapticFeedback.mediumImpact();
    if (_s.voice) {
      BreathGymVoice.say(BgStrings.phaseSpoken(type));
      return;
    }
    if (!_s.metronome) return;
    switch (type) {
      case PhaseType.inhale:
        _synth.play(_inhaleNote, volume: 0.8 * _s.volume);
      case PhaseType.exhale:
        _synth.play(_exhaleNote, volume: 0.8 * _s.volume);
      default:
        _synth.click(HornSynth.clickAccent, volume: _s.volume);
    }
  }

  /// Кінець таймера.
  void timeUp() {
    if (_s.vibration) HapticFeedback.heavyImpact();
    if (_s.voice) BreathGymVoice.say(BgStrings.timeUp);
    if (_s.metronome) _synth.play(4, volume: _s.volume); // СОЛЬ2
  }

  /// Відлік перед стартом.
  void countdown(bool last) {
    if (_s.metronome) _synth.click(last ? HornSynth.clickAccent : HornSynth.clickBeat, volume: _s.volume);
  }

  Future<void> dispose() async {
    await BreathGymVoice.stop();
    await _synth.dispose();
  }
}
