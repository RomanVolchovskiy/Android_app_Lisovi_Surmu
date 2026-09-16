import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyPlanService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _adminPlanCol   = 'study_plan';
  static const _userPlanKey    = 'user_study_plan';
  static const _completedKey   = 'completed_materials';

  // ── ПЛАН АДМІНІСТРАТОРА (Firebase) ────────────────────────────────────────

  static Future<List<StudyPlanEntry>> getAdminPlan() async {
    try {
      final snap = await _db.collection(_adminPlanCol).get();
      final entries = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return StudyPlanEntry.fromJson(data);
      }).toList();
      entries.sort((a, b) => a.order.compareTo(b.order));
      return entries;
    } catch (e) {
      debugPrint('getAdminPlan error: $e');
      return [];
    }
  }

  /// Повертає записи плану для конкретного рівня
  static Future<List<StudyPlanEntry>> getAdminPlanByLevel(String level) async {
    try {
      final snap = await _db
          .collection(_adminPlanCol)
          .where('level', isEqualTo: level)
          .get();
      final entries = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return StudyPlanEntry.fromJson(data);
      }).toList();
      entries.sort((a, b) => a.order.compareTo(b.order));
      return entries;
    } catch (e) {
      debugPrint('getAdminPlanByLevel error: $e');
      return [];
    }
  }

  static Future<bool> saveAdminEntry(StudyPlanEntry entry) async {
    try {
      await _db.collection(_adminPlanCol).doc(entry.id).set(entry.toJson());
      return true;
    } catch (e) {
      debugPrint('saveAdminEntry error: $e');
      return false;
    }
  }

  static Future<bool> deleteAdminEntry(String id) async {
    try {
      await _db.collection(_adminPlanCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('deleteAdminEntry error: $e');
      return false;
    }
  }

  static Future<bool> reorderAdminPlan(List<StudyPlanEntry> entries) async {
    try {
      final batch = _db.batch();
      for (int i = 0; i < entries.length; i++) {
        final updated = entries[i].copyWith(order: i);
        batch.set(_db.collection(_adminPlanCol).doc(updated.id), updated.toJson());
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('reorderAdminPlan error: $e');
      return false;
    }
  }

  // ── ВЛАСНИЙ ПЛАН КОРИСТУВАЧА (SharedPreferences) ──────────────────────────

  static Future<List<StudyPlanEntry>> getUserPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userPlanKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final entries = list.map((e) => StudyPlanEntry.fromJson(e as Map<String, dynamic>)).toList();
      entries.sort((a, b) => a.order.compareTo(b.order));
      return entries;
    } catch (e) {
      return [];
    }
  }

  static Future<void> _saveUserPlan(List<StudyPlanEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPlanKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static Future<bool> addUserEntry(String topicId) async {
    try {
      final entries = await getUserPlan();
      if (entries.any((e) => e.topicId == topicId)) return false; // вже є
      final id = 'up_${DateTime.now().millisecondsSinceEpoch}';
      entries.add(StudyPlanEntry(id: id, topicId: topicId, order: entries.length));
      await _saveUserPlan(entries);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> removeUserEntry(String id) async {
    final entries = await getUserPlan();
    entries.removeWhere((e) => e.id == id);
    for (int i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(order: i);
    }
    await _saveUserPlan(entries);
  }

  // ── ІНДИВІДУАЛЬНІ ПЛАНИ КОРИСТУВАЧА ──────────────────────────────────────

  static const _userPlansKey = 'user_named_plans';

  static Future<List<UserPlan>> getUserPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userPlansKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final plans = list.map((e) => UserPlan.fromJson(e as Map<String, dynamic>)).toList();
      plans.sort((a, b) => a.order.compareTo(b.order));
      return plans;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveUserPlans(List<UserPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPlansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));
  }

  static Future<void> addUserPlan(UserPlan plan) async {
    final plans = await getUserPlans();
    plans.add(plan);
    await _saveUserPlans(plans);
  }

  static Future<void> deleteUserPlan(String id) async {
    final plans = await getUserPlans();
    plans.removeWhere((p) => p.id == id);
    for (int i = 0; i < plans.length; i++) {
      plans[i] = UserPlan(
        id: plans[i].id, name: plans[i].name, order: i,
        theoreticalTopicIds: plans[i].theoreticalTopicIds,
        practicalTopicIds: plans[i].practicalTopicIds,
      );
    }
    await _saveUserPlans(plans);
  }

  // ── ВІДСТЕЖЕННЯ ВИКОНАННЯ МАТЕРІАЛІВ ─────────────────────────────────────

  static Future<Set<String>> getCompletedMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedKey) ?? []).toSet();
  }

  static Future<void> toggleMaterialDone(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_completedKey) ?? []).toSet();
    if (set.contains(materialId)) {
      set.remove(materialId);
    } else {
      set.add(materialId);
    }
    await prefs.setStringList(_completedKey, set.toList());
  }

  /// Версія з кастомним завантажувачем матеріалів (для практичних тем)
  static Future<Map<String, bool>> computeCompletionMapGeneric(
      List<String> topicIds,
      Future<List<LearningMaterial>> Function(String) loader,
      Set<String> completed) async {
    final result = <String, bool>{};
    await Future.wait(topicIds.map((tid) async {
      try {
        final mats = await loader(tid);
        result[tid] = mats.isNotEmpty && mats.every((m) => completed.contains(m.id));
      } catch (_) {
        result[tid] = false;
      }
    }));
    return result;
  }

  /// Обчислює для кожного topicId: чи всі матеріали виконані
  static Future<Map<String, bool>> computeCompletionMap(
      List<String> topicIds, Set<String> completed) async {
    final result = <String, bool>{};
    await Future.wait(topicIds.map((tid) async {
      try {
        final materials = await EducationService.getMaterialsByTopic(tid);
        if (materials.isEmpty) {
          result[tid] = false;
        } else {
          result[tid] = materials.every((m) => completed.contains(m.id));
        }
      } catch (_) {
        result[tid] = false;
      }
    }));
    return result;
  }
}
