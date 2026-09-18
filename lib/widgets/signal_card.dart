import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/services/media_cache_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/notation_editor.dart';

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
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  bool _isFavorite = false;

  bool get _thisCardPlaying =>
      _audioService.isPlaying &&
      _audioService.currentSignalId == widget.signal.audioUrl;

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioChanged);
    _loadFavoriteStatus();
  }

  void _onAudioChanged() {
    if (mounted) setState(() => _isPlaying = _thisCardPlaying);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChanged);
    super.dispose();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite = await _audioService.isFavorite(widget.signal.id);
    if (mounted) setState(() => _isFavorite = isFavorite);
  }

  Future<void> _togglePlay() async {
    if (_thisCardPlaying) {
      await _audioService.pause();
    } else {
      try {
        if (widget.signal.audioUrl != null) {
          await _audioService.play(widget.signal.audioUrl!);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignalDetailScreen(signal: widget.signal),
      ),
    );
  }

  void _openVideo() {
    final url = widget.signal.videoUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Відео не додано для цього сигналу')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _VideoPlayerScreen(videoUrl: url, title: widget.signal.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showSignalDetails,
      child: Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E7), Color(0xFFE8C87A)],
          ),
          border: Border.all(color: const Color(0xFFD4A017), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/icons/icon1.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.signal.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.signal.category,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.signal.description,
                style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CardBtn(
                      label: _isPlaying ? 'Пауза' : 'Слухати',
                      icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: HuntingTheme.primaryColor,
                      onTap: _togglePlay,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _CardBtn(
                      label: 'Відео',
                      icon: Icons.videocam_rounded,
                      color: const Color(0xFF1565C0),
                      onTap: _openVideo,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _CardBtn(
                      label: 'Інфо',
                      icon: Icons.info_outline,
                      color: Colors.grey[600]!,
                      outlined: true,
                      onTap: _showSignalDetails,
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

class SignalDetailScreen extends StatefulWidget {
  final HuntingSignal signal;

  const SignalDetailScreen({super.key, required this.signal});

  @override
  State<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends State<SignalDetailScreen> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;

  String _toImageUrl(String url) => MediaCacheService.toImageUrl(url);

  bool get _thisScreenPlaying =>
      _audioService.isPlaying &&
      _audioService.currentSignalId == widget.signal.audioUrl;

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioChanged);
  }

  void _onAudioChanged() {
    if (mounted) setState(() => _isPlaying = _thisScreenPlaying);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChanged);
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_thisScreenPlaying) {
      await _audioService.pause();
    } else {
      if (widget.signal.audioUrl == null || widget.signal.audioUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аудіо не додано для цього сигналу')),
        );
        return;
      }
      try {
        await _audioService.play(widget.signal.audioUrl!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка відтворення: $e')),
          );
        }
      }
    }
  }

  void _openVideo() {
    final url = widget.signal.videoUrl2;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Відео не додано для цього сигналу')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _VideoPlayerScreen(videoUrl: url, title: widget.signal.name),
    ));
  }

  void _openGallery() {
    final images = widget.signal.galleryImages;
    if (images == null || images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фотогалерея не додана для цього сигналу')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryScreen(
          images: images,
          title: widget.signal.name,
        ),
      ),
    );
  }

  void _openNotation() => openSignalNotation(context, widget.signal);

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: Text(signal.name, style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & duration row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HuntingTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.category, color: HuntingTheme.primaryDark, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            signal.category,
                            style: TextStyle(
                              color: HuntingTheme.primaryDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (signal.duration > 0) ...[
                          Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${signal.duration}с',
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description
                  _sectionTitle('Опис'),
                  const SizedBox(height: 8),
                  Text(
                    signal.description,
                    style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.6),
                  ),
                  // Image
                  if (signal.imageUrl != null && signal.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _toImageUrl(signal.imageUrl!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  // Historical info
                  if (signal.historicalInfo != null && signal.historicalInfo!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Історична довідка'),
                    const SizedBox(height: 8),
                    Text(
                      signal.historicalInfo!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6),
                    ),
                  ],
                  // Usage instructions
                  if (signal.usageInstructions != null && signal.usageInstructions!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Інструкції з використання'),
                    const SizedBox(height: 8),
                    Text(
                      signal.usageInstructions!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6),
                    ),
                  ],
                  // Tags
                  if (signal.tags != null && signal.tags!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Теги'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: signal.tags!
                          .map((tag) => Chip(
                                label: Text(tag, style: const TextStyle(fontSize: 12)),
                                backgroundColor: HuntingTheme.primaryColor.withValues(alpha: 0.1),
                                side: BorderSide(color: HuntingTheme.primaryColor.withValues(alpha: 0.3)),
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Fixed bottom buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              8,
              10,
              8,
              10 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  label: _isPlaying ? 'Пауза' : 'Аудіо',
                  color: HuntingTheme.primaryColor,
                  onTap: _toggleAudio,
                ),
                _ActionButton(
                  icon: Icons.videocam_rounded,
                  label: 'Відео',
                  color: Colors.blue[700]!,
                  onTap: _openVideo,
                ),
                _ActionButton(
                  icon: Icons.music_note_rounded,
                  label: 'Ноти',
                  color: Colors.orange[700]!,
                  onTap: _openNotation,
                ),
                _ActionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Галерея',
                  color: Colors.teal[600]!,
                  onTap: _openGallery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.brown[800],
      ),
    );
  }
}

