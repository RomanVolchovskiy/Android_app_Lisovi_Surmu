// ── ТЕМА ────────────────────────────────────────────────────────────────────
class EducationTopic {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final int sortOrder;

  EducationTopic({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'sortOrder': sortOrder,
  };

  factory EducationTopic.fromJson(Map<String, dynamic> json) => EducationTopic(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    imageUrl: json['imageUrl'],
    sortOrder: json['sortOrder'] != null ? (json['sortOrder'] as num).toInt() : 0,
  );
}

// ── НАВЧАЛЬНИЙ МАТЕРІАЛ ──────────────────────────────────────────────────────
enum LearningMaterialType { text, video, presentation, infographic, image, audio }

extension LearningMaterialTypeLabel on LearningMaterialType {
  String get label {
    switch (this) {
      case LearningMaterialType.text:         return 'Текстовий матеріал';
      case LearningMaterialType.video:        return 'Відео матеріал';
      case LearningMaterialType.presentation: return 'Презентаційний матеріал';
      case LearningMaterialType.infographic:  return 'Інфографіка';
      case LearningMaterialType.image:        return 'Зображення';
      case LearningMaterialType.audio:        return 'Аудіо';
    }
  }
}

enum MultimediaType { video, photo, presentation, document }

extension MultimediaTypeLabel on MultimediaType {
  String get label {
    switch (this) {
      case MultimediaType.video:        return 'Відео';
      case MultimediaType.photo:        return 'Фото';
      case MultimediaType.presentation: return 'Презентація';
      case MultimediaType.document:     return 'Документ';
    }
  }
}

class LearningMaterial {
  final String id;
  final String topicId;
  final LearningMaterialType type;
  final String name;
  final String driveUrl;
  final MultimediaType? mediaType;
  final String? thumbnailUrl;

  LearningMaterial({
    required this.id,
    required this.topicId,
    required this.type,
    required this.name,
    required this.driveUrl,
    this.mediaType,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'topicId': topicId,
    'type': type.name,
    'name': name,
    'driveUrl': driveUrl,
    'mediaType': mediaType?.name,
    'thumbnailUrl': thumbnailUrl,
  };

  factory LearningMaterial.fromJson(Map<String, dynamic> json) => LearningMaterial(
    id: json['id']?.toString() ?? '',
    topicId: json['topicId']?.toString() ?? '',
    type: LearningMaterialType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => LearningMaterialType.text,
    ),
    name: json['name']?.toString() ?? '',
    driveUrl: json['driveUrl']?.toString() ?? '',
    mediaType: json['mediaType'] != null
        ? MultimediaType.values.firstWhere(
            (e) => e.name == json['mediaType'],
            orElse: () => MultimediaType.video,
          )
        : null,
    thumbnailUrl: json['thumbnailUrl']?.toString(),
  );
}

// ── ФЛЕШ-КАРТКА ─────────────────────────────────────────────────────────────
class Flashcard {
  final String id;
  final String topicId;
  final String question;
  final String answer;

  Flashcard({
    required this.id,
    required this.topicId,
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'topicId': topicId,
    'question': question,
    'answer': answer,
  };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
    id: json['id']?.toString() ?? '',
    topicId: json['topicId']?.toString() ?? '',
    question: json['question']?.toString() ?? '',
    answer: json['answer']?.toString() ?? '',
  );
}

// ── ІНДИВІДУАЛЬНИЙ ПЛАН КОРИСТУВАЧА ──────────────────────────────────────────
class UserPlan {
  final String id;
  final String name;
  final List<String> theoreticalTopicIds;
  final List<String> practicalTopicIds;
  final int order;

  const UserPlan({
    required this.id,
    required this.name,
    this.theoreticalTopicIds = const [],
    this.practicalTopicIds   = const [],
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'theoreticalTopicIds': theoreticalTopicIds,
        'practicalTopicIds': practicalTopicIds,
        'order': order,
      };

  factory UserPlan.fromJson(Map<String, dynamic> json) => UserPlan(
        id:   json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        theoreticalTopicIds: List<String>.from(json['theoreticalTopicIds'] ?? []),
        practicalTopicIds:   List<String>.from(json['practicalTopicIds'] ?? []),
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}

// ── ЗАПИС ПЛАНУ НАВЧАННЯ ──────────────────────────────────────────────────────
class StudyPlanEntry {
  final String id;
  final String topicId;
  final int order;
  /// Рівень плану: 'basic' | 'standard' | 'professional' | 'expert'
  final String level;
  /// Тип теми: 'theoretical' | 'practical' | 'selfStudy'
  final String topicType;
  /// Кількість годин для тематичного плану
  final int hours;

  StudyPlanEntry({
    required this.id,
    required this.topicId,
    required this.order,
    this.level = '',
    this.topicType = 'theoretical',
    this.hours = 0,
  });

  StudyPlanEntry copyWith({int? order, String? level, String? topicType, int? hours}) =>
      StudyPlanEntry(
          id: id,
          topicId: topicId,
          order: order ?? this.order,
          level: level ?? this.level,
          topicType: topicType ?? this.topicType,
          hours: hours ?? this.hours);

  Map<String, dynamic> toJson() => {
    'id': id, 'topicId': topicId, 'order': order,
    'level': level, 'topicType': topicType, 'hours': hours,
  };

  factory StudyPlanEntry.fromJson(Map<String, dynamic> json) => StudyPlanEntry(
        id:        json['id']?.toString() ?? '',
        topicId:   json['topicId']?.toString() ?? '',
        order:     (json['order'] as num?)?.toInt() ?? 0,
        level:     json['level']?.toString() ?? '',
        topicType: json['topicType']?.toString() ?? 'theoretical',
        hours:     (json['hours'] as num?)?.toInt() ?? 0,
      );
}

// ── ПИТАННЯ ТЕСТУ ────────────────────────────────────────────────────────────
class TestQuestion {
  final String id;
  final String topicId;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  TestQuestion({
    required this.id,
    required this.topicId,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'topicId': topicId,
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };

  factory TestQuestion.fromJson(Map<String, dynamic> json) => TestQuestion(
    id: json['id']?.toString() ?? '',
    topicId: json['topicId']?.toString() ?? '',
    question: json['question']?.toString() ?? '',
    options: List<String>.from(json['options'] ?? []),
    correctIndex: json['correctIndex'] is int
        ? json['correctIndex']
        : int.tryParse(json['correctIndex']?.toString() ?? '0') ?? 0,
    explanation: json['explanation'],
  );
}
