import 'dart:io' show File;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/platform_dialog.dart';
import 'package:hunting_signals/utils/platform_utils.dart';

class SignalCard extends StatefulWidget {
  final HuntingSignal signal;

  const SignalCard({
    super.key,
    required this.signal,
  });

  @override
  State<SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<SignalCard> {
  late AudioService _audioService;
  bool _isPlaying = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite = await _audioService.isFavorite(widget.signal.id);
    setState(() {
      _isFavorite = isFavorite;
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioService.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      try {
        if (widget.signal.audioUrl != null) {
          await _audioService.play(widget.signal.audioUrl!);
          setState(() {
            _isPlaying = true;
          });
        }
      } catch (e) {
        if (mounted) {
          showPlatformSnackBar(context, 'Помилка відтворення: $e');
        }
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _audioService.removeFromFavorites(widget.signal.id);
    } else {
      await _audioService.addToFavorites(widget.signal.id);
    }
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _showSignalDetails() {
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SignalDetailsSheet(signal: widget.signal),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SignalDetailsSheet(signal: widget.signal),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              HuntingTheme.primaryLight.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showSignalDetails,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: HuntingTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.surround_sound,
                          color: HuntingTheme.primaryDark,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.signal.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.signal.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.grey[400],
                        size: 22,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.signal.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: isIOS
                          ? CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _togglePlay,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(_isPlaying ? 'Пауза' : 'Слухати'),
                                ],
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _togglePlay,
                              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                              label: Text(_isPlaying ? 'Пауза' : 'Слухати'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HuntingTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.signal.duration}с',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignalDetailsSheet extends StatelessWidget {
  final HuntingSignal signal;

  const SignalDetailsSheet({
    super.key,
    required this.signal,
  });

  void _openVideo(BuildContext context, String? videoUrl) {
    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Відео не додано для цього сигналу')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  void _openNotation(BuildContext context, String? notationUrl) async {
    if (notationUrl == null || notationUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ноти не додані для цього сигналу')),
      );
      return;
    }
    // Зображення — показуємо в діалозі
    final lower = notationUrl.toLowerCase();
    final isImage = lower.endsWith('.png') || lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') || lower.endsWith('.webp');
    if (isImage) {
      showDialog(context: context, builder: (_) => _NotationViewerDialog(notationUrl: notationUrl));
      return;
    }
    // PDF або будь-яке посилання — відкриваємо в браузері
    final uri = Uri.tryParse(notationUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не вдалося відкрити файл з нотами')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scrollable content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        signal.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HuntingTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.category, color: HuntingTheme.primaryDark, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        signal.category,
                        style: TextStyle(
                          color: HuntingTheme.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${signal.duration}с',
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Опис',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                ),
                const SizedBox(height: 8),
                Text(
                  signal.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
                ),
                // Зображення
                if (signal.imageUrl != null && signal.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      signal.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (ctx, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (ctx, err, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                // Історична інформація
                if (signal.historicalInfo != null && signal.historicalInfo!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Історична довідка',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                  const SizedBox(height: 6),
                  Text(signal.historicalInfo!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
                ],
                // Інструкції з використання
                if (signal.usageInstructions != null && signal.usageInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Інструкції',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                  const SizedBox(height: 6),
                  Text(signal.usageInstructions!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // Кнопки завжди видимі внизу
        if (signal.videoUrl != null || signal.notationUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Row(
              children: [
                if (signal.videoUrl != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openVideo(context, signal.videoUrl),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Дивитись відео'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (signal.notationUrl != null) const SizedBox(width: 12),
                ],
                if (signal.notationUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openNotation(context, signal.notationUrl),
                      icon: const Icon(Icons.music_note),
                      label: const Text('Ноти'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: HuntingTheme.primaryColor),
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          const SizedBox(height: 24),
      ],
    );
  }
}

// --- VIDEO PLAYER DIALOG ---

class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerDialog({required this.videoUrl});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _controllerInitialized = false;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.videoUrl.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(widget.videoUrl);
      } else if (!kIsWeb &&
          (widget.videoUrl.contains('drive.google.com') ||
              widget.videoUrl.contains('drive.usercontent.google.com'))) {
        // На вебі кеш не підтримується — відтворюємо напряму
        final localPath = await _downloadToCache(widget.videoUrl);
        _controller = VideoPlayerController.file(File(localPath));
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      }
      await _controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<String> _downloadToCache(String url) async {
    final resolvedUrl = _resolveGoogleDriveUrl(url);
    final fileName = '${resolvedUrl.hashCode}.mp4';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return file.path;
    final response = await http.get(Uri.parse(resolvedUrl));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/html')) {
      throw Exception('Google Drive повернув HTML замість відео. Перевірте, чи файл публічний.');
    }
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  String _resolveGoogleDriveUrl(String url) {
    // Формат: /file/d/FILE_ID/view або /file/d/FILE_ID/
    final fileIdMatch = RegExp(r'/file/d/([^/?]+)').firstMatch(url);
    if (fileIdMatch != null) {
      final id = fileIdMatch.group(1)!;
      return 'https://drive.usercontent.google.com/download?id=$id&export=download&authuser=0&confirm=t';
    }
    // Формат: ?id=FILE_ID або &id=FILE_ID
    final idMatch = RegExp(r'[?&]id=([^&]+)').firstMatch(url);
    if (idMatch != null) {
      final id = idMatch.group(1)!;
      return 'https://drive.usercontent.google.com/download?id=$id&export=download&authuser=0&confirm=t';
    }
    return url;
  }

  @override
  void dispose() {
    if (_initialized) {
      _controller.pause();
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Відео'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Помилка завантаження відео:\n$_error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          else if (!_initialized)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Завантаження відео...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          else
            Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (_, value, __) {
                        final pos = value.position;
                        final dur = value.duration;
                        return Text(
                          '${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')} / ${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ],
                ),
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (_, value, __) => Slider(
                    value: value.position.inSeconds.toDouble().clamp(0, value.duration.inSeconds.toDouble()),
                    max: value.duration.inSeconds.toDouble().clamp(1, double.infinity),
                    activeColor: Colors.white,
                    inactiveColor: Colors.grey,
                    onChanged: (v) => _controller.seekTo(Duration(seconds: v.toInt())),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// --- NOTATION VIEWER DIALOG ---

class _NotationViewerDialog extends StatelessWidget {
  final String notationUrl;
  const _NotationViewerDialog({required this.notationUrl});

  bool get _isImage {
    final lower = notationUrl.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: const Text('Ноти'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Flexible(
            child: _isImage ? _buildImageViewer() : _buildTextViewer(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    final isAsset = notationUrl.startsWith('assets/');
    return InteractiveViewer(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: isAsset
            ? Image.asset(notationUrl, fit: BoxFit.contain)
            : Image.network(
                notationUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (ctx, err, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Помилка завантаження: $err'),
                ),
              ),
      ),
    );
  }

  Widget _buildTextViewer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        notationUrl,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}