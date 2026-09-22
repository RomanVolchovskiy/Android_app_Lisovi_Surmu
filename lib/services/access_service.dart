import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/access_models.dart';

/// Вхід у додаток і перевірка права користуватися ним.
///
/// Правила:
/// * пошта з корпоративного домену (`app_access/config.corporateDomains`) —
///   безкоштовно й без обмежень;
/// * решта — пробний період `trialDays` від першого входу; дата першого
///   входу зберігається у `users/{uid}.createdAt` серверним часом, тож
///   перевстановлення додатку чи зміна годинника її не скидають;
/// * код доступу (`access_codes/{code}`), який створює адміністратор, дає
///   доступ назавжди або на `durationDays`.
///
/// Результат останньої перевірки кешується в SharedPreferences, щоб додаток
/// відкривався без мережі.
class AccessService {
  AccessService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const _cacheKey = 'access_status_v1';
  static const _configDocPath = 'app_access/config';

  /// Поточний статус доступу; `null` — ще не перевірено.
  static final ValueNotifier<AccessStatus?> status = ValueNotifier(null);

  static AccessConfig _config = AccessConfig.defaults;
  static AccessConfig get config => _config;

  /// Зсув між серверним і локальним часом (сервер − пристрій).
  static Duration _serverOffset = Duration.zero;
  static DateTime get serverNow => DateTime.now().add(_serverOffset);

  // ── Автентифікація ─────────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authChanges => _auth.userChanges();