// --- CARD BUTTON (3D ефект) ---

class _CardBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  State<_CardBtn> createState() => _CardBtnState();
}

class _CardBtnState extends State<_CardBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final topColor = Color.lerp(widget.color, Colors.white, 0.25)!;
    final botColor = Color.lerp(widget.color, Colors.black, 0.15)!;
    final shadowColor = Color.lerp(widget.color, Colors.black, 0.45)!;
    final fg = Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 32,
        transform: _pressed
            ? (Matrix4.identity()..translateByDouble(0.0, 2.0, 0.0, 1.0))
            : Matrix4.identity(),
        decoration: widget.outlined
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: widget.color, width: 1.5),
                boxShadow: _pressed ? [] : [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.4),
                    offset: const Offset(0, 3),
                    blurRadius: 2,
                  ),
                ],
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [topColor, botColor],
                ),
                boxShadow: _pressed ? [] : [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.6),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.25),
                    offset: const Offset(0, 5),
                    blurRadius: 6,
                  ),
                ],
              ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 13, color: fg),
            const SizedBox(width: 3),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              textScaler: TextScaler.noScaling,
            ),
          ],
        ),
      ),
    );
  }
}

// --- ACTION BUTTON ---

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- GALLERY SCREEN ---

class _GalleryScreen extends StatefulWidget {
  final List<String> images;
  final String title;

  const _GalleryScreen({required this.images, required this.title});

