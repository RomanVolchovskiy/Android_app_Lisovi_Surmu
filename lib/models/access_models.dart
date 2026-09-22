import 'package:cloud_firestore/cloud_firestore.dart';

/// Тип доступу користувача до додатку.
enum AccessKind {
  /// Корпоративна пошта (домен у [AccessConfig.corporateDomains]) — безлімітно.
  corporate,

  /// Активовано код доступу від адміністратора.
  code,

  /// Пробний період ([AccessConfig.trialDays] днів від першого входу).
  trial,

  /// Пробний період і код вичерпані — потрібен новий код.
  expired,
}

/// Результат перевірки доступу.
class AccessStatus {
  final AccessKind kind;

  /// До якої дати діє доступ (для пробного періоду й кодів із терміном).
  /// `null` для безлімітного доступу.
  final DateTime? until;

  /// `true`, якщо статус узято з локального кешу (немає мережі).
  final bool fromCache;

  const AccessStatus(this.kind, {this.until, this.fromCache = false});

  bool get allowed => kind != AccessKind.expired;

  /// Скільки повних днів лишилось (0, якщо сьогодні останній день).
  int get daysLeft {
    final u = until;
    if (u == null) return -1;
    final diff = u.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return (diff.inHours / 24).ceil();
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'until': until?.millisecondsSinceEpoch,
      };

  static AccessStatus? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final kind = AccessKind.values.cast<AccessKind?>().firstWhere(
          (k) => k!.name == json['kind'],
          orElse: () => null,
        );
    if (kind == null) return null;
    final untilMs = json['until'];
    return AccessStatus(
      kind,
      until: untilMs is int ? DateTime.fromMillisecondsSinceEpoch(untilMs) : null,
      fromCache: true,
    );
  }
}

/// Налаштування доступу (документ `app_access/config`).
class AccessConfig {
  /// Домени корпоративної пошти, для яких додаток безкоштовний.
  final List<String> corporateDomains;

  /// Тривалість пробного періоду для решти користувачів.
  final int trialDays;

  /// Пошти, які можуть керувати кодами й налаштуваннями (правила Firestore).
  final List<String> adminEmails;

  const AccessConfig({
    required this.corporateDomains,
    required this.trialDays,
    required this.adminEmails,
  });

  /// Значення за замовчуванням — використовуються, поки документ у Firestore
  /// не створено або він недоступний.
  static const AccessConfig defaults = AccessConfig(
    corporateDomains: ['forestcollege.ukr.education'],
    trialDays: 30,
    adminEmails: ['volcovskij@forestcollege.ukr.education'],
  );

  factory AccessConfig.fromMap(Map<String, dynamic>? d) {
    if (d == null) return defaults;
    List<String> strings(dynamic v, List<String> fallback) =>
        v is List ? v.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList() : fallback;
    final trial = d['trialDays'];
    return AccessConfig(
      corporateDomains: strings(d['corporateDomains'], defaults.corporateDomains),
      trialDays: trial is num && trial > 0 ? trial.toInt() : defaults.trialDays,
      adminEmails: strings(d['adminEmails'], defaults.adminEmails),
    );
  }

  Map<String, dynamic> toMap() => {
        'corporateDomains': corporateDomains,
        'trialDays': trialDays,
        'adminEmails': adminEmails,
      };

  AccessConfig copyWith({List<String>? corporateDomains, int? trialDays, List<String>? adminEmails}) => AccessConfig(
        corporateDomains: corporateDomains ?? this.corporateDomains,
        trialDays: trialDays ?? this.trialDays,
        adminEmails: adminEmails ?? this.adminEmails,
      );

  /// Чи належить пошта до корпоративного домену.
  bool isCorporate(String? email) {
    final domain = emailDomain(email);
    return domain != null && corporateDomains.contains(domain);
  }

  bool isAdmin(String? email) => email != null && adminEmails.contains(email.trim().toLowerCase());

  static String? emailDomain(String? email) {
    if (email == null) return null;
    final at = email.lastIndexOf('@');
    if (at < 0 || at == email.length - 1) return null;
    return email.substring(at + 1).trim().toLowerCase();
  }
}

/// Код доступу (документ `access_codes/{code}`).
class AccessCode {
  final String code;
  final String note;

  /// Скільки разів код можна активувати; 0 — без обмежень.
  final int maxUses;
  final int usedCount;
  final List<String> usedBy;
  final List<String> usedByEmails;

  /// На скільки днів код дає доступ; `null` — назавжди.
  final int? durationDays;

  /// Після цієї дати код не можна активувати; `null` — без терміну.
  final DateTime? expiresAt;
  final bool active;
  final DateTime? createdAt;

  const AccessCode({
    required this.code,
    this.note = '',
    this.maxUses = 1,
    this.usedCount = 0,
    this.usedBy = const [],
    this.usedByEmails = const [],
    this.durationDays,
    this.expiresAt,
    this.active = true,
    this.createdAt,
  });

  bool get exhausted => maxUses > 0 && usedCount >= maxUses;
  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get usable => active && !exhausted && !expired;

  factory AccessCode.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    List<String> strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];
    final dur = d['durationDays'];
    return AccessCode(
      code: doc.id,
      note: (d['note'] ?? '').toString(),
      maxUses: (d['maxUses'] as num?)?.toInt() ?? 1,
      usedCount: (d['usedCount'] as num?)?.toInt() ?? 0,
      usedBy: strings(d['usedBy']),
      usedByEmails: strings(d['usedByEmails']),
      durationDays: dur is num && dur > 0 ? dur.toInt() : null,
      expiresAt: ts(d['expiresAt']),
      active: d['active'] != false,
      createdAt: ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'note': note,
        'maxUses': maxUses,
        'usedCount': usedCount,
        'usedBy': usedBy,
        'usedByEmails': usedByEmails,
        'durationDays': durationDays,
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
        'active': active,
        'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      };
}

/// Помилка доступу з повідомленням для користувача.
class AccessException implements Exception {
  final String message;
  const AccessException(this.message);
  @override
  String toString() => message;
}
