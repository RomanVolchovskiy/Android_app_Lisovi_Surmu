import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'media_cache_service.dart';

class AudioService extends ChangeNotifier {
  // Singleton — один плеєр на весь застосунок
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  String? _currentSignalId;
  List<String> _favoriteIds = [];

  bool get isPlaying => _isPlaying;
  String? get currentSignalId => _currentSignalId;

  AudioService._internal() {
    _loadFavorites();
    _configureAudioContext();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // Слухаємо стан плеєра, щоб оновлювати UI, коли музика закінчиться
    _audioPlayer.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (_isPlaying == playing && state != PlayerState.completed) return;
      _isPlaying = playing;
      if (state == PlayerState.completed) _currentSignalId = null;
      notifyListeners();
    });
  }

  void _configureAudioContext() {
    // Аудіоконтекст — поняття Android/iOS. У браузері його налаштування не
    // підтримується і кидає виняток, який ламав би конструктор синглтона.
    if (kIsWeb) return;
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
      } else if (audioUrl.contains('drive.google.com') ||
          audioUrl.contains('drive.usercontent.google.com') ||
          audioUrl.contains('lh3.googleusercontent.com')) {
        // Google Drive — завантажуємо в постійний кеш і грає локально.
        // На вебі кешу у файловій системі немає: downloadAudio віддає прямий
        // URL, тож там граємо через UrlSource, а не DeviceFileSource.
        final localPath = await MediaCacheService.downloadAudio(audioUrl);
        await _audioPlayer.play(
            kIsWeb ? UrlSource(localPath) : DeviceFileSource(localPath));
      } else {
        // Спочатку перевіряємо локальний кеш
        final cached = await MediaCacheService.getLocalAudioPath(audioUrl);
        if (cached != null) {
          await _audioPlayer.play(DeviceFileSource(cached));
        } else {
          await _audioPlayer.play(UrlSource(audioUrl));
        }
      }

      debugPrint('Playing audio: $audioUrl');
    } catch (e) {
      debugPrint('Помилка відтворення: $e');
      rethrow;
    }
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

  // Singleton — не dispose-ємо, живе весь час роботи застосунку
}