  @override
  State<_GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<_GalleryScreen> {
  int _current = 0;
  late final PageController _pageController;
  final Map<int, bool> _isLandscape = {};

  String _toImageUrl(String url) {
    if (url.contains('lh3.googleusercontent.com')) return url;
    final m1 = RegExp(r'drive\.google\.com/file/d/([^/?]+)').firstMatch(url);
    if (m1 != null) return 'https://lh3.googleusercontent.com/d/${m1.group(1)}';
    final m2 = RegExp(r'[?&]id=([^&]+)').firstMatch(url);
    if (m2 != null) return 'https://lh3.googleusercontent.com/d/${m2.group(1)}';
    return url;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _resolveOrientation(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _resolveOrientation(int index) {
    final url = _toImageUrl(widget.images[index]);
    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener((info, _) {
      if (!mounted) return;
      final landscape = info.image.width > info.image.height;
      _isLandscape[index] = landscape;
      if (_current == index) _applyOrientation(landscape);
    }));
  }

  void _applyOrientation(bool landscape) {
    if (landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF4EFE4);
    const appBarColor = Color(0xFF3B2F1E);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.title} — ${_current + 1}/${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              if (_isLandscape.containsKey(i)) {
                _applyOrientation(_isLandscape[i]!);
              } else {
                _resolveOrientation(i);
              }
            },
            itemBuilder: (ctx, i) {
              return InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: _toImageUrl(widget.images[i]),
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Color(0xFF3B2F1E)),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Color(0xFF8B7355), size: 64),
                          SizedBox(height: 8),
                          Text('Не вдалося завантажити',
                              style: TextStyle(color: Color(0xFF8B7355))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Dots indicator
          if (widget.images.length > 1)
            Positioned(
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _current == i ? const Color(0xFF3B2F1E) : const Color(0x663B2F1E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- VIDEO PLAYER SCREEN ---

class _VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  const _VideoPlayerScreen({required this.videoUrl, required this.title});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _controller;
  WebViewController? _webController;
  bool _isYouTube = false;
  bool _initialized = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  String? _error;
  String _statusText = 'Підготовка відео...';
  Timer? _uiTimer;

  static const _bgColor    = Color(0xFF1A0F00);
  static const _woodColor  = Color(0xFF2C1A0A);
  static const _goldColor  = Color(0xFFD4A017);
  static const _goldLight  = Color(0xFFFFD966);
  static const _greenColor = Color(0xFF2D5A1B);

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      setState(() => _statusText = 'Завантаження відео...');
      if (MediaCacheService.isYouTubeUrl(widget.videoUrl)) {
        final embedUrl = MediaCacheService.toYouTubeEmbedUrl(widget.videoUrl);
        if (embedUrl == null) {
          setState(() => _error = 'Не вдалося розпізнати YouTube посилання');
          return;
        }
        _isYouTube = true;
        final wc = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(embedUrl));
        _webController = wc;
        if (mounted) setState(() => _initialized = true);
      } else if (widget.videoUrl.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(widget.videoUrl);
        await _finalizeController();
      } else if (widget.videoUrl.contains('drive.google.com') ||
          widget.videoUrl.contains('drive.usercontent.google.com') ||
          widget.videoUrl.contains('lh3.googleusercontent.com')) {
        setState(() => _statusText = 'Завантаження з Google Drive...');
        final networkUrl = MediaCacheService.toAudioDownloadUrl(widget.videoUrl);
        _controller = VideoPlayerController.networkUrl(Uri.parse(networkUrl));
        await _finalizeController();
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
        await _finalizeController();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _finalizeController() async {
    setState(() => _statusText = 'Ініціалізація плеєра...');
    await _controller!.initialize();
    if (mounted) {
      setState(() => _initialized = true);
      // Див. video_player_screen: у браузері автостарт зі звуком блокується.
      if (!kIsWeb) _controller!.play();
      _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    }
  }


  String _formatTime(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _togglePlay() {
    if (_isYouTube || _controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  void _seek(double seconds) {
    if (_isYouTube || _controller == null) return;
    _controller!.seekTo(Duration(seconds: seconds.toInt()));
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  Future<void> _restoreOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _restoreOrientation();
    if (!_isYouTube && _initialized && _controller != null) {
      _controller!.pause();
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    // YouTube: simple full-screen WebView with back button
    if (_isYouTube) {
      return PopScope(
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) await _restoreOrientation();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              Container(
                color: _woodColor,
                padding: EdgeInsets.fromLTRB(4, mq.padding.top + 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: _goldColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('▶', style: TextStyle(color: _goldColor, fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(color: _goldLight, fontSize: 15,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Container(height: 2,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_bgColor, _goldColor, _goldColor, _bgColor]))),
              Expanded(
                child: _initialized && _webController != null
                    ? WebViewWidget(controller: _webController!)
                    : _buildLoading(),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _restoreOrientation();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: isLandscape ? _buildLandscape(context) : _buildPortrait(context, mq),
      ),
    );
  }

  // ── PORTRAIT layout ──────────────────────────────────────────────────
  Widget _buildPortrait(BuildContext context, MediaQueryData mq) {
    return Column(
      children: [
        // Top bar
        Container(
          color: _woodColor,
          padding: EdgeInsets.fromLTRB(4, mq.padding.top + 4, 8, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: _goldColor),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('♪', style: TextStyle(color: _goldColor, fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(color: _goldLight, fontSize: 15,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: _goldColor, size: 26),
                tooltip: 'На весь екран',
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ),
        // Gold divider
        Container(height: 2,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_bgColor, _goldColor, _goldColor, _bgColor]))),
        // Video
        Expanded(
          child: _error != null ? _buildError() :
                 !_initialized ? _buildLoading() :
                 _buildVideoArea(),
        ),
        // Controls
        if (_initialized && _error == null)
          _buildControlsPanel(context, compact: false),
        // Notes bar
        Container(
          height: 26,
          color: _woodColor,
          child: const Center(
            child: Text('♩  ♪  ♫  ♬  ♩  ♪  ♫  ♬  ♩  ♪  ♫  ♬  ♩  ♪  ♫',
                style: TextStyle(color: _goldColor, fontSize: 12, letterSpacing: 2)),
          ),
        ),
        SizedBox(height: mq.padding.bottom),
      ],
    );
  }

  // ── LANDSCAPE / FULLSCREEN layout ────────────────────────────────────
  Widget _buildLandscape(BuildContext context) {
    final mq = MediaQuery.of(context);
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        children: [
          // Video fills entire screen
          Positioned.fill(
            child: _error != null ? _buildError() :
                   !_initialized ? _buildLoading() :
                   _buildVideoArea(),
          ),
          // Controls overlay (shown/hidden on tap)
          if (_initialized && _error == null && _showControls)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildControlsPanel(context, compact: true),
            ),
          // Back button
          if (_showControls)
            Positioned(
              top: mq.padding.top + 4,
              left: 4,
              child: _overlayIconBtn(
                Icons.arrow_back_ios_new,
                () => Navigator.pop(context),
              ),
            ),
          // Title
          if (_showControls)
            Positioned(
              top: mq.padding.top + 10,
              left: 56,
              right: 100,
              child: Text(widget.title,
                  style: const TextStyle(color: _goldLight, fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)]),
                  overflow: TextOverflow.ellipsis),
            ),
          // Fullscreen exit button
          if (_showControls)
            Positioned(
              top: mq.padding.top + 4,
              right: mq.padding.right + 4,
              child: _overlayIconBtn(
                Icons.fullscreen_exit,
                _toggleFullscreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _overlayIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _goldColor, size: 22),
      ),
    );
  }

  // ── VIDEO AREA ───────────────────────────────────────────────────────
  Widget _buildVideoArea() {
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }

  // ── CONTROLS PANEL ───────────────────────────────────────────────────
  Widget _buildControlsPanel(BuildContext context, {required bool compact}) {
    final value = _controller!.value;
    final pos = value.position;
    final dur = value.duration;
    final progress = dur.inMilliseconds > 0
        ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
    final mq = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: compact
            ? Colors.black.withValues(alpha: 0.75)
            : _woodColor,
        border: compact ? null : const Border(
            top: BorderSide(color: _goldColor, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, compact ? 6 : 10,
        16, compact ? mq.padding.bottom + 6 : 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _goldColor,
              inactiveTrackColor: Colors.brown[900],
              thumbColor: _goldLight,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayColor: _goldColor.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: pos.inSeconds.toDouble().clamp(0, dur.inSeconds.toDouble()),
              max: dur.inSeconds.toDouble().clamp(1, double.infinity),
              onChanged: _seek,
            ),
          ),
          // Time + fullscreen row
          Row(
            children: [
              Text(_formatTime(pos),
                  style: const TextStyle(color: _goldColor, fontSize: 12)),
              const Spacer(),
              Text(_formatTime(dur),
                  style: const TextStyle(color: _goldColor, fontSize: 12)),
              if (!compact) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleFullscreen,
                  child: const Icon(Icons.fullscreen, color: _goldColor, size: 22),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlBtn(
                icon: Icons.replay_10,
                size: compact ? 38 : 44,
                onTap: () => _seek((pos.inSeconds - 10).toDouble().clamp(0, double.infinity)),
              ),
              SizedBox(width: compact ? 16 : 20),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: compact ? 52 : 64,
                  height: compact ? 52 : 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _greenColor,
                    border: Border.all(color: _goldColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _goldColor.withValues(alpha: 0.3),
                        blurRadius: 10, spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: _goldLight,
                    size: compact ? 28 : 36,
                  ),
                ),
              ),
              SizedBox(width: compact ? 16 : 20),
              _ControlBtn(
                icon: Icons.forward_10,
                size: compact ? 38 : 44,
                onTap: () => _seek((pos.inSeconds + 10).toDouble()),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(20, (i) {
                final filled = i / 20 <= progress;
                return Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? _goldColor : const Color(0xFF3E2000),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _woodColor,
              border: Border.all(color: _goldColor, width: 2),
            ),
            child: const Icon(Icons.music_note, color: _goldColor, size: 42),
          ),
          const SizedBox(height: 20),
          const SizedBox(width: 160,
              child: LinearProgressIndicator(color: _goldColor, backgroundColor: _woodColor)),
          const SizedBox(height: 14),
          Text(_statusText,
              style: const TextStyle(color: _goldLight, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _goldColor, size: 52),
            const SizedBox(height: 14),
            const Text('Помилка завантаження',
                style: TextStyle(color: _goldLight, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _ControlBtn({required this.icon, required this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2C1A0A),
          border: Border.all(color: const Color(0xFFD4A017).withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: const Color(0xFFD4A017), size: size * 0.5),
      ),
    );
  }
}

// --- NOTATION VIEWER SCREEN ---

class _NotationViewerScreen extends StatefulWidget {
  final String? notationUrl;
  final String? notationAudioUrl;
  final String title;
  final String? signalText;
  final List<Map<String, dynamic>>? notationNotes;
  final int? notationTempo;
  final String? partitureUrl;

  const _NotationViewerScreen({
    this.notationUrl,
    required this.title,
    this.notationAudioUrl,
    this.signalText,
    this.notationNotes,
    this.notationTempo,
    this.partitureUrl,
  });

  @override
  State<_NotationViewerScreen> createState() => _NotationViewerScreenState();
}

class _NotationViewerScreenState extends State<_NotationViewerScreen> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;

  // ── Notation playback ──
  late int _tempo;
  bool _isPlayingNotation = false;
  int _currentNoteIndex = -1;
  int? _countdown; // 5..1 під час відліку, null = не рахує
  Timer? _notationTimer;
  Timer? _countdownTimer;
  final ScrollController _notationScroll = ScrollController();
  final TextEditingController _tempoInput = TextEditingController();

  // Beats per duration: whole=4, half=2, quarter=1, eighth=0.5, sixteenth=0.25
  static const _beats = [4.0, 2.0, 1.0, 0.5, 0.25];

  List<Map<String, dynamic>> get _notes => widget.notationNotes ?? [];

  bool get _thisPlaying =>
      _audioService.isPlaying &&
      _audioService.currentSignalId == widget.notationAudioUrl;

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioChanged);
    _tempo = widget.notationTempo ?? 80;
    _tempoInput.text = _tempo.toString();
  }

  void _onAudioChanged() {
    if (mounted) setState(() => _isPlaying = _thisPlaying);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChanged);
    _notationTimer?.cancel();
    _countdownTimer?.cancel();
    _notationScroll.dispose();
    _tempoInput.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.play(widget.notationAudioUrl!);
    }
  }

  // ── Notation playback methods ──

  void _startNotationPlayback() {
    if (_notes.isEmpty) return;
    _notationTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 5;
      _isPlayingNotation = false;
      _currentNoteIndex = -1;
    });
    _runCountdown();
  }

  void _runCountdown() {
    _countdownTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final next = (_countdown ?? 1) - 1;
      if (next <= 0) {
        setState(() {
          _countdown = null;
          _isPlayingNotation = true;
          _currentNoteIndex = 0;
        });
        _scheduleNextNote();
      } else {
        setState(() => _countdown = next);
        _runCountdown();
      }
    });
  }

