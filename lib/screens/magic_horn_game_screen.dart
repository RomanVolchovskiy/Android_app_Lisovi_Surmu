import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hunting_signals/config/site_info.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/horn_synth.dart';

/// Тренажер «Чарівна сурма» — ритмічна гра на кшталт Piano Tiles у
/// 3D-перспективі та мисливському стилі. Порт веб-версії
/// (site/js/views/trainer-horn.js) з тією самою логікою.
///
/// П'ять доріжок — п'ять висот сурми (ДО, СОЛЬ, ДО2, МІ2, СОЛЬ2). Плитки —
/// ноти з графічної нотації сигналу (notationData); довжина плитки —
/// тривалість ноти. Влучив на лінії — звучить нота; пропустив — промах.
class MagicHornGameScreen extends StatefulWidget {
  final HuntingSignal signal;
  const MagicHornGameScreen({super.key, required this.signal});

  @override
  State<MagicHornGameScreen> createState() => _MagicHornGameScreenState();
}

// висота в notationData (0 = СОЛЬ2 … 4 = ДО) → доріжка зліва направо
const _pitchToLane = [4, 3, 2, 1, 0];
const _beats = [4.0, 2.0, 1.0, 0.5, 0.25];
const _fallSeconds = 2.4;
const _windowGood = 0.28;
const _windowPerfect = 0.10;
const _perspective = 0.9;
const _gold = Color(0xFFD4A017);
const _dkBg = Color(0xFF1B2A1E);
const _dkCard = Color(0xFF243328);
const _dkBorder = Color(0xFF4A6741);
const _dkText = Color(0xFFCCDDCC);
const _keysPrefs = 'horn_keys_v1';

class _Tile {
  final int lane;
  final double time; // секунда, коли низ плитки на лінії
  final double dur;
  bool hit = false;
  bool missed = false;
  double missedAt = 0;
  String? judged; // 'perfect' | 'good'
  _Tile(this.lane, this.time, this.dur);
}

class _Flash {
  final int lane;
  final double until; // за «настінним» часом (секунди)
  final Color color;
  _Flash(this.lane, this.until, this.color);
}

