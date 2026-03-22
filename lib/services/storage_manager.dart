import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'local_storage_service.dart';

enum StorageType { local, googleDrive, firebase }

class StorageManager {
  static StorageType _currentStorage = StorageType.firebase;

  static Future<bool> initialize({
    StorageType storageType = StorageType.firebase,
  }) async {
    try {
      _currentStorage = storageType;
      await LocalStorageService.initialize();
      return true;
    } catch (e) {
      debugPrint('StorageManager init error: $e');
      return false;
    }
  }

  static Future<void> setStorageType(StorageType type) async {
    _currentStorage = type;
  }

  static StorageType get currentStorage => _currentStorage;

  // ── LOAD ───────────────────────────────────────────────────────────
  // Спочатку з Firebase, потім локальний кеш як резервний варіант

  static Future<List<Map<String, dynamic>>?> loadHuntingSignals() async {
    if (_currentStorage == StorageType.firebase) {
      try {
        final data = await FirebaseService.loadSignals();
        if (data != null && data.isNotEmpty) {
          await LocalStorageService.saveHuntingSignals(data);
          return data;
        }
      } catch (e) {
        debugPrint('Firebase load signals failed, using local cache: $e');
      }
    }
    return await LocalStorageService.loadHuntingSignals();
  }

  static Future<List<Map<String, dynamic>>?> loadEducationalMaterials() async {
    if (_currentStorage == StorageType.firebase) {
      try {
        final data = await FirebaseService.loadMaterials();
        if (data != null && data.isNotEmpty) {
          await LocalStorageService.saveEducationalMaterials(data);
          return data;
        }
      } catch (e) {
        debugPrint('Firebase load materials failed, using local cache: $e');
      }
    }
    return await LocalStorageService.loadEducationalMaterials();
  }

  // ── SAVE (тільки локальний кеш — для першого завантаження) ─────────
  // Firebase оновлюється через upsertSignal / upsertMaterial

  static Future<bool> saveHuntingSignals(
    List<Map<String, dynamic>> signals,
  ) async {
    return await LocalStorageService.saveHuntingSignals(signals);
  }

  static Future<bool> saveEducationalMaterials(
    List<Map<String, dynamic>> materials,
  ) async {
    return await LocalStorageService.saveEducationalMaterials(materials);
  }

  // ── UPSERT / REMOVE (admin writes — синхронізуються з Firebase) ────

  static Future<bool> upsertSignal(Map<String, dynamic> signal) async {
    // Оновлюємо локальний кеш
    final signals = await LocalStorageService.loadHuntingSignals() ?? [];
    final idx = signals.indexWhere((s) => s['id'] == signal['id']);
    if (idx >= 0) {
      signals[idx] = signal;
    } else {
      signals.add(signal);
    }
    await LocalStorageService.saveHuntingSignals(signals);

    // Зберігаємо в Firebase
    if (_currentStorage == StorageType.firebase) {
      return await FirebaseService.saveSignal(signal);
    }
    return true;
  }

  static Future<bool> removeSignal(String id) async {
    // Оновлюємо локальний кеш
    final signals = await LocalStorageService.loadHuntingSignals() ?? [];
    signals.removeWhere((s) => s['id'] == id);
    await LocalStorageService.saveHuntingSignals(signals);

    // Видаляємо з Firebase
    if (_currentStorage == StorageType.firebase) {
      return await FirebaseService.deleteSignal(id);
    }
    return true;
  }

  static Future<bool> upsertMaterial(Map<String, dynamic> material) async {
    final materials =
        await LocalStorageService.loadEducationalMaterials() ?? [];
    final idx = materials.indexWhere((m) => m['id'] == material['id']);
    if (idx >= 0) {
      materials[idx] = material;
    } else {
      materials.add(material);
    }
    await LocalStorageService.saveEducationalMaterials(materials);

    if (_currentStorage == StorageType.firebase) {
      return await FirebaseService.saveMaterial(material);
    }
    return true;
  }

  static Future<bool> removeMaterial(String id) async {
    final materials =
        await LocalStorageService.loadEducationalMaterials() ?? [];
    materials.removeWhere((m) => m['id'] == id);
    await LocalStorageService.saveEducationalMaterials(materials);

    if (_currentStorage == StorageType.firebase) {
      return await FirebaseService.deleteMaterial(id);
    }
    return true;
  }

  // ── SEED FIREBASE (адмін — публікація початкових даних) ────────────

  static Future<bool> seedFirebase() async {
    if (_currentStorage != StorageType.firebase) return false;
    try {
      final signals = await LocalStorageService.loadHuntingSignals() ?? [];
      final materials =
          await LocalStorageService.loadEducationalMaterials() ?? [];
      final sigOk = await FirebaseService.seedSignals(signals);
      final matOk = await FirebaseService.seedMaterials(materials);
      return sigOk && matOk;
    } catch (e) {
      debugPrint('seedFirebase error: $e');
      return false;
    }
  }

  // ── LEGACY ─────────────────────────────────────────────────────────

  static Future<bool> createBackup() async => true;
  static Future<bool> restoreFromBackup() async => true;
  static Future<bool> clearAll() async =>
      await LocalStorageService.clearAll();

  static Future<Map<String, dynamic>> getStorageInfo() async {
    final localInfo = await LocalStorageService.getStorageInfo();
    return {'storageType': _currentStorage.name, 'local': localInfo};
  }
}
