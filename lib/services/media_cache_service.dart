import 'dart:io' if (dart.library.html) 'package:hunting_signals/stubs/dart_io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunting_signals/models/hunting_models.dart';

class MediaCacheService {
  static const String _prefsKey = 'media_cache_v1';

  static Future<Directory> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/media_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Повертає локальний шлях до аудіо (якщо закешований), інакше null
  static Future<String?> getLocalAudioPath(String url) async {
    if (kIsWeb) return null;
    final fileName = _fileNameFor(url);
    final dir = await _cacheDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists() && (await file.length()) > 1024) return file.path;
    return null;
  }

  /// Завантажує аудіо у постійний кеш і повертає локальний шлях
  static Future<String> downloadAudio(String url) async {
    // На вебі файлового кешу немає — віддаємо прямий URL на завантаження,
    // щоб його можна було програти через UrlSource.
    if (kIsWeb) return toAudioDownloadUrl(url);
    final downloadUrl = toAudioDownloadUrl(url);
    final fileName = _fileNameFor(downloadUrl);
    final dir = await _cacheDir();
    final file = File('${dir.path}/$fileName');

    if (await file.exists() && (await file.length()) > 1024) {
      debugPrint('MediaCache: audio from cache ${file.path}');
      return file.path;
    }

    debugPrint('MediaCache: downloading audio $downloadUrl');
    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/html')) {
      throw Exception('Google Drive повернув HTML. Файл має бути публічним.');
    }
    if (response.bodyBytes.length < 1024) {
      throw Exception('Файл занадто малий — можливо, не аудіо.');
    }
    await file.writeAsBytes(response.bodyBytes);
    debugPrint('MediaCache: saved ${file.path} (${response.bodyBytes.length} bytes)');
    return file.path;
  }

  /// Попереднє завантаження всіх аудіо та нотацій сигналів у фоні
  static Future<void> preloadSignals(List<HuntingSignal> signals) async {
    if (kIsWeb) return; // На вебі кешування файлів не підтримується
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList(_prefsKey) ?? [];

    for (final signal in signals) {
      // Аудіо
      final audioUrl = signal.audioUrl;
      if (audioUrl != null && audioUrl.isNotEmpty && !cached.contains(audioUrl)) {
        try {
          await downloadAudio(audioUrl);
          cached.add(audioUrl);
          await prefs.setStringList(_prefsKey, cached);
        } catch (e) {
          debugPrint('MediaCache: failed to preload audio for ${signal.name}: $e');
        }
      }

      // Нотація (тільки зображення, не PDF)
      final notationUrl = signal.notationUrl;
      if (notationUrl != null &&
          notationUrl.isNotEmpty &&
          !notationUrl.toLowerCase().endsWith('.pdf') &&
          !notationUrl.startsWith('assets/') &&
          !cached.contains('notation_$notationUrl')) {
        try {
          await downloadNotation(notationUrl);
          cached.add('notation_$notationUrl');
          await prefs.setStringList(_prefsKey, cached);
        } catch (e) {
          debugPrint('MediaCache: failed to preload notation for ${signal.name}: $e');
        }
      }
    }
    debugPrint('MediaCache: preload complete');
  }

  /// Перевіряє чи є URL посиланням на YouTube
  static bool isYouTubeUrl(String url) {
    return url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/shorts/') ||
        url.contains('youtube.com/embed/') ||
        url.contains('m.youtube.com/watch');
  }

  /// Витягує YouTube video ID з будь-якого формату URL
  static String? extractYouTubeId(String url) {
    // youtu.be/ID
    final m1 = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m1 != null) return m1.group(1);
    // youtube.com/shorts/ID
    final m2 = RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m2 != null) return m2.group(1);
    // youtube.com/embed/ID
    final m3 = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m3 != null) return m3.group(1);
    // youtube.com/watch?v=ID or m.youtube.com/watch?v=ID
    final m4 = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m4 != null) return m4.group(1);
    return null;
  }

  /// Конвертує будь-який YouTube URL в embed URL для WebView
  static String? toYouTubeEmbedUrl(String url) {
    final id = extractYouTubeId(url);
    if (id == null) return null;
    return 'https://www.youtube.com/embed/$id?playsinline=1&rel=0';
  }

  /// Витягує Google Drive file ID з URL
  static String? extractGoogleDriveId(String url) {
    final m1 = RegExp(r'drive\.google\.com/file/d/([^/?]+)').firstMatch(url);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'[?&]id=([^&]+)').firstMatch(url);
    if (m2 != null) return m2.group(1);
    final m3 = RegExp(r'lh3\.googleusercontent\.com/d/([^/?]+)').firstMatch(url);
    if (m3 != null) return m3.group(1);
    final m4 = RegExp(r'drive\.usercontent\.google\.com/download\?id=([^&]+)').firstMatch(url);
    if (m4 != null) return m4.group(1);
    return null;
  }

  /// Генерує URL мініатюри для Google Drive файлу
  static String? toGoogleDriveThumbnailUrl(String url) {
    final id = extractGoogleDriveId(url);
    if (id == null) return null;
    return 'https://drive.google.com/thumbnail?id=$id&sz=w480';
  }

  /// Конвертує Google Drive URL в URL для завантаження аудіо/відео
  /// Витягує ідентифікатор файлу Drive з будь-якого відомого формату посилання.
  static String? driveFileId(String url) {
    final direct = RegExp(r'drive\.google\.com/file/d/([^/?]+)').firstMatch(url);
    if (direct != null) return direct.group(1);
    final lh3 = RegExp(r'lh3\.googleusercontent\.com/d/([^/?]+)').firstMatch(url);
    if (lh3 != null) return lh3.group(1);
    final query = RegExp(r'[?&]id=([^&]+)').firstMatch(url);
    if (query != null) return query.group(1);
    return null;
  }

  /// Пряме посилання на файл для завантаження/відтворення.
  ///
  /// Основне сховище медіа — Firebase Storage: його download-URL уже прямий
  /// і працює однаково на всіх платформах, тож повертається без змін.
  ///
  /// Посилання на Google Drive лишились із часів, коли файли лежали там;
  /// їх переводимо на download-URL Drive. У браузері такі файли, як правило,
  /// не грають (запит іде з кукі, на 403 немає CORS) — для вебу файл треба
  /// завантажити у сховище через адмін-панель.
  static String _mediaUrl(String url) {
    final id = driveFileId(url);
    if (id == null) return url;
    return 'https://drive.usercontent.google.com/download?id=$id&export=download&authuser=0&confirm=t';
  }

  static String toAudioDownloadUrl(String url) => _mediaUrl(url);

  /// Конвертує посилання в URL для відображення зображень
  static String toImageUrl(String url) => _mediaUrl(url);

  /// Повертає локальний шлях до нотації (якщо закешована), інакше null
  static Future<String?> getLocalNotationPath(String url) async {
    if (kIsWeb) return null;
    final fileName = _notationFileNameFor(url);
    final dir = await _cacheDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists() && (await file.length()) > 512) return file.path;
    return null;
  }

  /// Завантажує зображення нотації у постійний кеш і повертає локальний шлях
  static Future<String> downloadNotation(String url) async {
    if (kIsWeb) return url; // На вебі повертаємо URL напряму
    final downloadUrl = toImageUrl(url);
    final fileName = _notationFileNameFor(downloadUrl);
    final dir = await _cacheDir();
    final file = File('${dir.path}/$fileName');

    if (await file.exists() && (await file.length()) > 512) {
      debugPrint('MediaCache: notation from cache ${file.path}');
      return file.path;
    }

    debugPrint('MediaCache: downloading notation $downloadUrl');
    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/html')) {
      throw Exception('Файл нотації недоступний. Переконайтесь що файл публічний.');
    }
    await file.writeAsBytes(response.bodyBytes);
    debugPrint('MediaCache: saved notation ${file.path} (${response.bodyBytes.length} bytes)');
    return file.path;
  }

  static String _fileNameFor(String url) {
    return '${url.hashCode.abs()}.audio';
  }

  static String _notationFileNameFor(String url) {
    return '${url.hashCode.abs()}.notation';
  }
}
