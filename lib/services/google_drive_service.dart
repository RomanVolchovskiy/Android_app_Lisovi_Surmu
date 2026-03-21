import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Drive service — спільна база для всіх користувачів.
///
/// Схема:
/// - Адмін логіниться і зберігає дані у свій Drive (публічний файл)
/// - Всі користувачі читають з цього публічного файлу без логіну
class GoogleDriveService {
  static const String _fileIdKey = 'drive_data_file_id';
  static const String _signedInKey = 'google_drive_signed_in';
  static const String _fileName = 'hunting_signals_data.json';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  static drive.DriveApi? _driveApi;

  // ─── АВТОРИЗАЦІЯ ───────────────────────────────────────────────

  static Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      return await _initDriveApi();
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return false;
    }
  }

  static Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;
      return await _initDriveApi();
    } catch (e) {
      debugPrint('Silent sign-in error: $e');
      return false;
    }
  }

  static Future<bool> _initDriveApi() async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return false;
      _driveApi = drive.DriveApi(client);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_signedInKey, true);
      return true;
    } catch (e) {
      debugPrint('Drive API init error: $e');
      return false;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signedInKey, false);
  }

  static Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_signedInKey) ?? false;
  }

  static Future<bool> initialize() async {
    final signedIn = await isSignedIn();
    if (signedIn) return await signInSilently();
    return false;
  }

  // ─── ЗБЕРЕЖЕННЯ (тільки адмін) ─────────────────────────────────

  /// Зберігає дані у Google Drive і робить файл публічним.
  /// Повертає fileId.
  static Future<String?> saveData(Map<String, dynamic> data) async {
    if (_driveApi == null) {
      final ok = await signInSilently();
      if (!ok) return null;
    }

    try {
      final jsonBytes = utf8.encode(jsonEncode(data));
      final prefs = await SharedPreferences.getInstance();
      final existingId = prefs.getString(_fileIdKey);

      String fileId;

      if (existingId != null) {
        // Оновлюємо існуючий файл
        await _driveApi!.files.update(
          drive.File(),
          existingId,
          uploadMedia: drive.Media(
            Stream.value(jsonBytes),
            jsonBytes.length,
          ),
        );
        fileId = existingId;
        debugPrint('Drive: файл оновлено ($fileId)');
      } else {
        // Створюємо новий файл
        final file = drive.File()
          ..name = _fileName
          ..mimeType = 'application/json';

        final result = await _driveApi!.files.create(
          file,
          uploadMedia: drive.Media(
            Stream.value(jsonBytes),
            jsonBytes.length,
          ),
        );
        fileId = result.id!;
        await prefs.setString(_fileIdKey, fileId);
        debugPrint('Drive: новий файл створено ($fileId)');
      }

      // Робимо файл публічним (читання без авторизації)
      await _driveApi!.permissions.create(
        drive.Permission()
          ..role = 'reader'
          ..type = 'anyone',
        fileId,
      );

      // Зберігаємо fileId локально для всіх користувачів
      await prefs.setString(_fileIdKey, fileId);

      return fileId;
    } catch (e) {
      debugPrint('Drive save error: $e');
      return null;
    }
  }

  // ─── ЗАВАНТАЖЕННЯ (всі користувачі, без логіну) ────────────────

  /// Завантажує дані з публічного файлу Drive.
  /// Не потребує авторизації якщо файл публічний.
  static Future<Map<String, dynamic>?> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fileId = prefs.getString(_fileIdKey);

      if (fileId == null) {
        debugPrint('Drive: fileId не знайдено');
        return null;
      }

      // Публічний URL для завантаження без авторизації
      final url = Uri.parse(
        'https://drive.google.com/uc?export=download&id=$fileId',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Drive: дані завантажено успішно');
        return data;
      } else {
        debugPrint('Drive: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Drive load error: $e');
      return null;
    }
  }

  // ─── ЗБЕРЕЖЕННЯ FILE_ID ────────────────────────────────────────

  /// Зберегти fileId вручну (для розповсюдження між пристроями)
  static Future<void> setFileId(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fileIdKey, fileId);
  }

  static Future<String?> getFileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fileIdKey);
  }

  // ─── LEGACY методи (для сумісності з StorageManager) ───────────

  static Future<bool> saveHuntingSignals(Map<String, dynamic> data) async {
    final id = await saveData(data);
    return id != null;
  }

  static Future<Map<String, dynamic>?> loadHuntingSignals() async {
    return await loadData();
  }

  static Future<bool> createBackup() async {
    return true;
  }

  static Future<bool> restoreFromBackup() async {
    return true;
  }

  static Future<String> getStorageInfo() async {
    final fileId = await getFileId();
    return fileId != null ? 'File ID: $fileId' : 'Не підключено';
  }
}
