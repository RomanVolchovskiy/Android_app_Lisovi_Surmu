import 'package:cloud_firestore/cloud_firestore.dart';

// Дихальна гімнастика: ті самі колекції й поля, що на сайті
// (site/js/views/trainer-breathing.js, admin-breathing.js).

const breathingCategories = {
  'relaxation': 'Розслаблення',
  'diaphragm': 'Діафрагмальне дихання',
  'endurance': 'Витривалість',
  'pre_performance': 'Перед виступом',
};
const breathingLevels = {
  'beginner': 'Початковий',
  'intermediate': 'Середній',
  'advanced': 'Просунутий',
};
const breathingPhaseTypes = {
  'inhale': 'Вдих',
  'hold': 'Затримка',
  'exhale': 'Видих',
  'pause': 'Пауза',
};

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// Фаза блоку. cycle: [seconds]; endurance: [targetMin]–[targetMax].
/// Поля змінні — їх редагує форма адмін-панелі.
class BreathingPhase {
  String type;
  double seconds;
  double targetMin;
  double targetMax;
  String label;
  String sound;

  BreathingPhase({
    this.type = 'exhale',
    this.seconds = 4,
    this.targetMin = 15,
    this.targetMax = 20,
    this.label = '',
    this.sound = '',
  });

  factory BreathingPhase.fromJson(Map<String, dynamic> j) => BreathingPhase(
        type: j['type']?.toString() ?? 'exhale',
        seconds: _num(j['seconds']),
        targetMin: _num(j['targetMinSeconds']),
        targetMax: _num(j['targetMaxSeconds']),
        label: j['label']?.toString() ?? '',
        sound: j['sound']?.toString() ?? '',
      );

  Map<String, dynamic> toJson(String kind) => kind == 'endurance'
      ? {
          'type': 'exhale',
          'targetMinSeconds': targetMin,
          'targetMaxSeconds': targetMax,
          'label': label.trim(),
          if (sound.trim().isNotEmpty) 'sound': sound.trim(),
        }
      : {
          'type': type,
          'seconds': seconds,
          'label': label.trim(),
          if (type == 'exhale' && sound.trim().isNotEmpty) 'sound': sound.trim(),
        };

  BreathingPhase copy() => BreathingPhase(
      type: type, seconds: seconds, targetMin: targetMin, targetMax: targetMax, label: label, sound: sound);
}

class BreathingBlock {
  String label;
  String kind; // 'cycle' | 'endurance'
  int repeats;
  double restBetweenReps;
  List<BreathingPhase> phases;

  BreathingBlock({
    this.label = '',
    this.kind = 'cycle',
    this.repeats = 1,
    this.restBetweenReps = 0,
    List<BreathingPhase>? phases,
  }) : phases = phases ?? [];

  bool get isEndurance => kind == 'endurance';

  factory BreathingBlock.cycle() => BreathingBlock(label: 'Цикл', kind: 'cycle', repeats: 4, restBetweenReps: 2, phases: [
        BreathingPhase(type: 'inhale', seconds: 4, label: 'Вдих носом'),
        BreathingPhase(type: 'hold', seconds: 2, label: 'Затримка'),
        BreathingPhase(type: 'exhale', seconds: 8, label: 'Видих'),
      ]);

  factory BreathingBlock.endurance() => BreathingBlock(
      label: 'Рівномірний видих', kind: 'endurance', repeats: 3, restBetweenReps: 5,
      phases: [BreathingPhase(type: 'exhale', targetMin: 15, targetMax: 20, label: 'Рівномірний видих')]);

