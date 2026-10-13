import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/utils/csv_import.dart';

/// Підсумок імпорту CSV: скільки додано і які рядки пропущено.
class CsvImportResult {
  final int added;
  final List<CsvSkip> skipped;
  const CsvImportResult(this.added, this.skipped);
}

/// Наступний sortOrder у кінець списку (як nextOrder на сайті).
int nextSortOrder(Iterable<int?> orders) =>
    orders.fold<int>(orders.length, (m, o) => o != null && o + 1 > m ? o + 1 : m);

class EducationService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const _topicsCol        = 'edu_topics';
  static const _materialsCol     = 'edu_learning_materials';
  static const _flashcardsCol    = 'edu_flashcards';
  static const _testQuestionsCol = 'edu_test_questions';

  // ── ТЕМИ ────────────────────────────────────────────────────────────

  /// Приховані теми (лише для іспитів) студентам не показуються;
  /// адмінка й вибір тем для іспиту передають [includeHidden].
  static Future<List<EducationTopic>> getTopics({bool includeHidden = false}) async {
    try {
      final snap = await _db.collection(_topicsCol).get();
      final topics = snap.docs
          .map((d) => EducationTopic.fromJson(Map<String, dynamic>.from(d.data())))
          .where((t) => includeHidden || !t.hidden)
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
      // Лише sortOrder: решта полів (hidden, поля сайту) лишається як є
      final batch = _db.batch();
      for (int i = 0; i < newOrder.length; i++) {
        batch.update(_db.collection(_topicsCol).doc(newOrder[i].id), {'sortOrder': i});
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
      // merge: поля, яких модель не знає (їх може писати сайт), не стираються
      await _db.collection(_topicsCol).doc(topic.id).set(topic.toJson(), SetOptions(merge: true));
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
          .toList()
        ..sort((a, b) => compareBySortOrder(a.sortOrder, a.id, b.sortOrder, b.id));
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

  /// CSV: питання,відповідь (поля в лапках можуть містити коми; заголовок і
  /// BOM пропускаються). Нові картки додаються в кінець списку теми.
  static Future<CsvImportResult> saveFlashcardsFromCsv(String topicId, String csvContent) async {
    final parsed = parseCsvFile(csvContent, parseCardRow);
    if (parsed.rows.isEmpty) return CsvImportResult(0, parsed.skipped);
    final existing = await getFlashcardsByTopic(topicId);
    final base = nextSortOrder(existing.map((c) => c.sortOrder));
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < parsed.rows.length; i += 400) {
      final batch = _db.batch();
      for (var j = i; j < parsed.rows.length && j < i + 400; j++) {
        final r = parsed.rows[j];
        final card = Flashcard(id: importId('fc', ts, j), topicId: topicId, question: r.question, answer: r.answer, sortOrder: base + j);
        batch.set(_db.collection(_flashcardsCol).doc(card.id), card.toJson());
      }
      await batch.commit();
    }
    return CsvImportResult(parsed.rows.length, parsed.skipped);
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
          .toList()
        ..sort((a, b) => compareBySortOrder(a.sortOrder, a.id, b.sortOrder, b.id));
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

  /// CSV: питання,варіант1,варіант2,варіант3,варіант4,правильний(0-3)[,пояснення].
  /// Рядки з помилками пропускаються (номери — у результаті).
  static Future<CsvImportResult> saveTestQuestionsFromCsv(String topicId, String csvContent) async {
    final parsed = parseCsvFile(csvContent, parseQuestionRow);
    if (parsed.rows.isEmpty) return CsvImportResult(0, parsed.skipped);
    final existing = await getTestQuestionsByTopic(topicId);
    final base = nextSortOrder(existing.map((q) => q.sortOrder));
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < parsed.rows.length; i += 400) {
      final batch = _db.batch();
      for (var j = i; j < parsed.rows.length && j < i + 400; j++) {
        final r = parsed.rows[j];
        final q = TestQuestion(
          id: importId('tq', ts, j),
          topicId: topicId,
          question: r.question,
          options: r.options,
          correctIndex: r.correctIndex,
          explanation: r.explanation,
          sortOrder: base + j,
        );
        batch.set(_db.collection(_testQuestionsCol).doc(q.id), q.toJson());
      }
      await batch.commit();
    }
    return CsvImportResult(parsed.rows.length, parsed.skipped);
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
