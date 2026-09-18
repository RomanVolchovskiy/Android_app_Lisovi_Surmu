import 'package:flutter/material.dart';

// --- КЛАС СИГНАЛУ ---
class HuntingSignal {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? audioUrl;
  final String? videoUrl;
  final String? videoUrl2;
  final String? notationUrl;
  final String? notationAudioUrl;
  final String? imageUrl;
  final List<String>? galleryImages;
  final int duration;
  final List<String>? tags;
  final String? historicalInfo;
  final String? usageInstructions;
  final bool isFavorite;
  final String? difficulty;
  final String? signalText;
  final List<Map<String, dynamic>>? notationData;
  final int? notationTempo;
  final int sortOrder;
  final String? partitureUrl;

  HuntingSignal({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.audioUrl,
    this.videoUrl,
    this.videoUrl2,
    this.notationUrl,
    this.notationAudioUrl,
    this.imageUrl,
    this.galleryImages,
    required this.duration,
    this.tags,
    this.historicalInfo,
    this.usageInstructions,
    this.isFavorite = false,
    this.difficulty,
    this.signalText,
    this.notationData,
    this.notationTempo,
    this.sortOrder = 0,
    this.partitureUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'audioUrl': audioUrl,
    'videoUrl': videoUrl,
    'videoUrl2': videoUrl2,
    'notationUrl': notationUrl,
    'notationAudioUrl': notationAudioUrl,
    'imageUrl': imageUrl,
    'galleryImages': galleryImages,
    'duration': duration,
    'tags': tags,
    'historicalInfo': historicalInfo,
    'usageInstructions': usageInstructions,
    'isFavorite': isFavorite,
    'difficulty': difficulty,
    'signalText': signalText,
    'notationData': notationData,
    'notationTempo': notationTempo,
    'sortOrder': sortOrder,
    'partitureUrl': partitureUrl,
  };

  factory HuntingSignal.fromJson(Map<String, dynamic> json) => HuntingSignal(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    audioUrl: json['audioUrl'],
    videoUrl: json['videoUrl'],
    videoUrl2: json['videoUrl2'],
    notationUrl: json['notationUrl'],
    notationAudioUrl: json['notationAudioUrl'],
    imageUrl: json['imageUrl'],
    galleryImages: json['galleryImages'] != null
        ? List<String>.from(json['galleryImages'])
        : null,
    duration: json['duration'] is int
        ? json['duration']
        : int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
    tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    historicalInfo: json['historicalInfo'],
    usageInstructions: json['usageInstructions'],
    isFavorite: json['isFavorite'] ?? false,
    difficulty: json['difficulty'],
    signalText: json['signalText'],
    notationData: json['notationData'] != null
        ? List<Map<String, dynamic>>.from(
            (json['notationData'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : null,
    notationTempo: json['notationTempo'] != null
        ? (json['notationTempo'] as num).toInt()
        : null,
    sortOrder: json['sortOrder'] != null
        ? (json['sortOrder'] as num).toInt()
        : 0,
    partitureUrl: json['partitureUrl'],
  );

  HuntingSignal copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? audioUrl,
    String? videoUrl,
    String? videoUrl2,
    String? notationUrl,
    String? notationAudioUrl,
    String? imageUrl,
    List<String>? galleryImages,
    int? duration,
    List<String>? tags,
    String? historicalInfo,
    String? usageInstructions,
    bool? isFavorite,
    String? difficulty,
    String? signalText,
    List<Map<String, dynamic>>? notationData,
    int? notationTempo,
    int? sortOrder,
    String? partitureUrl,
  }) {
    return HuntingSignal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      videoUrl2: videoUrl2 ?? this.videoUrl2,
      notationUrl: notationUrl ?? this.notationUrl,
      notationAudioUrl: notationAudioUrl ?? this.notationAudioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      duration: duration ?? this.duration,
      tags: tags ?? this.tags,
      historicalInfo: historicalInfo ?? this.historicalInfo,
      usageInstructions: usageInstructions ?? this.usageInstructions,
      isFavorite: isFavorite ?? this.isFavorite,
      difficulty: difficulty ?? this.difficulty,
      signalText: signalText ?? this.signalText,
      notationData: notationData ?? this.notationData,
      notationTempo: notationTempo ?? this.notationTempo,
      sortOrder: sortOrder ?? this.sortOrder,
      partitureUrl: partitureUrl ?? this.partitureUrl,
    );
  }
}

// --- КЛАС КАТЕГОРІЇ (ТОЙ, ЩО БУВ ВІДСУТНІЙ) ---
class SignalCategory {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color color;

  SignalCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  // Додамо toJson/fromJson на випадок, якщо захочете зберігати і категорії теж
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'color': color.toARGB32(),
  };

  factory SignalCategory.fromJson(Map<String, dynamic> json) => SignalCategory(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    icon: json['icon']?.toString() ?? 'info',
    color: Color(
      json['color'] is int
          ? json['color']
          : int.parse(json['color']?.toString() ?? '0xFF000000'),
    ),
  );
}

// --- НАВЧАЛЬНІ МАТЕРІАЛИ ---
class EducationMaterial {
  final String id;
  final String title;
  final String description;
  final EducationType type;
  final String content;
  final String? videoUrl;
  final String? imageUrl;
  final String category;
  final DifficultyLevel difficulty;
  final List<String> tags;
  final DateTime createdAt;

  EducationMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.content,
    this.videoUrl,
    this.imageUrl,
    required this.category,
    required this.difficulty,
    required this.tags,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'content': content,
    'videoUrl': videoUrl,
    'imageUrl': imageUrl,
    'category': category,
    'difficulty': difficulty.name,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
  };

  factory EducationMaterial.fromJson(Map<String, dynamic> json) =>
      EducationMaterial(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        type: EducationType.values.byName(json['type'] ?? 'article'),
        content: json['content']?.toString() ?? '',
        videoUrl: json['videoUrl'],
        imageUrl: json['imageUrl'],
        category: json['category']?.toString() ?? '',
        difficulty: DifficultyLevel.values.byName(
          json['difficulty'] ?? 'beginner',
        ),
        tags: List<String>.from(json['tags'] ?? []),
        createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String(),
        ),
      );
}

enum EducationType { article, video, audio, interactive }

enum DifficultyLevel { beginner, intermediate, advanced }
