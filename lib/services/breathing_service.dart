import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunting_signals/models/breathing_models.dart';

/// Дихальна гімнастика: вправи (пише адміністратор) і журнал виконань
/// студента. Помилки не ковтаються — екрани показують їх у SnackBar.
class BreathingService {
  static final _db = FirebaseFirestore.instance;
  static const _exercises = 'breathing_exercises';
  static const _sessions = 'breathing_sessions';

  static Future<List<BreathingExercise>> getExercises() async {
    final snap = await _db.collection(_exercises).get();
    return snap.docs.map((d) => BreathingExercise.fromJson(d.id, d.data())).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Нова вправа — повний запис із createdAt/createdBy; наявна — merge, щоб
  /// не стерти поля, яких форма не знає.
  static Future<void> saveExercise(BreathingExercise ex, {required bool isNew}) async {
    final data = ex.toJson();
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['createdBy'] = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();
    }
    await _db.collection(_exercises).doc(ex.id).set(data, SetOptions(merge: !isNew));
  }

  static Future<void> setHidden(String id, bool hidden) =>
      _db.collection(_exercises).doc(id).update({'hidden': hidden});

  static Future<void> deleteExercise(String id) => _db.collection(_exercises).doc(id).delete();

  /// Запис виконання; ПІБ і група — з профілю users/{uid}, якщо вони там є.
  static Future<void> saveSession({
    required BreathingExercise ex,
    required int blocksCompleted,
    required int blocksTotal,
    required List<EnduranceResult> results,
    required int totalSeconds,
  }) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('Увійдіть, щоб зберігати результати');
    Map<String, dynamic> profile = {};
    try {
      profile = (await _db.collection('users').doc(u.uid).get()).data() ?? {};
    } catch (_) {/* профіль необов'язковий */}
    await _db.collection(_sessions).add({
      'uid': u.uid,
      'email': (u.email ?? '').toLowerCase(),
      'fullName': profile['fullName'],
      'group': profile['group'],
      'exerciseId': ex.id,
      'exerciseTitle': ex.title,
      'blocksCompleted': blocksCompleted,
      'blocksTotal': blocksTotal,
      'enduranceResults': results.map((r) => r.toJson()).toList(),
      'totalDurationSeconds': totalSeconds,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Останні 50 власних записів. Лише фільтр за uid (без складеного
  /// індексу), сортування на клієнті.
  static Future<List<BreathingSession>> getMySessions() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return [];
    final snap = await _db.collection(_sessions).where('uid', isEqualTo: u.uid).get();
    final list = snap.docs.map((d) => BreathingSession.fromDoc(d.id, d.data())).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  /// Видалення записів — правила дозволяють лише адміністратору.
  static Future<void> deleteSessions(List<String> ids) async {
    for (var i = 0; i < ids.length; i += 400) {
      final batch = _db.batch();
      for (final id in ids.skip(i).take(400)) {
        batch.delete(_db.collection(_sessions).doc(id));
      }
      await batch.commit();
    }
  }
}
