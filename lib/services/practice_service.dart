import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hunting_signals/services/practice_core.dart';

/// Дані розділу «Практика» — ті самі документи, що й на сайті
/// (site/js/practice-data.js): робота студента practice_work/{uid}, оцінки
/// викладача practice_grades/{uid}, файли practice_uploads/{uid}/{step}/…,
/// автоматичні джерела — quiz_results та іспит (exam_attempts/submissions).
class PracticeData {
  final String uid, email;
  final Map<String, dynamic> work;
  final Map<String, dynamic> grades;
  final PracticeCtx ctx;
  PracticeData({required this.uid, required this.email, required this.work, required this.grades, required this.ctx});

  String get fullName => ctx.fullName;
  String get group => ctx.group;
}

class PracticeService {
  static final _db = FirebaseFirestore.instance;
  static const work = 'practice_work';
  static const grades = 'practice_grades';
  static const maxFile = 20 * 1024 * 1024;
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf', 'doc', 'docx', 'odt', 'ppt', 'pptx', 'odp', 'txt'];
  static const _mime = {
    'pdf': 'application/pdf', 'doc': 'application/msword', 'txt': 'text/plain',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'ppt': 'application/vnd.ms-powerpoint',
    'odt': 'application/vnd.oasis.opendocument.text', 'odp': 'application/vnd.oasis.opendocument.presentation',
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'heic': 'image/heic', 'webp': 'image/webp',
  };

  static List<Map<String, dynamic>> _rows(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => {'id': d.id, ...d.data()}).toList();

  static Map<String, dynamic> _grades(DocumentSnapshot<Map<String, dynamic>> d) {
    final g = d.data()?['grades'];
    return g is Map ? Map<String, dynamic>.from(g) : {};
  }

