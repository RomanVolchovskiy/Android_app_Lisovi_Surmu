import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunting_signals/models/hunting_models.dart';

class DataPersistenceService {
  static const String _signalsKey = 'admin_signals';
  static const String _educationMaterialsKey = 'admin_education_materials';

  // Save signals to SharedPreferences
  static Future<void> saveSignals(List<HuntingSignal> signals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signalsJson = signals.map((signal) => {
        'id': signal.id,
        'name': signal.name,
        'description': signal.description,
        'category': signal.category,
        'audioUrl': signal.audioUrl,
        'videoUrl': signal.videoUrl,
        'notationUrl': signal.notationUrl,
        'imageUrl': signal.imageUrl,
        'duration': signal.duration,
        'tags': signal.tags,
        'historicalInfo': signal.historicalInfo,
        'usageInstructions': signal.usageInstructions,
        'isFavorite': signal.isFavorite,
      }).toList();
      
      await prefs.setString(_signalsKey, jsonEncode(signalsJson));
    } catch (e) {
      // Handle error silently
    }
  }

  // Load signals from SharedPreferences
  static Future<List<HuntingSignal>> loadSignals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signalsString = prefs.getString(_signalsKey);
      
      if (signalsString != null) {
        final List<dynamic> signalsJson = jsonDecode(signalsString);
        return signalsJson.map((json) => HuntingSignal(
          id: json['id'],
          name: json['name'],
          description: json['description'],
          category: json['category'],
          audioUrl: json['audioUrl'],
          videoUrl: json['videoUrl'],
          notationUrl: json['notationUrl'],
          imageUrl: json['imageUrl'],
          duration: json['duration'] ?? 30,
          tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
          historicalInfo: json['historicalInfo'],
          usageInstructions: json['usageInstructions'],
          isFavorite: json['isFavorite'] ?? false,
        )).toList();
      }
    } catch (e) {
      // Handle error silently
    }
    return [];
  }

  // Save education materials to SharedPreferences
  static Future<void> saveEducationMaterials(List<EducationMaterial> materials) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final materialsJson = materials.map((material) => {
        'id': material.id,
        'title': material.title,
        'description': material.description,
        'type': material.type.name,
        'content': material.content,
        'videoUrl': material.videoUrl,
        'imageUrl': material.imageUrl,
        'category': material.category,
        'difficulty': material.difficulty.name,
        'tags': material.tags,
        'createdAt': material.createdAt.toIso8601String(),
      }).toList();
      
      await prefs.setString(_educationMaterialsKey, jsonEncode(materialsJson));
    } catch (e) {
      // Handle error silently
    }
  }

  // Load education materials from SharedPreferences
  static Future<List<EducationMaterial>> loadEducationMaterials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final materialsString = prefs.getString(_educationMaterialsKey);
      
      if (materialsString != null) {
        final List<dynamic> materialsJson = jsonDecode(materialsString);
        return materialsJson.map((json) => EducationMaterial(
          id: json['id'],
          title: json['title'],
          description: json['description'],
          type: EducationType.values.firstWhere(
            (e) => e.name == json['type'],
            orElse: () => EducationType.article,
          ),
          content: json['content'],
          videoUrl: json['videoUrl'],
          imageUrl: json['imageUrl'],
          category: json['category'],
          difficulty: DifficultyLevel.values.firstWhere(
            (e) => e.name == json['difficulty'],
            orElse: () => DifficultyLevel.beginner,
          ),
          tags: List<String>.from(json['tags'] ?? []),
          createdAt: DateTime.parse(json['createdAt']),
        )).toList();
      }
    } catch (e) {
      // Handle error silently
    }
    return [];
  }

  // Clear all saved data
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_signalsKey);
      await prefs.remove(_educationMaterialsKey);
    } catch (e) {
      // Handle error silently
    }
  }
}