  void _stopNotationPlayback() {
    _notationTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _isPlayingNotation = false;
      _currentNoteIndex = -1;
      _countdown = null;
    });
  }

  void _scheduleNextNote() {
    if (_currentNoteIndex >= _notes.length) {
      _stopNotationPlayback();
      return;
    }
    _scrollToNote(_currentNoteIndex);

    final item = _notes[_currentNoteIndex];
    final t = item['t'] ?? 'n';
    final double b = t == 'n'
        ? _beats[(item['d'] as num).toInt()]
        : 1.0; // breath / pause = 1 beat
    final ms = (b * 60000.0 / _tempo).round();

    _notationTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _currentNoteIndex++);
      _scheduleNextNote();
    });
  }

  void _scrollToNote(int index) {
    if (!_notationScroll.hasClients) return;
    final target = (index * 62.0 - 80).clamp(0.0, _notationScroll.position.maxScrollExtent);
    _notationScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _applyTempo(String val) {
    final v = int.tryParse(val);
    if (v != null && v >= 20 && v <= 300) {
      setState(() => _tempo = v);
      if (_isPlayingNotation) {
        _notationTimer?.cancel();
        _scheduleNextNote();
      }
    }
  }

  Future<void> _openFullscreenImage() async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullscreenNotationScreen(child: _buildImage()),
    ));
  }

  Future<void> _openFullscreenGraphic() async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullscreenGraphicNotationScreen(
        notes: widget.notationNotes!,
        tempo: _tempo,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = widget.notationAudioUrl != null && widget.notationAudioUrl!.isNotEmpty;
    const bgColor = Color(0xFF1C2B1E);
    const cardColor = Color(0xFF243328);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        child: Column(
        children: [
          // Підказка про метод запам'ятовування
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4A6741), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFFD4A017), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '«Здавна мисливці «оживляли» кожен звук рожка, підбираючи до нього влучні слова. '
                    'Такий спів не лише допомагав надійно закарбувати мелодію в пам\'яті, а й давав змогу '
                    'миттєво збагнути прихований зміст кожного лісового сигналу».',
                    style: TextStyle(color: Color(0xFFCCDDCC), fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          // Зображення нот (якщо є URL) — тап → повноекранний горизонтальний режим
          if (widget.notationUrl != null && widget.notationUrl!.isNotEmpty)
            GestureDetector(
              onTap: _openFullscreenImage,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4A6741), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.40,
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: _buildImage(),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Повний екран',
                                  style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Темп та відтворення нот
          if (widget.notationNotes != null && widget.notationNotes!.isNotEmpty)
            _buildTempoControls(),
          // Графічне відображення нот + кнопка повного екрану у заголовку
          if (widget.notationNotes != null && widget.notationNotes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Рядок з кнопкою повного екрану
                  Row(
                    children: [
                      const Icon(Icons.grid_on_rounded, color: Color(0xFFD4A017), size: 15),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('Графічне відображення',
                            style: TextStyle(color: Color(0xFFD4A017),
                                fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      GestureDetector(
                        onTap: () => _openFullscreenGraphic(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A6741),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Повний екран',
                                  style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _openFullscreenGraphic,
                    child: NotationDisplayWidget(
                      notes: widget.notationNotes!,
                      currentNoteIndex: _currentNoteIndex,
                      scrollController: _notationScroll,
                    ),
                  ),
                ],
              ),
            ),
          // Текст сигналу (слова до мелодії)
          if (widget.signalText != null && widget.signalText!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4A6741), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lyrics_outlined, color: Color(0xFFD4A017), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Слова сигналу',
                        style: TextStyle(
                          color: Color(0xFFD4A017),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.signalText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFCCDDCC),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          // Плеєр одразу після нот
          if (hasAudio)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4A6741), width: 1),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleAudio,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD4A017),
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Мелодія зі словами — найкращий спосіб запам\'ятати',
                          style: TextStyle(
                            color: Color(0xFFD4A017),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _isPlaying ? 'Співайте слова разом із мелодією...' : 'Увімкніть і підспівуйте',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // ── Партитура (захищена паролем) ───────────────────────────────
          if (widget.partitureUrl != null && widget.partitureUrl!.isNotEmpty)
            _PartitureBlock(partitureUrl: widget.partitureUrl!),
          // Відступ знизу — щоб слова можна було прокрутити до середини екрану
          SizedBox(height: MediaQuery.of(context).size.height * 0.5),
        ],
        ),
      ),
    );
  }

  Widget _buildTempoControls() {
    const cardColor = Color(0xFF243328);
    const borderColor = Color(0xFF4A6741);
    const goldColor = Color(0xFFD4A017);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + play button
          Row(
            children: [
              const Icon(Icons.speed, color: goldColor, size: 16),
              const SizedBox(width: 8),
              const Text('Темп відтворення',
                  style: TextStyle(color: goldColor, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              // Countdown display
              if (_countdown != null)
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: goldColor,
                    boxShadow: [BoxShadow(color: goldColor.withValues(alpha: 0.5), blurRadius: 10)],
                  ),
                  child: Center(
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                          color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              // Play / Stop button
              GestureDetector(
                onTap: (_isPlayingNotation || _countdown != null)
                    ? _stopNotationPlayback
                    : _startNotationPlayback,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_isPlayingNotation || _countdown != null)
                        ? Colors.red[700]
                        : goldColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (_isPlayingNotation || _countdown != null)
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _countdown != null
                            ? 'Скасувати'
                            : _isPlayingNotation
                                ? 'Стоп'
                                : 'Грати',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Slider + BPM input
          Row(
            children: [
              const Text('40', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: goldColor,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: goldColor,
                    overlayColor: goldColor.withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _tempo.toDouble().clamp(40, 300),
                    min: 40,
                    max: 300,
                    divisions: 260,
                    onChanged: (v) {
                      final newTempo = v.round();
                      setState(() => _tempo = newTempo);
                      _tempoInput.text = newTempo.toString();
                      if (_isPlayingNotation) {
                        _notationTimer?.cancel();
                        _scheduleNextNote();
                      }
                    },
                  ),
                ),
              ),
              const Text('300', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 8),
              // BPM text input
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _tempoInput,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: goldColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: goldColor.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: goldColor),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1C2B1E),
                  ),
                  onSubmitted: _applyTempo,
                ),
              ),
              const SizedBox(width: 4),
              const Text('BPM', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return buildNotationImage(widget.notationUrl);
  }
}

