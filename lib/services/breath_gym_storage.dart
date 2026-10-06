import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:hunting_signals/services/local_storage_service.dart';

/// Спроба STOPWATCH-вправи.
class BreathAttempt {
  final String exerciseId;
  final double seconds;
  final DateTime at;
  const BreathAttempt(this.exerciseId, this.seconds, this.at);

  Map<String, dynamic> toJson() => {'e': exerciseId, 's': seconds, 't': at.millisecondsSinceEpoch};

  static BreathAttempt? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = j['e'], s = j['s'], t = j['t'];
    if (e is! String || s is! num || t is! int) return null;
    return BreathAttempt(e, s.toDouble(), DateTime.fromMillisecondsSinceEpoch(t));
  }
}

/// Виконана вправа (для прогресу: тренування за тиждень, серія днів).
class BreathSessionLog {
  final String exerciseId;
  final DateTime at;
  final int seconds;
  final bool completed;
  const BreathSessionLog(this.exerciseId, this.at, this.seconds, this.completed);

  Map<String, dynamic> toJson() =>
      {'e': exerciseId, 't': at.millisecondsSinceEpoch, 's': seconds, 'c': completed};

  static BreathSessionLog? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = j['e'], t = j['t'], s = j['s'], c = j['c'];
    if (e is! String || t is! int) return null;
    return BreathSessionLog(e, DateTime.fromMillisecondsSinceEpoch(t), s is int ? s : 0, c == true);
  }
}

/// Найкращий результат серед спроб вправи (0 — спроб немає).
double bestOf(Iterable<BreathAttempt> attempts) =>
    attempts.fold(0.0, (best, a) => a.seconds > best ? a.seconds : best);

/// Локальна історія тренажера в окремій Hive-скриньці. Нічого не
/// надсилається на сервер.
class BreathGymStorage {
  static const _boxName = 'breath_gym';
  static const _attemptsKey = 'attempts';
  static const _sessionsKey = 'sessions';
  static const _maxSessions = 2000;

  static Future<Box>? _box;

  static Future<Box> _open() => _box ??= () async {
        await LocalStorageService.initialize(); // Hive.initFlutter
        return Hive.openBox(_boxName);
      }();

  static Future<List<T>> _read<T>(String key, T? Function(Object?) parse) async {
    try {
      final raw = (await _open()).get(key);
      if (raw is! List) return [];
      return raw.map(parse).whereType<T>().toList();
    } catch (e) {
      debugPrint('BreathGymStorage: $e');
      return [];
    }
  }

  /// Спроби вправи, найновіші першими.
  static Future<List<BreathAttempt>> attempts(String exerciseId) async =>
      (await _read(_attemptsKey, BreathAttempt.fromJson)).where((a) => a.exerciseId == exerciseId).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  static Future<List<BreathAttempt>> allAttempts() => _read(_attemptsKey, BreathAttempt.fromJson);

  static Future<double> record(String exerciseId) async => bestOf(await attempts(exerciseId));

  /// Зберігає спробу; повертає попередній рекорд (0 — перша спроба).
  static Future<double> addAttempt(BreathAttempt a) async {
    final box = await _open();
    final all = await _read(_attemptsKey, BreathAttempt.fromJson);
    final prev = bestOf(all.where((x) => x.exerciseId == a.exerciseId));
    await box.put(_attemptsKey, [...all.map((x) => x.toJson()), a.toJson()]);
    return prev;
  }

  static Future<List<BreathSessionLog>> sessions() => _read(_sessionsKey, BreathSessionLog.fromJson);

  static Future<void> addSession(BreathSessionLog s) async {
    try {
      final box = await _open();
      final all = await sessions();
      final keep = all.length >= _maxSessions ? all.sublist(all.length - _maxSessions + 1) : all;
      await box.put(_sessionsKey, [...keep.map((x) => x.toJson()), s.toJson()]);
    } catch (e) {
      debugPrint('BreathGymStorage: $e');
    }
  }
}
