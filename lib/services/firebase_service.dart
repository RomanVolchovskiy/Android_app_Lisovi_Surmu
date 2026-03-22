import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Firebase Firestore service.
/// - Читання: всі користувачі (публічне)
/// - Запис: тільки через адмін панель (захищено паролем на рівні UI)
class FirebaseService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String _signalsCollection = 'signals';
  static const String _materialsCollection = 'materials';

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
