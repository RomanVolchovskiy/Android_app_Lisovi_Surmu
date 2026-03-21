import 'package:flutter/material.dart';

import 'google_drive_service.dart';
import 'local_storage_service.dart';

enum StorageType { local, googleDrive, firebase }

class StorageManager {
  static StorageType _currentStorage = StorageType.googleDrive;

  static Future<bool> initialize({
    StorageType storageType = StorageType.googleDrive,
  }) async {
    try {
      _currentStorage = storageType;
      await LocalStorageService.initialize();
      if (storageType == StorageType.googleDrive) {
        await GoogleDriveService.initialize();
      }
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

  // ─── СИГНАЛИ ───────────────────────────────────────────────────

  static Future<bool> saveHuntingSignals(
    List<Map<String, dynamic>> signals,
  ) async {
    try {
      // Завжди зберігаємо локально
      await LocalStorageService.saveHuntingSignals(signals);

      // Якщо Google Drive — синхронізуємо
      if (_currentStorage == StorageType.googleDrive) {
        final allData = await _buildDataBundle(signals: signals);
        final id = await GoogleDriveService.saveData(allData);
        return id != null;
      }
      return true;
    } catch (e) {
      debugPrint('Error saving signals: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> loadHuntingSignals() async {
    try {
      if (_currentStorage == StorageType.googleDrive) {
        final data = await GoogleDriveService.loadData();
        if (data != null && data.containsKey('signals')) {
          final signals = List<Map<String, dynamic>>.from(data['signals']);
          // Кешуємо локально
          await LocalStorageService.saveHuntingSignals(signals);
          return signals;
        }
      }
      return await LocalStorageService.loadHuntingSignals();
    } catch (e) {
      debugPrint('Error loading signals: $e');
      return await LocalStorageService.loadHuntingSignals();
    }
  }

  // ─── НАВЧАЛЬНІ МАТЕРІАЛИ ────────────────────────────────────────

  static Future<bool> saveEducationalMaterials(
    List<Map<String, dynamic>> materials,
  ) async {
    try {
      await LocalStorageService.saveEducationalMaterials(materials);

      if (_currentStorage == StorageType.googleDrive) {
        final allData = await _buildDataBundle(materials: materials);
        final id = await GoogleDriveService.saveData(allData);
        return id != null;
      }
      return true;
    } catch (e) {
      debugPrint('Error saving materials: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> loadEducationalMaterials() async {
    try {
      if (_currentStorage == StorageType.googleDrive) {
        final data = await GoogleDriveService.loadData();
        if (data != null && data.containsKey('materials')) {
          final materials = List<Map<String, dynamic>>.from(data['materials']);
          await LocalStorageService.saveEducationalMaterials(materials);
          return materials;
        }
      }
      return await LocalStorageService.loadEducationalMaterials();
    } catch (e) {
      debugPrint('Error loading materials: $e');
      return await LocalStorageService.loadEducationalMaterials();
    }
  }

  // ─── ПОВНА СИНХРОНІЗАЦІЯ ────────────────────────────────────────

  /// Завантажити ВСІ дані з Drive одним запитом
  static Future<bool> syncFromDrive() async {
    try {
      final data = await GoogleDriveService.loadData();
      if (data == null) return false;

      if (data.containsKey('signals')) {
        final signals = List<Map<String, dynamic>>.from(data['signals']);
        await LocalStorageService.saveHuntingSignals(signals);
      }
      if (data.containsKey('materials')) {
        final materials = List<Map<String, dynamic>>.from(data['materials']);
        await LocalStorageService.saveEducationalMaterials(materials);
      }
      debugPrint('Sync from Drive: успішно');
      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      return false;
    }
  }

  /// Завантажити ВСІ дані у Drive одним запитом (тільки адмін)
  static Future<bool> syncToDrive() async {
    try {
      final signals = await LocalStorageService.loadHuntingSignals() ?? [];
      final materials = await LocalStorageService.loadEducationalMaterials() ?? [];
      final allData = {
        'signals': signals,
        'materials': materials,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final id = await GoogleDriveService.saveData(allData);
      return id != null;
    } catch (e) {
      debugPrint('Sync to Drive error: $e');
      return false;
    }
  }

  // ─── ДОПОМІЖНІ ─────────────────────────────────────────────────

  /// Будує повний bundle даних для збереження в Drive
  static Future<Map<String, dynamic>> _buildDataBundle({
    List<Map<String, dynamic>>? signals,
    List<Map<String, dynamic>>? materials,
  }) async {
    final existingSignals = signals ?? await LocalStorageService.loadHuntingSignals() ?? [];
    final existingMaterials = materials ?? await LocalStorageService.loadEducationalMaterials() ?? [];
    return {
      'signals': existingSignals,
      'materials': existingMaterials,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<bool> createBackup() async => await syncToDrive();

  static Future<bool> restoreFromBackup() async => await syncFromDrive();

  static Future<bool> clearAll() async {
    return await LocalStorageService.clearAll();
  }

  static Future<Map<String, dynamic>> getStorageInfo() async {
    final localInfo = await LocalStorageService.getStorageInfo();
    final driveInfo = await GoogleDriveService.getStorageInfo();
    return {
      'storageType': _currentStorage.name,
      'local': localInfo,
      'drive': driveInfo,
    };
  }
}