  /// Пробні тести й іспит конкретного студента (для автоматичних кроків).
  static Future<(List<Map<String, dynamic>>, ExamPoints?)> _autoSources(String uid) async {
    final r = await Future.wait([
      _db.collection('quiz_results').where('uid', isEqualTo: uid).get().then(_rows).catchError((_) => <Map<String, dynamic>>[]),
      _db.collection('exam_attempts').where('uid', isEqualTo: uid).get().then(_rows).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    final submitted = r[1].where((a) => a['status'] == 'submitted');
    final subs = <Map<String, dynamic>>[];
    for (final a in submitted) {
      try {
        final d = await _db.collection('exam_submissions').doc('${a['sessionId']}_${a['uid']}').get();
        if (d.exists) subs.add({'id': d.id, ...?d.data()});
      } catch (_) {/* робота могла ще не створитися */}
    }
    return (r[0], bestExam(r[1], subs));
  }

  static User _user() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception('Увійдіть в акаунт');
    return u;
  }

  /// Усе для екрана студента.
  static Future<PracticeData> loadMine() => loadStudent(_user().uid, email: _user().email ?? '');

  /// Свіжі дані одного студента (свої або — для викладача — будь-чиї).
  static Future<PracticeData> loadStudent(String uid, {String email = ''}) async {
    final r = await Future.wait([
      _db.collection(work).doc(uid).get(),
      _db.collection(grades).doc(uid).get(),
      _db.collection('users').doc(uid).get().then((d) => d.data() ?? {}).catchError((_) => <String, dynamic>{}),
    ]);
    final w = (r[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final user = r[2] as Map<String, dynamic>;
    final auto = await _autoSources(uid);
    String pick(String k) => (user[k]?.toString() ?? '').isNotEmpty ? user[k].toString() : (w[k]?.toString() ?? '');
    return PracticeData(
      uid: uid,
      email: email.isNotEmpty ? email : pick('email'),
      work: w,
      grades: _grades(r[1] as DocumentSnapshot<Map<String, dynamic>>),
      ctx: PracticeCtx(fullName: pick('fullName'), group: pick('group'), quizResults: auto.$1, exam: auto.$2),
    );
  }

  /// Зберегти частину роботи (merge) разом з ПІБ і групою, щоб викладач бачив, чия робота.
  static Future<void> saveWork(Map<String, dynamic> patch, {String fullName = '', String group = ''}) async {
    final u = _user();
    await _db.collection(work).doc(u.uid).set({
      ...patch,
      'uid': u.uid, 'email': u.email ?? '', 'fullName': fullName, 'group': group,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String contentTypeOf(String name) => _mime[name.split('.').last.toLowerCase()] ?? '';

  /// Завантажити файл кроку у власну теку; повертає опис для steps[id].files.
  static Future<Map<String, dynamic>> uploadStepFile(String stepId, String name, Uint8List bytes) async {
    final u = _user();
    if (bytes.length > maxFile) throw Exception('Файл «$name» більший за 20 МБ');
    final type = contentTypeOf(name);
    if (type.isEmpty) throw Exception('Формат «$name» не підтримується. Можна фото, PDF, DOC/DOCX, ODT, PPT/PPTX, TXT');
    var safe = name.replaceAll(RegExp(r'[^\p{L}\p{N}._-]+', unicode: true), '_');
    if (safe.length > 80) safe = safe.substring(safe.length - 80);
    final path = 'practice_uploads/${u.uid}/$stepId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: type));
    return {
      'name': name, 'path': path, 'url': await ref.getDownloadURL(), 'size': bytes.length, 'type': type,
      'at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Future<void> deleteStepFile(Map<String, dynamic> meta) async {
    try {
      await FirebaseStorage.instance.ref(meta['path'].toString()).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  // ── Адміністратор ──────────────────────────────────────────────────────────

  /// Усі студенти: роботи, оцінки, профілі (users з групою) — для журналу.
  static Future<List<PracticeData>> loadAll() async {
    Future<List<Map<String, dynamic>>> col(String c, {bool optional = false}) {
      final f = _db.collection(c).get().then(_rows);
      return optional ? f.catchError((_) => <Map<String, dynamic>>[]) : f;
    }

    final r = await Future.wait([
      col(work), col(grades), col('users', optional: true), col('quiz_results', optional: true),
      col('exam_attempts', optional: true), col('exam_submissions', optional: true),
    ]);
    final byUid = <String, ({Map<String, dynamic> work, Map<String, dynamic> grades, String fullName, String group, String email})>{};
    // студенти — ті, хто почав практику, або заповнив групу в «Мої дані»
    for (final u in r[2].where((u) => (u['group']?.toString() ?? '').trim().isNotEmpty)) {
      byUid[u['id']] = (work: {}, grades: {}, fullName: u['fullName']?.toString() ?? '', group: u['group'].toString(), email: u['email']?.toString() ?? '');
    }
    for (final w in r[0]) {
      final s = byUid[w['id']];
      byUid[w['id']] = (
        work: w,
        grades: {},
        fullName: (s?.fullName.isNotEmpty ?? false) ? s!.fullName : w['fullName']?.toString() ?? '',
        group: (s?.fullName.isNotEmpty ?? false) ? s!.group : w['group']?.toString() ?? '',
        email: (s?.email.isNotEmpty ?? false) ? s!.email : w['email']?.toString() ?? '',
      );
    }
    for (final g in r[1]) {
      final s = byUid[g['id']];
      if (s == null) continue;
      byUid[g['id']] = (work: s.work, grades: g['grades'] is Map ? Map<String, dynamic>.from(g['grades']) : {}, fullName: s.fullName, group: s.group, email: s.email);
    }
    final list = byUid.entries.map((e) {
      final s = e.value;
      return PracticeData(
        uid: e.key, email: s.email, work: s.work, grades: s.grades,
        ctx: PracticeCtx(
          fullName: s.fullName, group: s.group,
          quizResults: r[3].where((q) => q['uid'] == e.key).toList(),
          exam: bestExam(r[4].where((a) => a['uid'] == e.key).toList(), r[5].where((x) => x['uid'] == e.key).toList()),
        ),
      );
    }).toList()
      ..sort((a, b) {
        final g = a.group.compareTo(b.group);
        if (g != 0) return g;
        return (a.fullName.isNotEmpty ? a.fullName : a.email).compareTo(b.fullName.isNotEmpty ? b.fullName : b.email);
      });
    return list;
  }

  /// Оцінка кроку: status 'graded' | 'revise' | 'none'.
  static Future<void> saveGrade(String uid, String stepId, {num? points, String comment = '', String status = 'graded'}) async {
    await _db.collection(grades).doc(uid).set({
      'uid': uid,
      'grades': {
        stepId: {
          'points': points, 'comment': comment, 'status': status,
          'gradedAt': FieldValue.serverTimestamp(), 'by': FirebaseAuth.instance.currentUser?.email ?? '',
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
