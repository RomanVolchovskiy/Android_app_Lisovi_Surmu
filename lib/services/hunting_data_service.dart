import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/firebase_service.dart';
import 'package:hunting_signals/services/local_storage_service.dart';
import 'package:hunting_signals/services/storage_manager.dart';

class HuntingDataService {
  static List<HuntingSignal> _signals = [];
  static List<EducationMaterial> _educationMaterials = [];

  /// Real-time stream сигналів з Firebase.
  /// Оновлює внутрішній кеш і сповіщає всіх слухачів автоматично.
  static Stream<List<HuntingSignal>> signalsStream() {
    return FirebaseService.signalsStream().map((data) {
      if (data.isNotEmpty) {
        _signals = data.map((j) => HuntingSignal.fromJson(j)).toList();
        _signals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      return List<HuntingSignal>.from(_signals);
    });
  }

  /// Ініціалізація даних: Firebase → локальний кеш → дефолтні значення
  static Future<void> loadPersistedData() async {
    final List<Map<String, dynamic>>? loadedSignals =
        await StorageManager.loadHuntingSignals();

    if (loadedSignals != null && loadedSignals.isNotEmpty) {
      _signals =
          loadedSignals.map((json) => HuntingSignal.fromJson(json)).toList();
      _signals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } else {
      // Firebase порожній або офлайн — завантажуємо дефолтні
      await getAllSignals();
      // Кешуємо локально (не пишемо в Firebase — адмін публікує вручну)
      final signalsJson = _signals.map((s) => s.toJson()).toList();
      await LocalStorageService.saveHuntingSignals(signalsJson);
    }

    final List<Map<String, dynamic>>? loadedMaterials =
        await StorageManager.loadEducationalMaterials();

    if (loadedMaterials != null && loadedMaterials.isNotEmpty) {
      _educationMaterials = loadedMaterials
          .map((json) => EducationMaterial.fromJson(json))
          .toList();
    } else {
      await getEducationMaterials();
      final materialsJson = _educationMaterials.map((m) => m.toJson()).toList();
      await LocalStorageService.saveEducationalMaterials(materialsJson);
    }
  }

  // ── КАТЕГОРІЇ ──────────────────────────────────────────────────────

  static Future<List<SignalCategory>> getCategories() async {
    return [
      SignalCategory(
        id: '1',
        name: 'Інформаційні',
        description: 'Сигнали для передачі інформації',
        icon: 'info',
        color: Colors.blue,
      ),
      SignalCategory(
        id: '2',
        name: 'Організаційні',
        description: 'Сигнали для організації полювання',
        icon: 'group',
        color: Colors.green,
      ),
      SignalCategory(
        id: '3',
        name: 'Сигнали покоту',
        description: 'Сигнали для полювання з гончими',
        icon: 'pets',
        color: Colors.orange,
      ),
      SignalCategory(
        id: '4',
        name: 'Святково-церемоніальні',
        description: 'Сигнали для святкових та церемоніальних подій',
        icon: 'celebration',
        color: Colors.purple,
      ),
      SignalCategory(
        id: '5',
        name: 'Довільні',
        description: 'Довільні мисливські сигнали',
        icon: 'music_note',
        color: Colors.teal,
      ),
    ];
  }

  // ── СИГНАЛИ — CRUD ─────────────────────────────────────────────────

  static Future<List<HuntingSignal>> getAllSignals() async {
    if (_signals.isEmpty) {
      _signals = [
        HuntingSignal(
          id: '1',
          name: 'Сигнал збору',
          category: 'Інформаційні',
          description: 'Сигнал для збору мисливців перед початком полювання',
          audioUrl:
              'https://drive.google.com/uc?export=download&id=1669WJ6zNDljlUHL6VpZ_MVA9Acf1C39X',
          duration: 15,
        ),
        HuntingSignal(
          id: '2',
          name: 'Початок полювання',
          category: 'Організаційні',
          description: 'Сигнал для оголошення початку полювання',
          audioUrl:
              'https://drive.google.com/uc?export=download&id=1669WJ6zNDljlUHL6VpZ_MVA9Acf1C39X',
          duration: 15,
        ),
        HuntingSignal(
          id: '3',
          name: 'Гончі на слід',
          category: 'Сигнали покоту',
          description: 'Сигнал для гончих — знайдено слід звіра',
          audioUrl:
              'https://drive.google.com/uc?export=download&id=1669WJ6zNDljlUHL6VpZ_MVA9Acf1C39X',
          duration: 15,
        ),
        HuntingSignal(
          id: '4',
          name: 'Святковий фанфар',
          category: 'Святково-церемоніальні',
          description: 'Урочистий сигнал для святкових мисливських заходів',
          audioUrl:
              'https://drive.google.com/uc?export=download&id=1669WJ6zNDljlUHL6VpZ_MVA9Acf1C39X',
          duration: 15,
        ),
      ];
    }
    return _signals;
  }

  /// Додати новий сигнал → зберігається в Firebase автоматично
  static Future<bool> addSignal(HuntingSignal signal) async {
    _signals.add(signal);
    return await StorageManager.upsertSignal(signal.toJson());
  }

  /// Оновити сигнал → оновлюється в Firebase автоматично
  static Future<bool> updateSignal(HuntingSignal signal) async {
    await getAllSignals();
    final index = _signals.indexWhere((s) => s.id == signal.id);
    if (index == -1) return false;
    _signals[index] = signal;
    return await StorageManager.upsertSignal(signal.toJson());
  }

  /// Змінити порядок сигналів → зберігається в Firebase та локально
  static Future<void> reorderSignals(List<HuntingSignal> newOrder) async {
    _signals = newOrder.asMap().entries
        .map((e) => e.value.copyWith(sortOrder: e.key))
        .toList();
    final json = _signals.map((s) => s.toJson()).toList();
    await LocalStorageService.saveHuntingSignals(json);
    FirebaseService.seedSignals(json); // fire-and-forget batch write
  }

  /// Видалити сигнал → видаляється з Firebase автоматично
  static Future<bool> deleteSignal(String id) async {
    await getAllSignals();
    _signals.removeWhere((s) => s.id == id);
    return await StorageManager.removeSignal(id);
  }

  static Future<List<HuntingSignal>> getSignalsByCategory(
    String category,
  ) async {
    final allSignals = await getAllSignals();
    return allSignals.where((signal) => signal.category == category).toList();
  }

  // ── НАВЧАЛЬНІ МАТЕРІАЛИ — CRUD ─────────────────────────────────────

  static Future<List<EducationMaterial>> getEducationMaterials() async {
    if (_educationMaterials.isEmpty) {
      _educationMaterials = [
        EducationMaterial(
          id: 'edu_001',
          title: 'Як читати мисливські ноти',
          description: 'Повний посібник з читання мисливських нот',
          type: EducationType.article,
          content: 'Детальна інструкція...',
          category: 'Нотна грамота',
          difficulty: DifficultyLevel.beginner,
          tags: ['ноти'],
          createdAt: DateTime.now(),
        ),
      ];
    }
    return _educationMaterials;
  }

  /// Додати матеріал → зберігається в Firebase автоматично
  static Future<bool> addEducationMaterial(EducationMaterial material) async {
    _educationMaterials.add(material);
    return await StorageManager.upsertMaterial(material.toJson());
  }

  /// Оновити матеріал → оновлюється в Firebase автоматично
  static Future<bool> updateMaterial(EducationMaterial material) async {
    await getEducationMaterials();
    final index = _educationMaterials.indexWhere((m) => m.id == material.id);
    if (index == -1) return false;
    _educationMaterials[index] = material;
    return await StorageManager.upsertMaterial(material.toJson());
  }

  /// Видалити матеріал → видаляється з Firebase автоматично
  static Future<bool> deleteMaterial(String id) async {
    await getEducationMaterials();
    _educationMaterials.removeWhere((m) => m.id == id);
    return await StorageManager.removeMaterial(id);
  }
}
