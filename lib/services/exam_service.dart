import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hunting_signals/models/exam_models.dart';

/// Сесії й роботи іспиту. Сам іспит студент складає на сайті (спроби
/// exam_attempts, таймер, автозбереження) — додаток лише створює сесії й
/// показує здані роботи (exam_submissions пише сайт у тому ж форматі).
class ExamService {
  static final _db = FirebaseFirestore.instance;

  static const siteUrl = 'https://lisovi-surmy.vercel.app';
  static const siteExamUrl = '$siteUrl/#/education';

  static const _sessionsCol    = 'exam_sessions';
  static const _submissionsCol = 'exam_submissions';

  // ── Генерація коду ───────────────────────────────────────────────────────
  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Сесії ────────────────────────────────────────────────────────────────
  /// Нова сесія: id документа = код (як на сайті — студент знаходить сесію
  /// одним get). Якщо такий код уже зайнятий, генерується інший.
  static Future<ExamSession?> createSession(ExamSession session) async {
    try {
      for (var i = 0; i < 5; i++) {
        final code = i == 0 ? session.code : generateCode();
        final ref = _db.collection(_sessionsCol).doc(code);
        if ((await ref.get()).exists) continue;
        final json = {...session.toJson(), 'id': code, 'code': code};
        await ref.set(json);
        return ExamSession.fromJson(json);
      }
    } catch (e) {
      debugPrint('createSession error: $e');
    }
    return null;
  }

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

  // ── Роботи студентів (пише сайт) ─────────────────────────────────────────
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
}
