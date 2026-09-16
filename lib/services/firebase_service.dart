import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Firebase Firestore service.
/// - Читання: всі користувачі (публічне)
/// - Запис: тільки через адмін панель (захищено паролем на рівні UI)
class FirebaseService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String _signalsCollection = 'signals';
  static const String _materialsCollection = 'materials';
  static const String _globalEventsCollection = 'global_events';
  static const String _sharedEventsCollection = 'shared_events';

  // ── SIGNALS ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> loadSignals() async {
    try {
      final snap = await _db.collection(_signalsCollection).get();
      if (snap.docs.isEmpty) return null;
      return snap.docs
          .map((doc) => Map<String, dynamic>.from(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Firebase loadSignals error: $e');
      return null;
    }
  }

  /// Real-time stream — оновлює дані на всіх пристроях автоматично
  static Stream<List<Map<String, dynamic>>> signalsStream() {
    return _db.collection(_signalsCollection).snapshots().map(
          (snap) => snap.docs
              .map((doc) => Map<String, dynamic>.from(doc.data()))
              .toList(),
        );
  }

  static Future<bool> saveSignal(Map<String, dynamic> signal) async {
    try {
      final id = signal['id'] as String?;
      if (id == null || id.isEmpty) return false;
      await _db.collection(_signalsCollection).doc(id).set(signal);
      return true;
    } catch (e) {
      debugPrint('Firebase saveSignal error: $e');
      return false;
    }
  }

  static Future<bool> deleteSignal(String id) async {
    try {
      await _db.collection(_signalsCollection).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Firebase deleteSignal error: $e');
      return false;
    }
  }

  // ── MATERIALS ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> loadMaterials() async {
    try {
      final snap = await _db.collection(_materialsCollection).get();
      if (snap.docs.isEmpty) return null;
      return snap.docs
          .map((doc) => Map<String, dynamic>.from(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Firebase loadMaterials error: $e');
      return null;
    }
  }

  static Future<bool> saveMaterial(Map<String, dynamic> material) async {
    try {
      final id = material['id'] as String?;
      if (id == null || id.isEmpty) return false;
      await _db.collection(_materialsCollection).doc(id).set(material);
      return true;
    } catch (e) {
      debugPrint('Firebase saveMaterial error: $e');
      return false;
    }
  }

  static Future<bool> deleteMaterial(String id) async {
    try {
      await _db.collection(_materialsCollection).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Firebase deleteMaterial error: $e');
      return false;
    }
  }

  // ── GLOBAL EVENTS (адмін → всі користувачі) ───────────────────────

  static Stream<List<Map<String, dynamic>>> globalEventsStream() {
    return _db.collection(_globalEventsCollection).snapshots().map(
          (snap) => snap.docs
              .map((doc) => Map<String, dynamic>.from(doc.data()))
              .toList(),
        );
  }

  static Future<bool> saveGlobalEvent(Map<String, dynamic> event) async {
    try {
      final id = event['id'] as String?;
      if (id == null || id.isEmpty) return false;
      await _db.collection(_globalEventsCollection).doc(id).set(event);
      return true;
    } catch (e) {
      debugPrint('Firebase saveGlobalEvent error: $e');
      return false;
    }
  }

  static Future<bool> deleteGlobalEvent(String id) async {
    try {
      await _db.collection(_globalEventsCollection).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Firebase deleteGlobalEvent error: $e');
      return false;
    }
  }

  // ── SHARED EVENTS (користувач → код → інший користувач) ───────────

  static Future<bool> saveSharedEvent(Map<String, dynamic> event) async {
    try {
      final id = event['id'] as String?;
      if (id == null || id.isEmpty) return false;
      await _db.collection(_sharedEventsCollection).doc(id).set(event);
      return true;
    } catch (e) {
      debugPrint('Firebase saveSharedEvent error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> findSharedEventByCode(
    String code,
  ) async {
    try {
      final snap = await _db
          .collection(_sharedEventsCollection)
          .where('shareCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return Map<String, dynamic>.from(snap.docs.first.data());
    } catch (e) {
      debugPrint('Firebase findSharedEventByCode error: $e');
      return null;
    }
  }

  // ── BULK SEED (адмін — публікація початкових даних) ────────────────

  static Future<bool> seedSignals(List<Map<String, dynamic>> signals) async {
    try {
      final batch = _db.batch();
      for (final signal in signals) {
        final id = signal['id'] as String?;
        if (id != null && id.isNotEmpty) {
          batch.set(_db.collection(_signalsCollection).doc(id), signal);
        }
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Firebase seedSignals error: $e');
      return false;
    }
  }

  static Future<bool> seedMaterials(
    List<Map<String, dynamic>> materials,
  ) async {
    try {
      final batch = _db.batch();
      for (final material in materials) {
        final id = material['id'] as String?;
        if (id != null && id.isNotEmpty) {
          batch.set(_db.collection(_materialsCollection).doc(id), material);
        }
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Firebase seedMaterials error: $e');
      return false;
    }
  }
}
