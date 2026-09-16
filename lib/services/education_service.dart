import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';

class EducationService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const _topicsCol        = 'edu_topics';
  static const _materialsCol     = 'edu_learning_materials';
  static const _flashcardsCol    = 'edu_flashcards';
  static const _testQuestionsCol = 'edu_test_questions';

  // ── ТЕМИ ────────────────────────────────────────────────────────────

  static Future<List<EducationTopic>> getTopics() async {
    try {
      final snap = await _db.collection(_topicsCol).get();
      final topics = snap.docs
          .map((d) => EducationTopic.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
      topics.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return topics;
    } catch (e) {
      debugPrint('getTopics error: $e');
      return [];
    }
  }

  static Future<bool> reorderTopics(List<EducationTopic> newOrder) async {
    try {
      final batch = _db.batch();
      for (int i = 0; i < newOrder.length; i++) {
        final updated = EducationTopic(
          id: newOrder[i].id,
          name: newOrder[i].name,
          description: newOrder[i].description,
          imageUrl: newOrder[i].imageUrl,
          sortOrder: i,
        );
        batch.set(_db.collection(_topicsCol).doc(updated.id), updated.toJson());
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('reorderTopics error: $e');
      return false;
    }
  }

  static Future<bool> saveTopic(EducationTopic topic) async {
    try {
      await _db.collection(_topicsCol).doc(topic.id).set(topic.toJson());
      return true;
    } catch (e) {
      debugPrint('saveTopic error: $e');
      return false;
    }
  }

  static Future<bool> deleteTopic(String id) async {
    try {
      await _db.collection(_topicsCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('deleteTopic error: $e');
      return false;
    }
  }

  // ── НАВЧАЛЬНІ МАТЕРІАЛИ ──────────────────────────────────────────────

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
      debugPrint('getMaterialsByTopic error: $e');
      return [];
    }
  }

  static Future<bool> saveLearningMaterial(LearningMaterial material) async {
    try {
      await _db.collection(_materialsCol).doc(material.id).set(material.toJson());
      return true;
    } catch (e) {
      debugPrint('saveLearningMaterial error: $e');
      return false;
    }
  }

  static Future<bool> deleteLearningMaterial(String id) async {
    try {
      await _db.collection(_materialsCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('deleteLearningMaterial error: $e');
      return false;
    }
  }

  // ── ФЛЕШ-КАРТКИ ─────────────────────────────────────────────────────

  static Future<List<Flashcard>> getFlashcardsByTopic(String topicId) async {
    try {
      final snap = await _db
          .collection(_flashcardsCol)
          .where('topicId', isEqualTo: topicId)
          .get();
      return snap.docs
          .map((d) => Flashcard.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (e) {
      debugPrint('getFlashcardsByTopic error: $e');
      return [];
    }
  }

  static Future<bool> saveFlashcard(Flashcard card) async {
    try {
      await _db.collection(_flashcardsCol).doc(card.id).set(card.toJson());
      return true;
    } catch (e) {
      debugPrint('saveFlashcard error: $e');
      return false;
    }
  }

  static Future<bool> deleteFlashcard(String id) async {
    try {
      await _db.collection(_flashcardsCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('deleteFlashcard error: $e');
      return false;
    }
  }

  /// CSV формат: питання,відповідь
  static Future<int> saveFlashcardsFromCsv(String topicId, String csvContent) async {
    try {
      final lines = csvContent
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final batch = _db.batch();
      int count = 0;
      final ts = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < lines.length; i++) {
        final commaIdx = lines[i].indexOf(',');
        if (commaIdx < 1) continue;
        final question = lines[i].substring(0, commaIdx).trim();
        final answer   = lines[i].substring(commaIdx + 1).trim();
        if (question.isEmpty || answer.isEmpty) continue;

        final id = 'fc_${ts}_$i';
        final card = Flashcard(id: id, topicId: topicId, question: question, answer: answer);
        batch.set(_db.collection(_flashcardsCol).doc(id), card.toJson());
        count++;
      }
      await batch.commit();
      return count;
    } catch (e) {
      debugPrint('saveFlashcardsFromCsv error: $e');
      return 0;
    }
  }

  static Future<bool> deleteAllFlashcardsForTopic(String topicId) async {
    try {
      final snap = await _db
          .collection(_flashcardsCol)
          .where('topicId', isEqualTo: topicId)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) batch.delete(doc.reference);
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('deleteAllFlashcards error: $e');
      return false;
    }
  }

  // ── ПИТАННЯ ТЕСТУ ────────────────────────────────────────────────────

  static Future<List<TestQuestion>> getTestQuestionsByTopic(String topicId) async {
    try {
      final snap = await _db
          .collection(_testQuestionsCol)
          .where('topicId', isEqualTo: topicId)
          .get();
      return snap.docs
          .map((d) => TestQuestion.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (e) {
      debugPrint('getTestQuestions error: $e');
      return [];
    }
  }

  static Future<bool> saveTestQuestion(TestQuestion q) async {
    try {
      await _db.collection(_testQuestionsCol).doc(q.id).set(q.toJson());
      return true;
    } catch (e) {
      debugPrint('saveTestQuestion error: $e');
      return false;
    }
  }

  static Future<bool> deleteTestQuestion(String id) async {
    try {
      await _db.collection(_testQuestionsCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('deleteTestQuestion error: $e');
      return false;
    }
  }

  /// CSV формат: питання,варіант1,варіант2,варіант3,варіант4,правильний_індекс(0-3),пояснення(опціонально)
  static Future<int> saveTestQuestionsFromCsv(String topicId, String csvContent) async {
    try {
      final lines = csvContent
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final batch = _db.batch();
      int count = 0;
      final ts = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < 6) continue;

        final question     = parts[0].trim();
        final options      = [parts[1].trim(), parts[2].trim(), parts[3].trim(), parts[4].trim()];
        final correctIndex = int.tryParse(parts[5].trim()) ?? 0;
        final explanation  = parts.length > 6 ? parts.sublist(6).join(',').trim() : null;

        if (question.isEmpty || options.any((o) => o.isEmpty)) continue;

        final id = 'tq_${ts}_$i';
        final q = TestQuestion(
          id: id,
          topicId: topicId,
          question: question,
          options: options,
          correctIndex: correctIndex,
          explanation: explanation,
        );
        batch.set(_db.collection(_testQuestionsCol).doc(id), q.toJson());
        count++;
      }
      await batch.commit();
      return count;
    } catch (e) {
      debugPrint('saveTestQuestionsFromCsv error: $e');
      return 0;
    }
  }

  static Future<bool> deleteAllTestQuestionsForTopic(String topicId) async {
    try {
      final snap = await _db
          .collection(_testQuestionsCol)
          .where('topicId', isEqualTo: topicId)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) batch.delete(doc.reference);
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('deleteAllTestQuestions error: $e');
      return false;
    }
  }
}
