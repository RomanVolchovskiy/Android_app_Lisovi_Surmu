import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AudioService extends ChangeNotifier {
  // Створюємо екземпляр плеєра
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  String? _currentSignalId;
  List<String> _favoriteIds = [];

  bool get isPlaying => _isPlaying;
  String? get currentSignalId => _currentSignalId;

  AudioService() {
    _loadFavorites();
    _configureAudioContext();

    // Слухаємо стан плеєра, щоб оновлювати UI, коли музика закінчиться
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.completed) {
        _currentSignalId = null;
      }
      notifyListeners();
    });
  }

  void _configureAudioContext() {
    if (kIsWeb) return; // Web не потребує налаштування AudioContext
    AudioPlayer.global.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {},
      ),
    ));
  }

  /// ВІДТВОРЕННЯ
  Future<void> play(String audioUrl) async {
    audioUrl = audioUrl.trim();
    try {
      // Якщо це той самий сигнал, який вже грає — просто продовжуємо
      if (_currentSignalId == audioUrl && !_isPlaying) {
        await _audioPlayer.resume();
        return;
      }

      // Зупиняємо попередній звук перед початком нового
      await _audioPlayer.stop();
      _currentSignalId = audioUrl;

      // Нормалізуємо шлях (підтримка Windows-шляхів типу D:\flutter_app\assets\audio\1.mp3)
      if (audioUrl.contains('assets')) {
        final assetsIndex = audioUrl.indexOf('assets');
        String relativePath = audioUrl.substring(assetsIndex).replaceAll('\\', '/');
        String cleanPath = relativePath.replaceFirst('assets/', '');
        await _audioPlayer.play(AssetSource(cleanPath));
      } else if (!kIsWeb && (audioUrl.contains('drive.google.com') || audioUrl.contains('drive.usercontent.google.com'))) {
        // Google Drive — завантажуємо в кеш і грає локально (тільки мобільні)
        final localPath = await _downloadToCache(audioUrl);
        await _audioPlayer.play(DeviceFileSource(localPath));
      } else {
        await _audioPlayer.play(UrlSource(audioUrl));
      }

      _isPlaying = true;
      notifyListeners();
      debugPrint('Playing audio: $audioUrl');
    } catch (e) {
      debugPrint('Помилка відтворення: $e');
      rethrow;
    }
  }

  Future<String> _downloadToCache(String url) async {
    final fileName = '${url.hashCode}.mp3';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      debugPrint('Playing from cache: ${file.path}');
      return file.path;
    }
    debugPrint('Downloading audio to cache: $url');
    final response = await http.get(Uri.parse(url));
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  /// ПАУЗА
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
    debugPrint('Pausing audio');
  }

  /// ЗУПИНКА
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentSignalId = null;
    notifyListeners();
    debugPrint('Stopping audio');
  }

  // --- ЛОГІКА ОБРАНОГО (FAVORITES) ---

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteIds = prefs.getStringList('favorite_signals') ?? [];
    notifyListeners();
  }

  Future<bool> isFavorite(String signalId) async {
    return _favoriteIds.contains(signalId);
  }

  Future<void> addToFavorites(String signalId) async {
    if (!_favoriteIds.contains(signalId)) {
      _favoriteIds.add(signalId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_signals', _favoriteIds);
      notifyListeners();
    }
  }

  Future<void> removeFromFavorites(String signalId) async {
    if (_favoriteIds.contains(signalId)) {
      _favoriteIds.remove(signalId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_signals', _favoriteIds);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