  factory BreathingBlock.fromJson(Map<String, dynamic> j) => BreathingBlock(
        label: j['label']?.toString() ?? '',
        kind: j['kind'] == 'endurance' ? 'endurance' : 'cycle',
        repeats: _num(j['repeats']).round().clamp(1, 999),
        restBetweenReps: _num(j['restBetweenReps']),
        phases: ((j['phases'] as List?) ?? [])
            .whereType<Map>()
            .map((p) => BreathingPhase.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'label': label.trim(),
        'kind': kind,
        'repeats': repeats < 1 ? 1 : repeats,
        'restBetweenReps': restBetweenReps,
        'phases': (isEndurance ? phases.take(1) : phases).map((p) => p.toJson(kind)).toList(),
      };

  BreathingBlock copy() => BreathingBlock(
      label: label, kind: kind, repeats: repeats, restBetweenReps: restBetweenReps,
      phases: phases.map((p) => p.copy()).toList());

  /// «Цикл (4–2–8 с) — 4 раз(и)» / «Видих — 4 раз(и), ціль 15–20 с».
  String describe() {
    if (isEndurance) {
      final p = phases.isNotEmpty ? phases.first : BreathingPhase();
      return '${label.isEmpty ? 'Витривалість видиху' : label} — $repeats раз(и), ціль ${fmtSec(p.targetMin)}–${fmtSec(p.targetMax)} с';
    }
    return '${label.isEmpty ? 'Цикл' : label} (${phases.map((p) => fmtSec(p.seconds)).join('–')} с) — $repeats раз(и)';
  }

  /// Тривалість блоку, с (endurance — середина цілі).
  double get estimateSeconds {
    final one = isEndurance
        ? phases.fold<double>(0, (s, p) => s + (p.targetMin + p.targetMax) / 2)
        : phases.fold<double>(0, (s, p) => s + p.seconds);
    return one * repeats + restBetweenReps * (repeats - 1);
  }
}

class BreathingExercise {
  final String id;
  String title;
  String description;
  String category;
  String level;
  bool hidden;
  int sortOrder;
  List<BreathingBlock> blocks;

  BreathingExercise({
    required this.id,
    this.title = '',
    this.description = '',
    this.category = 'diaphragm',
    this.level = 'beginner',
    this.hidden = false,
    this.sortOrder = 0,
    List<BreathingBlock>? blocks,
  }) : blocks = blocks ?? [];

  factory BreathingExercise.fromJson(String docId, Map<String, dynamic> j) => BreathingExercise(
        id: (j['id']?.toString().isNotEmpty ?? false) ? j['id'].toString() : docId,
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        category: j['category']?.toString() ?? 'diaphragm',
        level: j['level']?.toString() ?? 'beginner',
        hidden: j['hidden'] == true,
        sortOrder: _num(j['sortOrder']).round(),
        blocks: ((j['blocks'] as List?) ?? [])
            .whereType<Map>()
            .map((b) => BreathingBlock.fromJson(Map<String, dynamic>.from(b)))
            .toList(),
      );

  /// Поля, які пише форма (createdAt/createdBy додає сервіс для нових).
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'level': level,
        'hidden': hidden,
        'sortOrder': sortOrder,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  BreathingExercise copy() => BreathingExercise(
      id: id, title: title, description: description, category: category, level: level,
      hidden: hidden, sortOrder: sortOrder, blocks: blocks.map((b) => b.copy()).toList());

  int get estimateSeconds => blocks.fold<double>(0, (s, b) => s + b.estimateSeconds).round();
}

/// Результат одного повтору endurance-блоку.
class EnduranceResult {
  final String blockLabel;
  final int repeatIndex;
  final double achievedSeconds;
  final bool inTarget;
  const EnduranceResult(this.blockLabel, this.repeatIndex, this.achievedSeconds, this.inTarget);

  Map<String, dynamic> toJson() => {
        'blockLabel': blockLabel,
        'repeatIndex': repeatIndex,
        'achievedSeconds': achievedSeconds,
        'inTarget': inTarget,
      };
}

/// Запис журналу breathing_sessions (для «Моїх результатів»).
class BreathingSession {
  final String docId;
  final String exerciseTitle;
  final int blocksCompleted;
  final int blocksTotal;
  final int enduranceTotal;
  final int enduranceInTarget;
  final DateTime? createdAt;

  const BreathingSession({
    required this.docId,
    required this.exerciseTitle,
    required this.blocksCompleted,
    required this.blocksTotal,
    required this.enduranceTotal,
    required this.enduranceInTarget,
    this.createdAt,
  });

  factory BreathingSession.fromDoc(String id, Map<String, dynamic> j) {
    final results = ((j['enduranceResults'] as List?) ?? []).whereType<Map>().toList();
    return BreathingSession(
      docId: id,
      exerciseTitle: j['exerciseTitle']?.toString() ?? '',
      blocksCompleted: _num(j['blocksCompleted']).round(),
      blocksTotal: _num(j['blocksTotal']).round(),
      enduranceTotal: results.length,
      enduranceInTarget: results.where((r) => r['inTarget'] == true).length,
      createdAt: (j['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

String fmtSec(double s) => s == s.roundToDouble() ? s.round().toString() : s.toStringAsFixed(1);

String fmtDuration(int sec) => sec >= 60
    ? '${sec ~/ 60} хв${sec % 60 > 0 ? ' ${sec % 60} с' : ''}'
    : '$sec с';
