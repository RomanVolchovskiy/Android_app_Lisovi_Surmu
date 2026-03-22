import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Local storage service as alternative to Firebase
/// Uses SharedPreferences + Hive for complex data + Google Drive for backup
class LocalStorageService {
  static const String _signalsKey = 'hunting_signals';
  static const String _categoriesKey = 'signal_categories';
  static const String _materialsKey = 'educational_materials';
  static const String _settingsKey = 'app_settings';
  
  static bool _isInitialized = false;
  static Box? _hiveBox;

  /// Initialize local storage
  static Future<bool> initialize() async {
    try {
      if (!_isInitialized) {
        // Initialize Hive
        await Hive.initFlutter();
        _hiveBox = await Hive.openBox('hunting_signals_box');
        _isInitialized = true;
      }
      return true;
    } catch (e) {
      debugPrint('Local storage initialization error: $e');
      return false;
    }
  }

  /// Save hunting signals to local storage
  static Future<bool> saveHuntingSignals(List<Map<String, dynamic>> signals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(signals);
      await prefs.setString(_signalsKey, jsonString);
      
      // Also save to Hive for better performance
      if (_hiveBox != null) {
        await _hiveBox!.put(_signalsKey, signals);
      }
      
      debugPrint('Saved ${signals.length} hunting signals to local storage');
      return true;
    } catch (e) {
      debugPrint('Error saving hunting signals: $e');
      return false;
    }
  }

  /// Load hunting signals from local storage
  static Future<List<Map<String, dynamic>>?> loadHuntingSignals() async {
    try {
      // Try Hive first (faster)
      if (_hiveBox != null && _hiveBox!.containsKey(_signalsKey)) {
        final data = _hiveBox!.get(_signalsKey);
        if (data is List) {
          final jsonStr = jsonEncode(data);
          final decoded = jsonDecode(jsonStr) as List;
          return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_signalsKey);
      
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading hunting signals: $e');
      return null;
    }
  }

  /// Save signal categories
  static Future<bool> saveCategories(List<Map<String, dynamic>> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(categories);
      await prefs.setString(_categoriesKey, jsonString);
      
      if (_hiveBox != null) {
        await _hiveBox!.put(_categoriesKey, categories);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error saving categories: $e');
      return false;
    }
  }

  /// Load signal categories
  static Future<List<Map<String, dynamic>>?> loadCategories() async {
    try {
      if (_hiveBox != null && _hiveBox!.containsKey(_categoriesKey)) {
        final data = _hiveBox!.get(_categoriesKey);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_categoriesKey);
      
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading categories: $e');
      return null;
    }
  }

  /// Save educational materials
  static Future<bool> saveEducationalMaterials(List<Map<String, dynamic>> materials) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(materials);
      await prefs.setString(_materialsKey, jsonString);
      
      if (_hiveBox != null) {
        await _hiveBox!.put(_materialsKey, materials);
      }
      
      debugPrint('Saved ${materials.length} educational materials to local storage');
      return true;
    } catch (e) {
      debugPrint('Error saving educational materials: $e');
      return false;
    }
  }

  /// Load educational materials
  static Future<List<Map<String, dynamic>>?> loadEducationalMaterials() async {
    try {
      if (_hiveBox != null && _hiveBox!.containsKey(_materialsKey)) {
        final data = _hiveBox!.get(_materialsKey);
        if (data is List) {
          final jsonStr = jsonEncode(data);
          final decoded = jsonDecode(jsonStr) as List;
          return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_materialsKey);
      
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading educational materials: $e');
      return null;
    }
  }

  /// Save app settings
  static Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings);
      await prefs.setString(_settingsKey, jsonString);
      
      if (_hiveBox != null) {
        await _hiveBox!.put(_settingsKey, settings);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  /// Load app settings
  static Future<Map<String, dynamic>?> loadSettings() async {
    try {
      if (_hiveBox != null && _hiveBox!.containsKey(_settingsKey)) {
        final data = _hiveBox!.get(_settingsKey);
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      
      if (jsonString != null) {
        return Map<String, dynamic>.from(jsonDecode(jsonString));
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return null;
    }
  }

  /// Save single item
  static Future<bool> saveItem(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else {
        // For complex objects, use JSON encoding
        final jsonString = jsonEncode(value);
        await prefs.setString(key, jsonString);
      }
      
      // Also save to Hive
      if (_hiveBox != null) {
        await _hiveBox!.put(key, value);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error saving item $key: $e');
      return false;
    }
  }

  /// Load single item
  static Future<dynamic> loadItem(String key) async {
    try {
      // Try Hive first
      if (_hiveBox != null && _hiveBox!.containsKey(key)) {
        return _hiveBox!.get(key);
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Try different types
      if (prefs.containsKey(key)) {
        final value = prefs.get(key);
        
        // Try to decode JSON if it's a string
        if (value is String) {
          try {
            return jsonDecode(value);
          } catch (_) {
            return value; // It's just a string
          }
        }
        
        return value;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error loading item $key: $e');
      return null;
    }
  }

  /// Delete item
  static Future<bool> deleteItem(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      
      if (_hiveBox != null) {
        await _hiveBox!.delete(key);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting item $key: $e');
      return false;
    }
  }

  /// Clear all data
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (_hiveBox != null) {
        await _hiveBox!.clear();
      }
      
      debugPrint('Cleared all local storage data');
      return true;
    } catch (e) {
      debugPrint('Error clearing storage: $e');
      return false;
    }
  }

  /// Get storage info
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int totalSize = 0;
      for (final key in keys) {
        final value = prefs.get(key);
        if (value is String) {
          totalSize += value.length;
        }
      }
      
      return {
        'itemCount': keys.length,
        'totalSize': totalSize,
        'hiveBox': _hiveBox != null ? 'initialized' : 'not initialized',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Create backup file
  static Future<String?> createBackupFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupData = <String, dynamic>{};
      
      // Collect all data
      for (final key in prefs.getKeys()) {
        backupData[key] = prefs.get(key);
      }
      
      // Add Hive data
      if (_hiveBox != null) {
        for (final key in _hiveBox!.keys) {
          backupData['hive_$key'] = _hiveBox!.get(key);
        }
      }
      
      // Create backup file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/hunting_signals_backup_$timestamp.json');
      
      await file.writeAsString(jsonEncode(backupData));
      
      debugPrint('Backup file created: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error creating backup file: $e');
      return null;
    }
  }

  /// Restore from backup file
  static Future<bool> restoreFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final content = await file.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;
      
      // Clear existing data
      await clearAll();
      
      // Restore data
      for (final entry in backupData.entries) {
        await saveItem(entry.key, entry.value);
      }
      
      debugPrint('Successfully restored from backup file: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error restoring from file: $e');
      return false;
    }
  }
}