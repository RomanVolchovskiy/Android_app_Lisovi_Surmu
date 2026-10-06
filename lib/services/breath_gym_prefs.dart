import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hunting_signals/models/breath_gym_models.dart';

/// Загальні налаштування тренажера.
@immutable
class BreathGymSettings {
  final bool metronome;
  final double volume;
  final bool vibration;
  final bool voice;

  const BreathGymSettings({this.metronome = true, this.volume = 0.8, this.vibration = true, this.voice = false});

  BreathGymSettings copyWith({bool? metronome, double? volume, bool? vibration, bool? voice}) => BreathGymSettings(
    metronome: metronome ?? this.metronome,
    volume: volume ?? this.volume,
    vibration: vibration ?? this.vibration,
    voice: voice ?? this.voice,
  );

  Map<String, dynamic> toJson() => {'metronome': metronome, 'volume': volume, 'vibration': vibration, 'voice': voice};

  factory BreathGymSettings.fromJson(Object? j) {
    const d = BreathGymSettings();
    if (j is! Map) return d;
    final v = j['volume'];
    return BreathGymSettings(
      metronome: j['metronome'] is bool ? j['metronome'] as bool : d.metronome,
      volume: v is num ? v.toDouble().clamp(0.0, 1.0) : d.volume,
      vibration: j['vibration'] is bool ? j['vibration'] as bool : d.vibration,
      voice: j['voice'] is bool ? j['voice'] as bool : d.voice,
    );
  }
}

/// Налаштування в SharedPreferences (як решта застосунку): загальні й
/// окремо для кожної вправи (темп, серії, повтори, склад).
class BreathGymPrefs {
  static const _settingsKey = 'breath_gym_settings';
  static const _exercisePrefix = 'breath_gym_ex_';

  /// Поточні загальні налаштування — екрани слухають зміни.
  static final settings = ValueNotifier(const BreathGymSettings());
  static Future<void>? _loaded;

  static Future<void> load() => _loaded ??= () async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_settingsKey);
      if (raw != null) settings.value = BreathGymSettings.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('BreathGymPrefs: $e');
    }
  }();

  static Future<void> save(BreathGymSettings s) async {
    settings.value = s;
    await (await SharedPreferences.getInstance()).setString(_settingsKey, jsonEncode(s.toJson()));
  }

  static Future<ExerciseSettings> exercise(Exercise ex) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString('$_exercisePrefix${ex.id}');
      return raw == null ? ex.defaults : ExerciseSettings.fromJson(jsonDecode(raw), ex);
    } catch (e) {
      debugPrint('BreathGymPrefs: $e');
      return ex.defaults;
    }
  }

  static Future<void> saveExercise(Exercise ex, ExerciseSettings s) async =>
      (await SharedPreferences.getInstance()).setString('$_exercisePrefix${ex.id}', jsonEncode(s.toJson()));

  /// Повертає всі вправи до значень за замовчуванням.
  static Future<void> resetExercises() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_exercisePrefix)).toList()) {
      await prefs.remove(k);
    }
  }
}