class _MagicHornGameScreenState extends State<MagicHornGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _synth = HornSynth();
  late final Ticker _ticker;
  final _focus = FocusNode();

  // налаштування
  double _speed = 1.0;
  List<String> _keys = ['1', '2', '3', '4', '5'];

  // стан раунду
  List<_Tile> _tiles = [];
  double _total = 0, _spb = 0.6;
  double _t0 = 0; // performance-час старту (мс)
  bool _running = false, _finished = false, _demo = false;
  double? _pausedAt;
  int _countdown = 0;
  String _status = '';
  Color _statusColor = _gold;
  Timer? _statusTimer;
  int _points = 0, _streak = 0, _best = 0, _perfect = 0, _good = 0, _miss = 0, _wrong = 0;
  final List<_Flash> _flashes = [];
  bool _showStart = true, _showPause = false, _showResult = false;

  int get _baseTempo => widget.signal.notationTempo ?? 90;
  double get _tempo => _baseTempo * _speed;
  List<Map<String, dynamic>> get _notes => widget.signal.notationData ?? const [];

  double _wallMs() => DateTime.now().microsecondsSinceEpoch / 1000.0;
  double _now() => ((_pausedAt ?? _wallMs()) - _t0) / 1000.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) => _tick())..start();
    _synth.ensureReady();
    _loadKeys();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _statusTimer?.cancel();
    _synth.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_keysPrefs);
    if (saved != null && saved.length == 5 && saved.every((k) => k.isNotEmpty)) {
      setState(() => _keys = saved);
    }
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keysPrefs, _keys);
  }

  // ── Плитки ──────────────────────────────────────────────────────────────
  void _buildTiles() {
    final spb = 60 / _tempo;
    double beat = 0;
    final tiles = <_Tile>[];
    for (final item in _notes) {
      final t = item['t'] ?? 'n';
      if (t == 'n') {
        final d = (item['d'] as num?)?.toInt() ?? 2;
        final beats = _beats[d.clamp(0, 4)];
        final p = (item['p'] as num?)?.toInt() ?? 2;
        tiles.add(_Tile(_pitchToLane[p.clamp(0, 4)], beat * spb, beats * spb));
        beat += beats;
      } else {
        beat += 1; // вдих / пауза = 1 доля
      }
    }
    _tiles = tiles;
    _total = beat * spb;
    _spb = spb;
  }

  // ── Керування раундом ───────────────────────────────────────────────────
  void _start(bool demo) {
    _demo = demo;
    _buildTiles();
    _points = _streak = _best = _perfect = _good = _miss = _wrong = 0;
    _pausedAt = null;
    _running = false;
    _finished = false;
    setState(() {
      _showStart = _showPause = _showResult = false;
      _countdown = 3;
      _status = '3';
      _statusColor = _gold;
    });
    _synth.ensureReady();
    _focus.requestFocus();
    void tick() {
      if (!mounted) return;
      _countdown--;
      if (_countdown > 0) {
        setState(() => _status = '$_countdown');
        Future.delayed(const Duration(milliseconds: 700), tick);
      } else {
        setState(() {
          _status = 'Грай!';
          _t0 = _wallMs() + _fallSeconds * 1000;
          _running = true;
        });
        _statusTimer?.cancel();
        _statusTimer = Timer(const Duration(milliseconds: 500), () { if (mounted) setState(() => _status = ''); });
      }
    }
    Future.delayed(const Duration(milliseconds: 700), tick);
  }

  void _finish() {
    _running = false;
    _finished = true;
    setState(() => _showResult = true);
  }

  void _pause() {
    if (!_running || _pausedAt != null || _finished) return;
    _pausedAt = _wallMs();
    setState(() => _showPause = true);
  }

  void _resume() {
    if (_pausedAt == null) return;
    _t0 += _wallMs() - _pausedAt!;
    _pausedAt = null;
    setState(() => _showPause = false);
    _focus.requestFocus();
  }

  void _setStatus(String text, Color color) {
    _status = text;
    _statusColor = color;
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(milliseconds: 500), () { if (mounted) setState(() => _status = ''); });
  }

  // ── Дотик / клавіша ──────────────────────────────────────────────────────
  void _tap(int lane) {
    if (!_running) {
      // вільна гра до старту: почути ноту й перевірити клавішу
      _synth.play(lane);
      _flashes.add(_Flash(lane, _wallMs() / 1000 + 0.25, _gold.withValues(alpha: .28)));
      return;
    }
    if (_demo || _pausedAt != null) return;
    final t = _now();
    _Tile? bestTile;
    double bestDt = double.infinity;
    for (final tile in _tiles) {
      if (tile.lane != lane || tile.hit || tile.missed) continue;
      final dt = t - tile.time;
      if (dt < -_windowGood) break;
      if (dt.abs() <= _windowGood && dt.abs() < bestDt) { bestTile = tile; bestDt = dt; }
    }
    if (bestTile != null) {
      bestTile.hit = true;
      if (bestDt.abs() <= _windowPerfect) {
        bestTile.judged = 'perfect'; _perfect++; _points += 100 + _streak * 10; _setStatus('Ідеально!', _gold);
      } else {
        bestTile.judged = 'good'; _good++; _points += 50 + _streak * 5; _setStatus('Добре', const Color(0xFF9CCC65));
      }
      _streak++; _best = max(_best, _streak);
      _synth.play(lane);
      _flashes.add(_Flash(lane, _wallMs() / 1000 + 0.18, _gold.withValues(alpha: .28)));
    } else {
      _wrong++; _streak = 0;
      _flashes.add(_Flash(lane, _wallMs() / 1000 + 0.22, const Color(0xFFE53935).withValues(alpha: .25)));
    }
    setState(() {});
  }

  int _laneForKey(KeyEvent e) {
    final label = _keyName(e.logicalKey);
    final i = _keys.indexWhere((k) => k.toLowerCase() == label.toLowerCase());
    return i;
  }

  static String _keyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'Пробіл';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    final l = key.keyLabel;
    return l.isNotEmpty ? l : key.debugName ?? '?';
  }

  // ── Кадр ────────────────────────────────────────────────────────────────
  void _tick() {
    final wall = _wallMs() / 1000;
    _flashes.removeWhere((f) => f.until <= wall);
    if (_running && _pausedAt == null) {
      final t = _now();
      for (final tile in _tiles) {
        if (tile.hit || tile.missed) continue;
        final dt = t - tile.time;
        if (_demo && dt >= 0) {
          tile.hit = true; tile.judged = 'perfect'; _synth.play(tile.lane);
        } else if (dt > _windowGood) {
          tile.missed = true; tile.missedAt = t; _miss++; _streak = 0;
          _setStatus('Промах', const Color(0xFFEF5350));
          _flashes.add(_Flash(tile.lane, wall + 0.3, const Color(0xFFE53935).withValues(alpha: .18)));
        }
      }
      if (t > _total + 1.6) { _finish(); return; }
    }
    if (mounted) setState(() {});
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dkBg,
      appBar: AppBar(
        backgroundColor: _dkBg,
        foregroundColor: Colors.white,
        title: const Text('Чарівна сурма', style: TextStyle(fontSize: 18)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: _plaque(),
        ),
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          final lane = _laneForKey(e);
          if (lane >= 0) { _tap(lane); return KeyEventResult.handled; }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            _hud(),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, c) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _tap(_laneAt(d.localPosition, c.biggest)),
                      child: CustomPaint(
                        painter: _ArenaPainter(
                          tiles: _tiles,
                          t: _running ? _now() : -_fallSeconds,
                          running: _running,
                          spb: _spb,
                          flashes: _flashes,
                          keys: _keys,
                          wall: _wallMs() / 1000,
                        ),
                      ),
                    ),
                  ),
                  if (_status.isNotEmpty)
                    Positioned(
                      left: 0, right: 0, top: 0, bottom: 0,
                      child: Align(
                        alignment: const Alignment(0, -0.25),
                        child: IgnorePointer(
                          child: Text(_status, textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: _statusColor,
                                  shadows: const [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))])),
                        ),
                      ),
                    ),
                  if (_showStart) _overlay(_startCard()),
                  if (_showPause) _overlay(_pauseCard()),
                  if (_showResult) _overlay(_resultCard()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plaque() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5A3B1C), Color(0xFF3B2410)]),
        border: Border(bottom: BorderSide(color: _gold, width: 2)),
      ),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icons/icon1.png', width: 34, height: 34, fit: BoxFit.cover)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
            Text(SiteInfo.college, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFFFFF1C1), fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'serif')),
            Text(SiteInfo.ensemble, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xCCF5E6C8), fontSize: 11)),
          ]),
        ),
        const Text('𝄞 ♪ ♫ ♩ ♬', style: TextStyle(color: _gold, fontSize: 14, letterSpacing: 3)),
      ]),
    );
  }

  Widget _hud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _dkBorder))),
      child: Row(children: [
        const Icon(Icons.stars, color: _gold, size: 20),
        const SizedBox(width: 6),
        Text('$_points', style: const TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        if (_streak >= 2) Text('×$_streak', style: const TextStyle(color: Colors.white, fontSize: 13)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.pause, color: _gold), tooltip: 'Пауза', onPressed: _pause, visualDensity: VisualDensity.compact),
        const Spacer(),
        Text('${widget.signal.name} · ${_tempo.round()} BPM${_demo && _running ? ' · демо' : ''}',
            style: const TextStyle(color: _dkText, fontSize: 12), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _overlay(Widget card) {
    // Дотик по затемненню поза карткою до старту — вільна гра нотою доріжки.
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) { if (!_running) _tap(_laneAt(d.localPosition, c.biggest)); },
        child: Container(
          color: const Color(0xDB141F16),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: GestureDetector(
              onTapDown: (_) {},
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: card),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _dkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _dkBorder)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _cardHead() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icons/icon1.png', width: 44, height: 44, fit: BoxFit.cover)),
      const SizedBox(width: 10),
      const Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(SiteInfo.college, style: TextStyle(color: Color(0xFFFFF1C1), fontSize: 12, fontFamily: 'serif', fontWeight: FontWeight.w600)),
          Text(SiteInfo.ensemble, style: TextStyle(color: _dkText, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _dkButton(String label, IconData icon, VoidCallback onTap, {bool fill = false}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: fill ? _dkBg : _gold),
      label: Text(label, style: TextStyle(color: fill ? _dkBg : _gold, fontWeight: FontWeight.w600, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        backgroundColor: fill ? _gold : Colors.transparent,
        side: const BorderSide(color: _gold),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _speedControl() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.speed, color: _dkText, size: 16),
        const SizedBox(width: 4),
        const Text('Швидкість', style: TextStyle(color: _dkText, fontSize: 12)),
        const Spacer(),
        Text('${_speed.toStringAsFixed(1)}× · ${_tempo.round()} BPM', style: const TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      Row(children: [
        const Text('повільно', style: TextStyle(color: Colors.white54, fontSize: 11)),
        Expanded(
          child: Slider(
            value: _speed, min: 0.5, max: 2.0, divisions: 15, activeColor: _gold, inactiveColor: Colors.white24,
            onChanged: (v) => setState(() => _speed = v),
          ),
        ),
        const Text('швидко', style: TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    ]);
  }

  Widget _startCard() {
    return _card([
      _cardHead(),
      const SizedBox(height: 6),
      const Text('📯', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
      const Text('Чарівна сурма', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _gold, fontFamily: 'serif')),
      const SizedBox(height: 6),
      Text(widget.signal.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text(
        'Плитки — ноти сигналу — летять назустріч п’ятьма доріжками за висотою звуку. Торкніться доріжки, коли плитка дійде до золотої лінії, і сурма заграє ноту. До старту можна вільно грати ноти доріжками або клавішами.',
        textAlign: TextAlign.center, style: TextStyle(color: _dkText, fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 12),
      _speedControl(),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _dkButton('Почати', Icons.play_arrow, () => _start(false), fill: true),
        _dkButton('Демо', Icons.play_circle, () => _start(true)),
        _dkButton('Клавіші', Icons.keyboard, _openKeysDialog),
      ]),
    ]);
  }

  Widget _pauseCard() {
    return _card([
      const Text('Пауза', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _gold)),
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _dkButton('Продовжити', Icons.play_arrow, _resume, fill: true),
        _dkButton('Спочатку', Icons.replay, () { _pausedAt = null; _start(_demo); }),
      ]),
    ]);
  }

  Widget _resultCard() {
    final hits = _perfect + _good;
    final totalNotes = _tiles.length;
    final acc = totalNotes == 0 ? 0 : (hits / totalNotes * 100).round();
    final stars = acc >= 95 ? '★★★' : acc >= 75 ? '★★☆' : acc >= 50 ? '★☆☆' : '☆☆☆';
    return _card([
      _cardHead(),
      const SizedBox(height: 6),
      Text(stars, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, color: _gold, letterSpacing: 4)),
      Text(_demo ? 'Демо' : '$_points', textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(_demo ? 'Так звучить сигнал. Тепер спробуйте самі!' : 'Точність $acc% · найдовша серія ×$_best',
          textAlign: TextAlign.center, style: const TextStyle(color: _dkText)),
      if (!_demo) ...[
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 16, children: [
          Text('Ідеально: $_perfect', style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text('Добре: $_good', style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text('Промахи: $_miss', style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text('Мимо: $_wrong', style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      ],
      const SizedBox(height: 12),
      _speedControl(),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        _dkButton('Ще раз', Icons.replay, () => _start(false), fill: true),
        _dkButton('Демо', Icons.play_circle, () => _start(true)),
        _dkButton('Клавіші', Icons.keyboard, _openKeysDialog),
        _dkButton('Інший сигнал', Icons.list, () => Navigator.pop(context)),
      ]),
    ]);
  }

  // ── Призначення клавіш ──────────────────────────────────────────────────
  Future<void> _openKeysDialog() async {
    final draft = List<String>.from(_keys);
    int? capturing;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Focus(
          autofocus: true,
          onKeyEvent: (node, e) {
            if (capturing == null || e is! KeyDownEvent) return KeyEventResult.ignored;
            final i = capturing!;
            if (e.logicalKey != LogicalKeyboardKey.escape) {
              final name = _keyName(e.logicalKey);
              final dup = draft.indexWhere((k) => k == name);
              if (dup >= 0 && dup != i) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Клавіша вже призначена ноті ${HornSynth.labels[dup]}')));
              } else {
                draft[i] = name;
                _synth.play(i);
              }
            }
            setS(() => capturing = null);
            return KeyEventResult.handled;
          },
          child: AlertDialog(
            backgroundColor: _dkCard,
            title: const Text('Клавіші для нот', style: TextStyle(color: _gold)),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Натисніть «Змінити» біля ноти, потім — бажану клавішу на підключеній клавіатурі. Esc — скасувати.',
                    style: TextStyle(color: _dkText, fontSize: 13)),
                const SizedBox(height: 8),
                for (var i = 0; i < 5; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _dkBorder))),
                    child: Row(children: [
                      SizedBox(width: 64, child: Text(HornSynth.labels[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      Container(
                        constraints: const BoxConstraints(minWidth: 64),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: _gold), borderRadius: BorderRadius.circular(6)),
                        child: Text(capturing == i ? '…' : draft[i], textAlign: TextAlign.center,
                            style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setS(() => capturing = i),
                        icon: const Icon(Icons.keyboard, size: 16, color: _gold),
                        label: Text(capturing == i ? 'Натисніть клавішу' : 'Змінити', style: const TextStyle(color: _gold, fontSize: 12)),
                      ),
                    ]),
                  ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () { _keys = ['1', '2', '3', '4', '5']; _saveKeys(); Navigator.pop(ctx); }, child: const Text('Скинути', style: TextStyle(color: _gold))),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати', style: TextStyle(color: _gold))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _dkBg),
                onPressed: () { _keys = draft; _saveKeys(); Navigator.pop(ctx); },
                child: const Text('Зберегти'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
    _focus.requestFocus();
  }

  int _laneAt(Offset p, Size size) {
    final g = _Geom(size);
    final s = (1 - (g.hitY - p.dy) / (g.hitY - g.horizonY)).clamp(0.05, 1.0);
    final xNear = size.width / 2 + (p.dx - size.width / 2) / s;
    return (xNear / g.laneW).floor().clamp(0, 4);
  }
}

// ── Геометрія перспективи ───────────────────────────────────────────────────
class _Geom {
  final Size size;
  _Geom(this.size);
  double get w => size.width;
  double get h => size.height;
  double get horizonY => h * 0.10;
  double get hitY => h * 0.84;
  double get laneW => w / 5;

  static double scaleAt(double d) => _perspective / (max(d, -0.35) + _perspective);

  /// laneEdge 0..5, d — глибина в секундах до лінії удару.
  Offset project(double laneEdge, double d) {
    final s = scaleAt(d);
    final xNear = laneEdge * laneW;
    return Offset(w / 2 + (xNear - w / 2) * s, hitY - (hitY - horizonY) * (1 - s));
  }
}

// ── Малювання арени ─────────────────────────────────────────────────────────
class _ArenaPainter extends CustomPainter {
  final List<_Tile> tiles;
  final double t, spb, wall;
  final bool running;
  final List<_Flash> flashes;
  final List<String> keys;

  _ArenaPainter({required this.tiles, required this.t, required this.running, required this.spb, required this.flashes, required this.keys, required this.wall});

  static const _lanes = HornSynth.labels;
  static final _trees = List.generate(70, (i) => (x: (i * 0.0137 + 0.005) % 1, h: 0.55 + ((i * 7919) % 100) / 100 * 0.9, w: 0.6 + ((i * 104729) % 100) / 100 * 0.6));

  Path _quad(Offset a, Offset b, Offset c, Offset d) => Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy)..lineTo(d.dx, d.dy)..close();

  void _drawBackground(Canvas g, _Geom G) {
    final w = G.w, h = G.h, horizonY = G.horizonY;
    // небо
    g.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0C1A10), Color(0xFF24361F), Color(0xFF6B4A17)], stops: [0, .6, 1]).createShader(Rect.fromLTWH(0, 0, w, horizonY * 1.3)));
    // зорі
    final star = Paint()..color = const Color(0x8CFFF0C8);
    for (var i = 0; i < 40; i++) {
      g.drawRect(Rect.fromLTWH(((i * 977) % 1000) / 1000 * w, ((i * 631) % 1000) / 1000 * horizonY * 0.7, 1.5, 1.5), star);
    }
    // місяць
    final mx = w * 0.8, my = horizonY * 0.45, mr = min(w, h) * 0.045;
    g.drawCircle(Offset(mx, my), mr * 3, Paint()..shader = const RadialGradient(colors: [Color(0xE6FFECAA), Color(0x59FFECAA), Color(0x00FFECAA)], stops: [0, .25, 1]).createShader(Rect.fromCircle(center: Offset(mx, my), radius: mr * 3)));
    g.drawCircle(Offset(mx, my), mr, Paint()..color = const Color(0xFFFFF1C1));
    // світіння біля горизонту
    g.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = const RadialGradient(colors: [Color(0x73E6AA3C), Color(0x00E6AA3C)]).createShader(Rect.fromCircle(center: Offset(w / 2, horizonY), radius: w * 0.45)));
    // сосни
    void trees(Color color, double scale, double yOff) {
      final p = Paint()..color = color;
      for (final tr in _trees) {
        final th = tr.h * horizonY * scale, tw = tr.w * horizonY * 0.55 * scale, x = tr.x * w, base = horizonY + yOff;
        g.drawPath(Path()..moveTo(x - tw / 2, base)..lineTo(x, base - th)..lineTo(x + tw / 2, base)..close(), p);
        g.drawPath(Path()..moveTo(x - tw * 0.36, base - th * 0.42)..lineTo(x, base - th * 1.02)..lineTo(x + tw * 0.36, base - th * 0.42)..close(), p);
      }
    }
    trees(const Color(0xFF1A2B1C), 0.8, 2);
    trees(const Color(0xFF0B140D), 1.0, 6);
    // земля
    g.drawRect(Rect.fromLTWH(0, horizonY + 6, w, h - horizonY), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1C2A19), Color(0xFF0F1A10)]).createShader(Rect.fromLTWH(0, horizonY, w, h - horizonY)));
    // стежка
    for (var i = 0; i < 5; i++) {
      final a = G.project(i.toDouble(), 60), b = G.project(i + 1.0, 60), c = G.project(i + 1.0, -0.35), d = G.project(i.toDouble(), -0.35);
      g.drawPath(_quad(a, b, c, d), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: i.isOdd ? const [Color(0xFF3A2D18), Color(0xFF5A4326)] : const [Color(0xFF33281A), Color(0xFF4E3A22)]).createShader(Rect.fromLTWH(0, horizonY, w, h - horizonY)));
    }
    // мотузки
    final rope = Paint()..color = const Color(0x59E6C88C)..strokeWidth = 1.5;
    for (var i = 0; i <= 5; i++) {
      g.drawLine(G.project(i.toDouble(), 60), G.project(i.toDouble(), -0.35), rope);
    }
    // серпанок
    final farY = G.project(0, _fallSeconds).dy, fogEnd = farY + (h - farY) * 0.22;
    g.drawRect(Rect.fromLTWH(0, horizonY, w, fogEnd - horizonY), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xE6464B2D), Color(0x6632321E), Color(0x0032321E)], stops: [0, .5, 1]).createShader(Rect.fromLTWH(0, horizonY, w, fogEnd - horizonY)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final G = _Geom(size);
    final w = G.w, h = G.h, hitY = G.hitY;
    _drawBackground(canvas, G);

    // ноти пливуть у небі, скрипковий ключ біля лінії
    const glyphs = ['♪', '♫', '♩', '♬'];
    for (var i = 0; i < 7; i++) {
      final phase = (wall * 0.05 + i / 7) % 1;
      final x = phase * w, y = G.horizonY * (0.25 + 0.5 * ((i * 37) % 10) / 10) + sin(wall * 1.2 + i) * 4;
      _text(canvas, glyphs[i % 4], Offset(x, y), 16, Color.fromRGBO(255, 230, 160, 0.3 + 0.2 * sin(wall + i)));
    }
    _text(canvas, '𝄞', Offset(18, hitY - 2), 34, _gold.withValues(alpha: .85));

    // спалахи
    for (final f in flashes) {
      canvas.drawPath(_quad(G.project(f.lane.toDouble(), 60), G.project(f.lane + 1.0, 60), G.project(f.lane + 1.0, -0.35), G.project(f.lane.toDouble(), -0.35)), Paint()..color = f.color);
    }
    // лінії долей
    if (running && spb > 0) {
      final p = Paint()..color = const Color(0x1AFFE6B4)..strokeWidth = 1;
      final first = (t / spb).ceil() * spb;
      for (var bt = first; bt < t + _fallSeconds; bt += spb) {
        canvas.drawLine(G.project(0, bt - t), G.project(5, bt - t), p);
      }
    }
    // зона та латунна лінія
    canvas.drawPath(_quad(G.project(0, _windowGood), G.project(5, _windowGood), G.project(5, -_windowGood * 0.8), G.project(0, -_windowGood * 0.8)), Paint()..color = _gold.withValues(alpha: .13));
    canvas.drawRect(Rect.fromLTWH(0, hitY - 5, w, 10), Paint()..color = _gold.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRect(Rect.fromLTWH(0, hitY - 3, w, 6), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE9A6), _gold, Color(0xFF8A6410)]).createShader(Rect.fromLTWH(0, hitY - 3, w, 6)));

    // плитки — від дальніх до ближніх; промахи завмирають на лінії ~1 с
    for (var i = tiles.length - 1; i >= 0; i--) {
      final tile = tiles[i];
      double dNear = tile.time - t, alpha = 1;
      if (tile.missed) {
        final since = t - tile.missedAt;
        if (since > 1.4) continue;
        dNear = max(dNear, -0.08);
        alpha = since < 1.0 ? 1 : 1 - (since - 1.0) / 0.4;
      }
      final dFarEdge = dNear + tile.dur;
      if (dNear > _fallSeconds || dFarEdge < -0.35) continue;
      final dn = max(dNear, -0.35), df = min(dFarEdge, _fallSeconds);
      if (!tile.missed) alpha = ((_fallSeconds - dn) / (_fallSeconds * 0.35)).clamp(0.15, 1.0);
      const pad = 0.06;
      _drawTile(canvas, tile, G.project(tile.lane + pad, df), G.project(tile.lane + 1 - pad, df), G.project(tile.lane + 1 - pad, dn), G.project(tile.lane + pad, dn), _Geom.scaleAt(dn), alpha.clamp(0.0, 1.0));
    }
    // дошка з підписами доріжок і клавішами
    canvas.drawRect(Rect.fromLTWH(0, h - 26, w, 26), Paint()..color = const Color(0xD9281A0A));
    canvas.drawRect(Rect.fromLTWH(0, h - 26, w, 1.5), Paint()..color = _gold);
    for (var i = 0; i < 5; i++) {
      _text(canvas, '${_lanes[i]}  [${keys[i]}]', Offset((i + 0.5) * G.laneW, h - 13), 12, const Color(0xFFF5E6C8), bold: true);
    }
  }

  void _drawTile(Canvas g, _Tile tile, Offset a, Offset b, Offset c, Offset d, double s, double alpha) {
    final lift = max(2.0, 7 * s);
    g.drawPath(_quad(d, c, Offset(c.dx, c.dy + lift), Offset(d.dx, d.dy + lift)), Paint()..color = (tile.missed ? const Color(0xFF4A1414) : const Color(0xFF3B2410)).withValues(alpha: alpha));
    final rect = Rect.fromLTRB(min(a.dx, d.dx), a.dy, max(b.dx, c.dx), c.dy);
    List<Color> colors;
    if (tile.hit) {
      colors = tile.judged == 'perfect' ? const [Color(0xFFFFE49A), Color(0xFFD4A017)] : const [Color(0xFFD9E8A8), Color(0xFF8BC34A)];
    } else if (tile.missed) {
      colors = const [Color(0xFFE57373), Color(0xFF8E1B1B)];
    } else {
      colors = const [Color(0xFFB07A3E), Color(0xFF8B5A2B), Color(0xFF6B4220)];
    }
    g.drawPath(_quad(a, b, c, d), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors.map((cl) => cl.withValues(alpha: alpha)).toList()).createShader(rect));
    if (!tile.hit && !tile.missed) {
      final grain = Paint()..color = const Color(0x593C230A).withValues(alpha: .35 * alpha)..strokeWidth = 1;
      for (final k in [0.25, 0.5, 0.75]) {
        g.drawLine(Offset(a.dx + (b.dx - a.dx) * k, a.dy + 2), Offset(d.dx + (c.dx - d.dx) * k, c.dy - 2), grain);
      }
    }
    g.drawPath(_quad(a, b, c, d), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6
      ..color = (tile.missed ? const Color(0xFFFF8A80) : tile.hit ? const Color(0xFFFFF3C4) : _gold).withValues(alpha: alpha));
    final fs = 9 + 6 * s;
    if (c.dy - a.dy > fs * 1.2) {
      final label = tile.missed ? '✕ ${_lanes[tile.lane]}' : '♪ ${_lanes[tile.lane]}';
      _text(g, label, Offset((c.dx + d.dx) / 2, c.dy - fs * 0.9), fs, (tile.missed ? const Color(0xFFFFEBEE) : tile.hit ? Colors.black54 : const Color(0xFFF5E6C8)).withValues(alpha: alpha), bold: true);
    }
  }

  void _text(Canvas g, String s, Offset center, double size, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(g, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter old) => true;
}
