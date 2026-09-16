import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hunting_signals/models/exam_models.dart';

class ExamService {
  static final _db      = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static const _sessionsCol    = 'exam_sessions';
  static const _submissionsCol = 'exam_submissions';

  // ── Генерація коду ───────────────────────────────────────────────────────
  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Сесії ────────────────────────────────────────────────────────────────
  static Future<bool> saveSession(ExamSession session) async {
    try {
      await _db.collection(_sessionsCol).doc(session.id).set(session.toJson());
      return true;
    } catch (e) {
      debugPrint('saveSession error: $e');
      return false;
    }
  }

  static Future<List<ExamSession>> getAllSessions() async {
    try {
      final snap = await _db.collection(_sessionsCol)
          .orderBy('createdAt', descending: true).get();
      return snap.docs
          .map((d) => ExamSession.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (e) {
      debugPrint('getAllSessions error: $e');
      return [];
    }
  }

  static Future<ExamSession?> getSessionByCode(String code) async {
    try {
      final snap = await _db.collection(_sessionsCol)
          .where('code', isEqualTo: code.toUpperCase().trim())
          .limit(1).get();
      if (snap.docs.isEmpty) return null;
      return ExamSession.fromJson(Map<String, dynamic>.from(snap.docs.first.data()));
    } catch (e) {
      debugPrint('getSessionByCode error: $e');
      return null;
    }
  }

  static Future<bool> updateSessionStatus(String id, String status) async {
    try {
      await _db.collection(_sessionsCol).doc(id).update({'status': status});
      return true;
    } catch (e) {
      debugPrint('updateSessionStatus error: $e');
      return false;
    }
  }

  static Future<bool> deleteSession(String id) async {
    try {
      await _db.collection(_sessionsCol).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('deleteSession error: $e');
      return false;
    }
  }

  // ── Роботи студентів ─────────────────────────────────────────────────────
  static Future<bool> hasSubmitted(String sessionId, String studentName) async {
    try {
      final snap = await _db.collection(_submissionsCol)
          .where('sessionId',   isEqualTo: sessionId)
          .where('studentName', isEqualTo: studentName.trim())
          .limit(1).get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('hasSubmitted error: $e');
      return false;
    }
  }

  static Future<bool> saveSubmission(ExamSubmission sub) async {
    try {
      await _db.collection(_submissionsCol).doc(sub.id).set(sub.toJson());
      return true;
    } catch (e) {
      debugPrint('saveSubmission error: $e');
      return false;
    }
  }

  static Future<List<ExamSubmission>> getSubmissionsBySession(String sessionId) async {
    try {
      final snap = await _db.collection(_submissionsCol)
          .where('sessionId', isEqualTo: sessionId)
          .orderBy('submittedAt').get();
      return snap.docs
          .map((d) => ExamSubmission.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (e) {
      debugPrint('getSubmissions error: $e');
      return [];
    }
  }

  static Future<bool> updateGrade(ExamSubmission sub) async {
    try {
      await _db.collection(_submissionsCol).doc(sub.id).update({
        'adminTheoryPoints': sub.adminTheoryPoints,
        'adminAudioPoints':  sub.adminAudioPoints,
        'adminFilePoints':   sub.adminFilePoints,
        'adminNote':         sub.adminNote,
        'status':            sub.status,
      });
      return true;
    } catch (e) {
      debugPrint('updateGrade error: $e');
      return false;
    }
  }

  // ── Завантаження файлу в Storage ─────────────────────────────────────────
  // Приймає байти, а не File: на вебі file_picker не дає шляху до файлу,
  // тому putFile там непридатний. putData працює на всіх платформах.
  static Future<String?> uploadFile(
      String sessionId, String submissionId, Uint8List bytes, String fileName) async {
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
      final ref = _storage.ref('exam_files/$sessionId/$submissionId.$ext');
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('uploadFile error: $e');
      return null;
    }
  }

  // ── Розрахунок балів ─────────────────────────────────────────────────────
  static int scaleScore(int correct, int total, int maxPoints) {
    if (total == 0 || maxPoints == 0) return 0;
    return (correct / total * maxPoints).round();
  }
}
