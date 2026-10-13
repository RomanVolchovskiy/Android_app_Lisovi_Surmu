import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';

/// Сервіс практичних завдань — зберігає теми та матеріали у окремих колекціях Firebase.
class PracticalService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _topicsCol    = 'practical_topics';
  static const _materialsCol = 'practical_materials';

  // ── ТЕМИ ПРАКТИЧНИХ ЗАВДАНЬ ───────────────────────────────────────────────

  static Future<List<EducationTopic>> getTopics() async {
    try {
      final snap = await _db.collection(_topicsCol).get();
      final topics = snap.docs
          .map((d) => EducationTopic.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
      topics.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return topics;
    } catch (e) {
      debugPrint('PracticalService.getTopics error: $e');
      return [];
    }
  }

  static Future<bool> saveTopic(EducationTopic topic) async {
    try {
      // merge: поля, яких модель не знає (їх може писати сайт), не стираються
      await _db.collection(_topicsCol).doc(topic.id).set(topic.toJson(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('PracticalService.saveTopic error: $e');
      return false;
    }
  }

  static Future<bool> deleteTopic(String id) async {
    try {
      await _db.collection(_topicsCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('PracticalService.deleteTopic error: $e');
      return false;
    }
  }

  static Future<bool> reorderTopics(List<EducationTopic> newOrder) async {
    try {
      final batch = _db.batch();
      for (int i = 0; i < newOrder.length; i++) {
        batch.update(_db.collection(_topicsCol).doc(newOrder[i].id), {'sortOrder': i});
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('PracticalService.reorderTopics error: $e');
      return false;
    }
  }

  /// Теоретичні теми, пробні тести яких — «тест дня» цієї практичної теми.
  static Future<bool> setTestTopics(String topicId, List<String> testTopicIds) async {
    try {
      await _db.collection(_topicsCol).doc(topicId).update({'testTopicIds': testTopicIds});
      return true;
    } catch (e) {
      debugPrint('PracticalService.setTestTopics error: $e');
      return false;
    }
  }

  // ── МАТЕРІАЛИ ПРАКТИЧНИХ ЗАВДАНЬ ──────────────────────────────────────────

  static Future<List<LearningMaterial>> getMaterialsByTopic(String topicId) async {
    try {
      final snap = await _db
          .collection(_materialsCol)
          .where('topicId', isEqualTo: topicId)
          .get();
      return snap.docs
          .map((d) => LearningMaterial.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (e) {
      debugPrint('PracticalService.getMaterialsByTopic error: $e');
      return [];
    }
  }

  static Future<bool> saveMaterial(LearningMaterial material) async {
    try {
      await _db.collection(_materialsCol).doc(material.id).set(material.toJson());
      return true;
    } catch (e) {
      debugPrint('PracticalService.saveMaterial error: $e');
      return false;
    }
  }

  static Future<bool> deleteMaterial(String id) async {
    try {
      await _db.collection(_materialsCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('PracticalService.deleteMaterial error: $e');
      return false;
    }
  }
}
