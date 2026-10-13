import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Запис пробного тесту (ТЗ практики, розділ 4): quiz_results/{autoId}.
/// Ті самі документи пише сайт (site/js/quiz-results.js); викладач бачить їх
/// на сайті в «Управління іспитами» → «Пробні тести».
class QuizResult {
  final String id;
  final String kind; // 'theory' | 'audio'
  final String topicName;
  final int correct;
  final int total;
  final int percent;
  final DateTime? createdAt;

  const QuizResult({
    required this.id,
    required this.kind,
    required this.topicName,
    required this.correct,
    required this.total,
    required this.percent,
    this.createdAt,
  });

  factory QuizResult.fromDoc(String id, Map<String, dynamic> j) => QuizResult(
        id: id,
        kind: j['kind']?.toString() ?? 'theory',
        topicName: j['topicName']?.toString() ?? '',
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        percent: (j['percent'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as Timestamp?)?.toDate(),
      );

  /// Назва тесту для списку — як quizTitle на сайті.
  String get title => kind == 'audio'
      ? 'Аудіотест: ${topicName.isEmpty ? 'усі сигнали' : topicName}'
      : (topicName.isEmpty ? 'Теоретичний тест' : topicName);
}

class QuizResultsService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'quiz_results';

  static const audioLevelNames = {'easy': 'легкий рівень', 'medium': 'середній рівень', 'hard': 'важкий рівень'};

  /// Зберігає результат завершеного пробного тесту. Без входу або при
  /// помилці нічого не робить — студенту це не заважає.
  static Future<void> save({
    required String kind,
    String? topicId,
    required String topicName,
    String? audioFilter,
    required int correct,
    required int total,
  }) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || total <= 0) return;
    try {
      Map<String, dynamic> profile = {};
      try {
        profile = (await _db.collection('users').doc(u.uid).get()).data() ?? {};
      } catch (_) {/* профіль необов'язковий */}
      await _db.collection(_col).add({
        'uid': u.uid,
        'email': (u.email ?? '').toLowerCase(),
        'fullName': profile['fullName']?.toString() ?? '',
        'group': profile['group']?.toString() ?? '',
        'kind': kind,
        'topicId': topicId,
        'topicName': topicName,
        'audioFilter': audioFilter,
        'correct': correct,
        'total': total,
        'percent': (correct / total * 100).round(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('quiz_results: $e');
    }
  }

  /// Останні 50 результатів поточного користувача (фільтр лише за uid —
  /// без складеного індексу; сортування на клієнті).
  static Future<List<QuizResult>> myResults() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return [];
    final snap = await _db.collection(_col).where('uid', isEqualTo: u.uid).get();
    final list = snap.docs.map((d) => QuizResult.fromDoc(d.id, d.data())).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list.take(50).toList();
  }
}