// ── БЛОК "ПАРТИТУРА" із захистом паролем ───────────────────────────────────

class _PartitureBlock extends StatefulWidget {
  final String partitureUrl;
  const _PartitureBlock({required this.partitureUrl});

  @override
  State<_PartitureBlock> createState() => _PartitureBlockState();
}

class _PartitureBlockState extends State<_PartitureBlock> {
  bool _unlocked = false;

  static const _kPassword = '2505';
  static const _bgColor   = Color(0xFF1C2B1E);
  static const _cardColor = Color(0xFF243328);
  static const _goldColor = Color(0xFFD4A017);
  static const _border    = Color(0xFF4A6741);

  Future<void> _askPassword() async {
    final controller = TextEditingController();
    bool wrong = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _border),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock, color: _goldColor),
              SizedBox(width: 8),
              Text('Партитура', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Введіть пароль для перегляду:',
                  style: TextStyle(color: Color(0xFFCCDDCC))),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Пароль',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: _goldColor),
                  ),
                  filled: true,
                  fillColor: _bgColor,
                  errorText: wrong ? 'Невірний пароль' : null,
                ),
                onSubmitted: (_) {
                  if (controller.text == _kPassword) {
                    Navigator.pop(ctx, true);
                  } else {
                    setS(() => wrong = true);
                    controller.clear();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Скасувати',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _goldColor,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (controller.text == _kPassword) {
                  Navigator.pop(ctx, true);
                } else {
                  setS(() => wrong = true);
                  controller.clear();
                }
              },
              child: const Text('Увійти'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) setState(() => _unlocked = true);
  }

  void _openFullscreen() {
    final image = buildNotationImage(widget.partitureUrl);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenNotationScreen(child: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                const Icon(Icons.library_music, color: _goldColor, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Партитура',
                    style: TextStyle(
                      color: _goldColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (_unlocked)
                  IconButton(
                    onPressed: _openFullscreen,
                    icon: const Icon(Icons.fullscreen,
                        color: Colors.white70, size: 24),
                    tooltip: 'Повний екран',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Вміст
          if (!_unlocked)
            GestureDetector(
              onTap: _askPassword,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, color: _goldColor, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Натисніть, щоб ввести пароль',
                      style: TextStyle(color: Color(0xFFCCDDCC), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _openFullscreen,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EFE4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      FittedBox(
                        fit: BoxFit.contain,
                        child: buildNotationImage(widget.partitureUrl),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Повний екран',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── ПОВНОЕКРАННИЙ ПЕРЕГЛЯДАЧ НОТАЦІЙ — зображення ─────────────────────────

class _FullscreenNotationScreen extends StatefulWidget {
  final Widget child;
  const _FullscreenNotationScreen({required this.child});

  @override
  State<_FullscreenNotationScreen> createState() => _FullscreenNotationScreenState();
}

class _FullscreenNotationScreenState extends State<_FullscreenNotationScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8.0,
              child: Center(child: widget.child),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ПОВНОЕКРАННИЙ ПЕРЕГЛЯДАЧ ГРАФІЧНИХ НОТ з кнопкою Play ──────────────────

class _FullscreenGraphicNotationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> notes;
  final int tempo;
  const _FullscreenGraphicNotationScreen({required this.notes, required this.tempo});

  @override
  State<_FullscreenGraphicNotationScreen> createState() =>
      _FullscreenGraphicNotationScreenState();
}

class _FullscreenGraphicNotationScreenState
    extends State<_FullscreenGraphicNotationScreen> {
  late int _tempo;
  bool _isPlaying = false;
  int _currentNoteIndex = -1;
  int? _countdown;
  Timer? _noteTimer;
  Timer? _countdownTimer;
  final ScrollController _scroll = ScrollController();

  static const _beats = [4.0, 2.0, 1.0, 0.5, 0.25];

  static const _bgColor   = Color(0xFF1C2B1E);
  static const _goldColor = Color(0xFFD4A017);

  @override
  void initState() {
    super.initState();
    _tempo = widget.tempo;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _noteTimer?.cancel();
    _countdownTimer?.cancel();
    _scroll.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startPlayback() {
    _noteTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() { _countdown = 5; _isPlaying = false; _currentNoteIndex = -1; });
    _runCountdown();
  }

  void _runCountdown() {
    _countdownTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final next = (_countdown ?? 1) - 1;
      if (next <= 0) {
        setState(() { _countdown = null; _isPlaying = true; _currentNoteIndex = 0; });
        _scheduleNext();
      } else {
        setState(() => _countdown = next);
        _runCountdown();
      }
    });
  }

  void _stopPlayback() {
    _noteTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() { _isPlaying = false; _currentNoteIndex = -1; _countdown = null; });
  }

  void _scheduleNext() {
    if (_currentNoteIndex >= widget.notes.length) { _stopPlayback(); return; }
    _scrollTo(_currentNoteIndex);
    final item = widget.notes[_currentNoteIndex];
    final t = item['t'] ?? 'n';
    final double b = t == 'n' ? _beats[(item['d'] as num).toInt()] : 1.0;
    final ms = (b * 60000.0 / _tempo).round();
    _noteTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _currentNoteIndex++);
      _scheduleNext();
    });
  }

  void _scrollTo(int index) {
    if (!_scroll.hasClients) return;
    final target = (index * 62.0 - 80).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // Нотаційна сітка — займає весь доступний простір
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: NotationDisplayWidget(
                notes: widget.notes,
                currentNoteIndex: _currentNoteIndex,
                scrollController: _scroll,
              ),
            ),
          ),
          // Панель керування внизу
          Container(
            color: const Color(0xFF162018),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Відлік
                if (_countdown != null)
                  Container(
                    width: 40, height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _goldColor,
                      boxShadow: [BoxShadow(color: _goldColor.withValues(alpha: 0.5), blurRadius: 8)],
                    ),
                    child: Center(
                      child: Text('$_countdown',
                          style: const TextStyle(color: Colors.black,
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                // BPM
                const Icon(Icons.speed, color: _goldColor, size: 16),
                const SizedBox(width: 6),
                const Text('BPM:', style: TextStyle(color: _goldColor, fontSize: 13)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 56,
                  child: Text('$_tempo',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const Spacer(),
                // Play / Stop
                GestureDetector(
                  onTap: (_isPlaying || _countdown != null) ? _stopPlayback : _startPlayback,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_isPlaying || _countdown != null) ? Colors.red[700] : _goldColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (_isPlaying || _countdown != null)
                              ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.black, size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _countdown != null ? 'Скасувати'
                              : _isPlaying ? 'Стоп' : 'Грати',
                          style: const TextStyle(color: Colors.black,
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Закрити
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
/// Відкриває переглядач нот сигналу (зображення, аудіо до нот, графічні
/// ноти, текст, партитура). Використовується з деталей сигналу та з
/// тренажера «Примітивні ноти».
Future<void> openSignalNotation(BuildContext context, HuntingSignal signal) async {
  final notationUrl = signal.notationUrl;
  final hasNotationData = signal.notationData != null && signal.notationData!.isNotEmpty;
  final hasText = signal.signalText != null && signal.signalText!.isNotEmpty;
  final hasPartiture = signal.partitureUrl != null && signal.partitureUrl!.isNotEmpty;

  if ((notationUrl == null || notationUrl.isEmpty) && !hasNotationData && !hasText && !hasPartiture) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ноти не додані для цього сигналу')),
    );
    return;
  }

  // PDF — відкриваємо в браузері
  if (notationUrl != null && notationUrl.toLowerCase().endsWith('.pdf')) {
    final uri = Uri.tryParse(notationUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  String? displayUrl;
  if (notationUrl != null && notationUrl.isNotEmpty) {
    if (notationUrl.startsWith('assets/') || notationUrl.startsWith('/')) {
      displayUrl = notationUrl;
    } else {
      final imageUrl = MediaCacheService.toImageUrl(notationUrl);
      try {
        final cached = await MediaCacheService.getLocalNotationPath(imageUrl);
        if (cached != null) {
          displayUrl = cached;
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Завантаження нот...'), duration: Duration(seconds: 10)),
            );
          }
          displayUrl = await MediaCacheService.downloadNotation(imageUrl);
          if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      } catch (_) {
        if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        displayUrl = imageUrl;
      }
    }
  }

  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NotationViewerScreen(
        notationUrl: displayUrl,
        notationAudioUrl: signal.notationAudioUrl,
        title: signal.name,
        signalText: signal.signalText,
        notationNotes: signal.notationData,
        notationTempo: signal.notationTempo,
        partitureUrl: signal.partitureUrl,
      ),
    ),
  );
}