  static Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AccessException(describeAuthError(e));
    }
  }

  /// Реєстрація з надсиланням листа для підтвердження пошти.
  static Future<void> register(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AccessException(describeAuthError(e));
    }
  }

  static Future<void> sendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AccessException(describeAuthError(e));
    }
  }

  /// Перечитує користувача з сервера (після підтвердження пошти).
  static Future<bool> reloadVerified() async {
    final u = _auth.currentUser;
    if (u == null) return false;
    try {
      await u.reload();
    } catch (_) {
      return false;
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AccessException(describeAuthError(e));
    }
  }

  static Future<void> signOut() async {
    status.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await _auth.signOut();
  }

  static String describeAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Некоректна адреса пошти';
      case 'user-disabled':
        return 'Обліковий запис заблоковано';
      case 'user-not-found':
        return 'Користувача з такою поштою не знайдено';
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Неправильна пошта або пароль';
      case 'email-already-in-use':
        return 'Ця пошта вже зареєстрована — увійдіть';
      case 'weak-password':
        return 'Пароль надто простий (мінімум 6 символів)';
      case 'too-many-requests':
        return 'Забагато спроб. Спробуйте пізніше';
      case 'network-request-failed':
        return 'Немає з’єднання з інтернетом';
      case 'operation-not-allowed':
        return 'Вхід за поштою не ввімкнено у Firebase (Authentication → Sign-in method → Email/Password)';
      default:
        return e.message ?? 'Помилка входу (${e.code})';
    }
  }

  // ── Налаштування ───────────────────────────────────────────────────────────

  static Future<AccessConfig> loadConfig({bool fromServer = false}) async {
    try {
      final snap = await _db.doc(_configDocPath).get(
            fromServer ? const GetOptions(source: Source.server) : const GetOptions(),
          );
      _config = AccessConfig.fromMap(snap.data());
    } catch (e) {
      debugPrint('AccessService: config unavailable, using defaults: $e');
    }
    return _config;
  }

  static Future<void> saveConfig(AccessConfig cfg) async {
    await _db.doc(_configDocPath).set(cfg.toMap(), SetOptions(merge: true));
    _config = cfg;
  }

  // ── Перевірка доступу ──────────────────────────────────────────────────────

  /// Перевіряє доступ поточного користувача й оновлює [status].
  static Future<AccessStatus> resolve() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      return _publish(const AccessStatus(AccessKind.expired));
    }
    try {
      final result = await _resolveOnline(user);
      await _writeCache(user.uid, result);
      return _publish(result);
    } catch (e) {
      debugPrint('AccessService: online check failed: $e');
      final cached = await _readCache(user.uid);
      if (cached != null) {
        // Кешований пробний період чи код із терміном перевіряємо за
        // годинником пристрою — краще, ніж не пустити зовсім.
        if (cached.until != null && cached.until!.isBefore(DateTime.now())) {
          return _publish(AccessStatus(AccessKind.expired, until: cached.until, fromCache: true));
        }
        return _publish(cached);
      }
      throw const AccessException('Не вдалося перевірити доступ. Перевірте з’єднання з інтернетом');
    }
  }

  static Future<AccessStatus> _resolveOnline(User user) async {
    await loadConfig();
    final email = user.email?.trim().toLowerCase();
    if (_config.isCorporate(email) || _config.isAdmin(email)) {
      // Корпоративним теж заводимо запис — щоб бачити, хто користується;
      // без мережі це не заважає входу.
      try {
        await _touchUser(user, needRead: false);
      } catch (_) {}
      return const AccessStatus(AccessKind.corporate);
    }

    final data = await _touchUser(user, needRead: true);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final lastSeen = (data['lastSeenAt'] as Timestamp?)?.toDate();
    if (lastSeen != null) _serverOffset = lastSeen.difference(DateTime.now());
    final now = serverNow;

    if (data['accessType'] == 'code') {
      final until = (data['accessUntil'] as Timestamp?)?.toDate();
      if (until == null) return const AccessStatus(AccessKind.code);
      if (until.isAfter(now)) return AccessStatus(AccessKind.code, until: until);
    }

    final start = createdAt ?? now;
    final trialEnd = start.add(Duration(days: _config.trialDays));
    if (trialEnd.isAfter(now)) return AccessStatus(AccessKind.trial, until: trialEnd);
    return AccessStatus(AccessKind.expired, until: trialEnd);
  }

  /// Створює `users/{uid}` при першому вході або оновлює `lastSeenAt`;
  /// повертає актуальні дані з сервера (серверні мітки часу).
  static Future<Map<String, dynamic>> _touchUser(User user, {required bool needRead}) async {
    final ref = _db.collection('users').doc(user.uid);
    final email = user.email?.trim().toLowerCase() ?? '';
    final snap = await ref.get(const GetOptions(source: Source.server));
    if (!snap.exists) {
      await ref.set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'accessType': 'trial',
      });
    } else {
      await ref.update({'email': email, 'lastSeenAt': FieldValue.serverTimestamp()});
    }
    if (!needRead) return const {};
    final fresh = await ref.get(const GetOptions(source: Source.server));
    return fresh.data() ?? {};
  }

  static AccessStatus _publish(AccessStatus s) {
    status.value = s;
    return s;
  }

  static Future<void> _writeCache(String uid, AccessStatus s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({'uid': uid, ...s.toJson()}));
    } catch (_) {}
  }

  static Future<AccessStatus?> _readCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['uid'] != uid) return null;
      return AccessStatus.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // ── Коди доступу ───────────────────────────────────────────────────────────

  /// Символи без схожих (0/O, 1/I/L).
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generateCode([int length = 8]) {
    final rnd = Random.secure();
    return List.generate(length, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
  }

  static String normalizeCode(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

  /// Активує код для поточного користувача (транзакція: лічильник коду +
  /// запис користувача змінюються разом).
  static Future<AccessStatus> redeemCode(String raw) async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) throw const AccessException('Спочатку увійдіть у додаток');
    final code = normalizeCode(raw);
    if (code.isEmpty) throw const AccessException('Введіть код');

    final codeRef = _db.collection('access_codes').doc(code);
    final userRef = _db.collection('users').doc(user.uid);
    final email = user.email?.trim().toLowerCase() ?? '';

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(codeRef);
        if (!snap.exists) throw const AccessException('Код не знайдено');
        final c = AccessCode.fromDoc(snap);
        final now = serverNow;
        if (!c.active) throw const AccessException('Код деактивовано адміністратором');
        if (c.expiresAt != null && c.expiresAt!.isBefore(now)) throw const AccessException('Термін дії коду минув');
        final already = c.usedBy.contains(user.uid);
        if (!already && c.exhausted) throw const AccessException('Код уже використано максимальну кількість разів');

        if (!already) {
          tx.update(codeRef, {
            'usedCount': FieldValue.increment(1),
            'usedBy': FieldValue.arrayUnion([user.uid]),
            'usedByEmails': FieldValue.arrayUnion([email]),
          });
        }
        final until = c.durationDays == null ? null : now.add(Duration(days: c.durationDays!));
        tx.set(userRef, {
          'email': email,
          'accessType': 'code',
          'codeId': code,
          'codeActivatedAt': FieldValue.serverTimestamp(),
          'accessUntil': until == null ? null : Timestamp.fromDate(until),
        }, SetOptions(merge: true));
      });
    } on AccessException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AccessException('Код відхилено правилами доступу. Зверніться до адміністратора');
      }
      throw AccessException('Не вдалося активувати код: ${e.message ?? e.code}');
    }
    return resolve();
  }

  // ── Адміністрування кодів ──────────────────────────────────────────────────

  static Stream<List<AccessCode>> codesStream() => _db
      .collection('access_codes')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AccessCode.fromDoc).toList());

  static Future<void> createCode(AccessCode code) async {
    final ref = _db.collection('access_codes').doc(code.code);
    if ((await ref.get()).exists) throw AccessException('Код ${code.code} уже існує');
    await ref.set(code.toMap());
  }

  static Future<void> setCodeActive(String code, bool active) =>
      _db.collection('access_codes').doc(code).update({'active': active});

  static Future<void> deleteCode(String code) => _db.collection('access_codes').doc(code).delete();
}
