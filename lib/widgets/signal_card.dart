import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка відтворення: $e')),
          );
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SignalDetailsSheet(signal: widget.signal),
    );
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
                      child: ElevatedButton.icon(
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

  void _openNotation(BuildContext context, String? notationUrl) {
    if (notationUrl == null || notationUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ноти не додані для цього сигналу')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _NotationViewerDialog(notationUrl: notationUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Icon(
                  Icons.category,
                  color: HuntingTheme.primaryDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  signal.category,
                  style: TextStyle(
                    color: HuntingTheme.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.timer,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${signal.duration}с',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Опис',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            signal.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
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
              const SizedBox(width: 12),
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
          const SizedBox(height: 16),
        ],
      ),
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

  @override
  void dispose() {
    _controller.dispose();
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
              child: CircularProgressIndicator(color: Colors.white),
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