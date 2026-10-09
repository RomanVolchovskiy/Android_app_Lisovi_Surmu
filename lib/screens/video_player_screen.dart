import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hunting_signals/services/media_cache_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({super.key, required this.videoUrl, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  WebViewController? _webController;
  bool _isYouTube = false;
  bool _initialized = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  String? _error;
  String _statusText = 'Підготовка відео...';
  Timer? _uiTimer;

  // Відновлення після обриву мережі: плеєр після помилки мережі вже не
  // докачує потік (а play() починає з нуля), тож запам'ятовуємо позицію
  // і, щойно мережа повертається, створюємо новий контролер з того місця.
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  bool _wantsPlay = false;
  bool _reconnecting = false;
  bool _attemptInFlight = false;
  bool _disposed = false;
  Timer? _retryTimer;

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
      } else {
        if (_isDriveUrl) {
          setState(() => _statusText = 'Завантаження з Google Drive...');
        }
        _controller = _createController();
        await _finalizeController();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      // Відео не відкрилося (найчастіше — немає мережі): пробуємо ще,
      // поки екран відкритий; щойно вдасться, помилка зникне.
      if (_isNetworkSource) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 3), () {
          final failed = _controller;
          _controller = null;
          failed?.dispose();
          if (!_disposed) _initPlayer();
        });
      }
    }
  }

  bool get _isDriveUrl =>
      widget.videoUrl.contains('drive.google.com') ||
      widget.videoUrl.contains('drive.usercontent.google.com') ||
      widget.videoUrl.contains('lh3.googleusercontent.com');

  bool get _isNetworkSource =>
      !_isYouTube && !widget.videoUrl.startsWith('assets/');

  VideoPlayerController _createController() {
    if (widget.videoUrl.startsWith('assets/')) {
      return VideoPlayerController.asset(widget.videoUrl);
    }
    final url = _isDriveUrl
        ? MediaCacheService.toAudioDownloadUrl(widget.videoUrl)
        : widget.videoUrl;
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _finalizeController() async {
    setState(() => _statusText = 'Ініціалізація плеєра...');
    await _controller!.initialize();
    if (mounted) {
      setState(() {
        _initialized = true;
        _error = null;
      });
      _controller!.addListener(_onPlayerUpdate);
      // Браузери блокують автовідтворення зі звуком: жест користувача
      // губиться за час await initialize(). Лишаємо на паузі — глядач
      // натисне play сам, і це вже буде справжній жест.
      if (!kIsWeb) {
        _controller!.play();
        _wantsPlay = true;
      }
      _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onPlayerUpdate() {
    final value = _controller?.value;
    if (value == null || _reconnecting) return;
    if (value.hasError) {
      if (_isNetworkSource) _startReconnect();
      return;
    }
    if (value.isInitialized && value.position > Duration.zero) {
      _lastPosition = value.position;
      _lastDuration = value.duration;
    }
  }

  void _startReconnect() {
    _reconnecting = true;
    if (mounted) setState(() {});
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 3), (_) => _tryReconnect());
  }

  Future<void> _tryReconnect() async {
    if (_attemptInFlight || _disposed || !_reconnecting) return;
    _attemptInFlight = true;
    final fresh = _createController();
    try {
      // Без мережі initialize() падає (або висить) — тоді просто спробуємо ще.
      await fresh.initialize().timeout(const Duration(seconds: 20));
      if (_disposed) {
        await fresh.dispose();
        return;
      }
      await fresh.seekTo(_lastPosition);
      if (_wantsPlay) {
        try {
          await fresh.play();
        } catch (_) {
          // У браузері автостарт без жесту може бути заборонений.
        }
      }
      final old = _controller;
      old?.removeListener(_onPlayerUpdate);
      fresh.addListener(_onPlayerUpdate);
      _retryTimer?.cancel();
      setState(() {
        _controller = fresh;
        _reconnecting = false;
      });
      // Старий контролер ще намальований у поточному кадрі.
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    } catch (_) {
      await fresh.dispose();
    } finally {
      _attemptInFlight = false;
    }
  }

  String _formatTime(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _togglePlay() {
    if (_isYouTube || _controller == null) return;
    if (_reconnecting) {
      // Не стартуємо мертвий контролер з нуля — лише запам'ятовуємо намір.
      setState(() => _wantsPlay = !_wantsPlay);
      if (_wantsPlay) _tryReconnect();
      return;
    }
    setState(() {
      final playing = _controller!.value.isPlaying;
      playing ? _controller!.pause() : _controller!.play();
      _wantsPlay = !playing;
    });
  }

  void _seek(double seconds) {
    if (_isYouTube || _controller == null) return;
    final target = Duration(seconds: seconds.toInt());
    if (_reconnecting) {
      setState(() => _lastPosition = target);
      return;
    }
    _controller!.seekTo(target);
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
    _disposed = true;
    _uiTimer?.cancel();
    _retryTimer?.cancel();
    _restoreOrientation();
    if (!_isYouTube && _initialized && _controller != null) {
      _controller!.removeListener(_onPlayerUpdate);
      _controller!.pause();
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

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

  Widget _buildPortrait(BuildContext context, MediaQueryData mq) {
    return Column(
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
        Container(height: 2,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_bgColor, _goldColor, _goldColor, _bgColor]))),
        Expanded(
          child: _error != null ? _buildError() :
                 !_initialized ? _buildLoading() :
                 _buildVideoArea(),
        ),
        if (_initialized && _error == null)
          _buildControlsPanel(context, compact: false),
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

  Widget _buildLandscape(BuildContext context) {
    final mq = MediaQuery.of(context);
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        children: [
          Positioned.fill(
            child: _error != null ? _buildError() :
                   !_initialized ? _buildLoading() :
                   _buildVideoArea(),
          ),
          if (_initialized && _error == null && _showControls)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildControlsPanel(context, compact: true),
            ),
          if (_showControls)
            Positioned(
              top: mq.padding.top + 4,
              left: 4,
              child: _overlayIconBtn(Icons.arrow_back_ios_new,
                  () => Navigator.pop(context)),
            ),
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
          if (_showControls)
            Positioned(
              top: mq.padding.top + 4,
              right: mq.padding.right + 4,
              child: _overlayIconBtn(Icons.fullscreen_exit, _toggleFullscreen),
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

  Widget _buildVideoArea() {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (_reconnecting) _buildReconnectBanner(),
        ],
      ),
    );
  }

  Widget _buildReconnectBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _goldColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: _goldColor, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Немає з\'єднання. Відео продовжиться з '
              '${_formatTime(_lastPosition)}, щойно з\'явиться інтернет',
              style: const TextStyle(color: _goldLight, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(BuildContext context, {required bool compact}) {
    final value = _controller!.value;
    final pos = _reconnecting ? _lastPosition : value.position;
    final dur = _reconnecting ? _lastDuration : value.duration;
    final progress = dur.inMilliseconds > 0
        ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
    final mq = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: compact ? Colors.black.withValues(alpha: 0.75) : _woodColor,
        border: compact ? null : const Border(top: BorderSide(color: _goldColor, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, compact ? 6 : 10,
        16, compact ? mq.padding.bottom + 6 : 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _VidControlBtn(
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
              _VidControlBtn(
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
            child: const Icon(Icons.movie, color: _goldColor, size: 42),
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
            if (_isNetworkSource) ...[
              const SizedBox(height: 14),
              const Text('Перевірте інтернет — відео відкриється автоматично',
                  style: TextStyle(color: _goldLight, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _VidControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _VidControlBtn({required this.icon, required this.onTap, this.size = 44});

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
