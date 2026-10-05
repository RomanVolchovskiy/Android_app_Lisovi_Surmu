import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunting_signals/models/pokit_models.dart';

/// «Покіт: розкладка здобичі»: довідник видів і налаштування (пише
/// адміністратор), журнал спроб студента. Помилки — до екранів (SnackBar).
class PokitService {
  static final _db = FirebaseFirestore.instance;
  static const _species = 'pokit_species';
  static const _sessions = 'pokit_sessions';
  static DocumentReference<Map<String, dynamic>> get _config => _db.collection('pokit_trainer').doc('config');

  static Future<List<PokitSpecies>> getSpecies() async {
    final snap = await _db.collection(_species).get();
    return snap.docs.map((d) => PokitSpecies.fromJson(d.id, d.data())).toList();
  }

  static Future<PokitConfig> getConfig() async {
    try {
      return PokitConfig.fromJson((await _config.get()).data());
    } catch (_) {
      return const PokitConfig();
    }
  }

  static Future<void> saveConfig(PokitConfig cfg) =>
      _config.set({...cfg.toJson(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  /// Новий вид — повний запис; наявний — merge (не стираємо невідомі поля).
  static Future<void> saveSpecies(PokitSpecies sp, {required bool isNew}) =>
      _db.collection(_species).doc(sp.id).set(sp.toJson(), SetOptions(merge: !isNew));

  static Future<void> setHidden(String id, bool hidden) => _db.collection(_species).doc(id).update({'hidden': hidden});

  static Future<void> deleteSpecies(String id) => _db.collection(_species).doc(id).delete();

  static Future<void> saveSession(List<PokitRoundItem> round, List<PokitSpecies> row, PokitCheck res) async {
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
      'round': [for (final r in round) {'speciesId': r.species.id, 'speciesName': r.species.name, 'count': r.count}],
      'studentOrder': row.map((s) => s.id).toList(),
      'correct': res.correct,
      'total': res.total,
      'percent': res.percent,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Власні спроби, новіші першими (фільтр лише за uid — без індексу).
  static Future<List<PokitSession>> getMySessions() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return [];
    final snap = await _db.collection(_sessions).where('uid', isEqualTo: u.uid).get();
    return snap.docs.map((d) => PokitSession.fromDoc(d.id, d.data())).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  }

  /// Видалення — правила дозволяють лише адміністратору.
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
