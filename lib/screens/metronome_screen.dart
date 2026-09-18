import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hunting_signals/config/site_info.dart';
import 'package:hunting_signals/services/horn_synth.dart';

/// Тренажер «Метроном» — відбиває мисливський ріг: сильна доля — СОЛЬ2,
/// слабкі — ДО2, підрозділи — тихе ДО. Порт веб-версії
/// (site/js/views/trainer-metronome.js).
///
/// Ритм веде власний планувальник на Stopwatch: кожен удар призначається
/// на точний момент від старту, тож похибки таймерів не накопичуються.
class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

const _gold = Color(0xFFD4A017);
const _dkBg = Color(0xFF1B2A1E);
const _dkCard = Color(0xFF243328);
const _dkBorder = Color(0xFF4A6741);
const _dkText = Color(0xFFCCDDCC);
const _signatures = ['1/4', '2/4', '3/4', '4/4', '5/4', '6/8', '7/8', '9/8', '12/8'];
const _subdivisions = [(1, '♩', 'Чверті'), (2, '♫', 'Восьмі'), (3, '♪♪♪', 'Тріолі'), (4, '♬♬', 'Шістнадцяті')];
const _tempoNames = [
  (40, 'Grave'), (60, 'Largo'), (66, 'Larghetto'), (76, 'Adagio'), (108, 'Andante'),
  (120, 'Moderato'), (156, 'Allegro'), (176, 'Vivace'), (200, 'Presto'), (251, 'Prestissimo'),
];
String _tempoName(int bpm) => _tempoNames.firstWhere((e) => bpm < e.$1, orElse: () => (0, 'Prestissimo')).$2;

class _MetronomeScreenState extends State<MetronomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _synth = HornSynth();
  late final Ticker _ticker;
  final _clock = Stopwatch();

  int _bpm = 90;
  String _sig = '4/4';
  int _sub = 1;
  double _volume = 0.8;
  List<int> _accents = [2, 1, 1, 1]; // 2 акцент, 1 звичайна, 0 тиша

  bool _running = false;
  Timer? _timer;
  double _nextTime = 0; // секунди від старту _clock
  int _beat = 0, _subIdx = 0, _curBeat = -1;
  final List<double> _taps = [];

  int get _beatsInBar => int.parse(_sig.split('/')[0]);
  int get _noteValue => int.parse(_sig.split('/')[1]);
  double get _beatSeconds => (60 / _bpm) * (_noteValue == 8 ? 0.5 : 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) { if (_running && mounted) setState(() {}); })..start();
    _synth.ensureClicksReady();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _ticker.dispose();
    _synth.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _bpm = p.getInt('metro_bpm') ?? 90;
      final sig = p.getString('metro_sig');
      if (sig != null && _signatures.contains(sig)) _sig = sig;
      _sub = p.getInt('metro_sub') ?? 1;
      _volume = p.getDouble('metro_volume') ?? 0.8;
      final acc = p.getStringList('metro_accents');
      _accents = acc != null && acc.length == _beatsInBar ? acc.map(int.parse).toList() : _defaultAccents();
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('metro_bpm', _bpm);
    await p.setString('metro_sig', _sig);
    await p.setInt('metro_sub', _sub);
    await p.setDouble('metro_volume', _volume);
    await p.setStringList('metro_accents', _accents.map((a) => '$a').toList());
  }

  List<int> _defaultAccents() =>
      List.generate(_beatsInBar, (i) => (i == 0 || (_noteValue == 8 && i % 3 == 0)) ? 2 : 1);

  // ── Планувальник ────────────────────────────────────────────────────────
  void _start() {
    _synth.ensureClicksReady();
    _clock..reset()..start();
    _beat = 0; _subIdx = 0; _nextTime = 0.05; _curBeat = -1;
    setState(() => _running = true);
    _schedule();
  }

  void _stop() {
    _timer?.cancel(); _timer = null;
    _clock.stop();
    if (mounted) setState(() { _running = false; _curBeat = -1; });
  }

  void _schedule() {
    if (!_running) return;
    final now = _clock.elapsedMicroseconds / 1e6;
    final wait = ((_nextTime - now) * 1000).round();
    _timer = Timer(Duration(milliseconds: max(0, wait)), _fire);
  }

  void _fire() {
    if (!_running) return;
    final acc = _accents[_beat];
    if (_subIdx == 0) {
      if (acc == 2) {
        _synth.click(HornSynth.clickAccent, volume: _volume);
      } else if (acc == 1) {
        _synth.click(HornSynth.clickBeat, volume: _volume);
      }
      _curBeat = _beat;
    } else {
      _synth.click(HornSynth.clickSub, volume: _volume);
    }
    _nextTime += _beatSeconds / _sub;
    _subIdx++;
    if (_subIdx >= _sub) { _subIdx = 0; _beat = (_beat + 1) % _beatsInBar; }
    _schedule();
  }

  void _restartIfRunning() { if (_running) { _stop(); _start(); } }

  void _setBpm(int v) { setState(() => _bpm = v.clamp(30, 250)); _save(); }

  void _tap() {
    // tap-tempo рахується за системним часом, незалежно від планувальника
    final t = DateTime.now().microsecondsSinceEpoch / 1e6;
    if (_taps.isNotEmpty && t - _taps.last > 2) _taps.clear();
    _taps.add(t);
    if (_taps.length > 6) _taps.removeAt(0);
    if (_taps.length >= 2) {
      double sum = 0;
      for (var i = 1; i < _taps.length; i++) {
        sum += _taps[i] - _taps[i - 1];
      }
      _setBpm((60 / (sum / (_taps.length - 1))).round());
    }
    _synth.click(HornSynth.clickBeat, volume: _volume * 0.7);
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dkBg,
      appBar: AppBar(
        backgroundColor: _dkBg, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Метроном', style: TextStyle(fontSize: 18)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(46), child: _plaque()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(null, null, [
            SizedBox(
              height: 150,
              child: CustomPaint(painter: _PendulumPainter(phase: _phase(), running: _running)),
            ),
            const SizedBox(height: 6),
            Text('$_bpm', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: _gold, height: 1, fontFamily: 'serif')),
            Text(_tempoName(_bpm).toUpperCase(), textAlign: TextAlign.center,
                style: const TextStyle(color: _dkText, fontSize: 14, letterSpacing: 2)),
            Slider(value: _bpm.toDouble(), min: 30, max: 250, activeColor: _gold, inactiveColor: Colors.white24,
                onChanged: (v) => setState(() => _bpm = v.round()), onChangeEnd: (_) => _save()),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _step('−5', -5), _step('−1', -1),
              _btn(_running ? 'Стоп' : 'Старт', _running ? Icons.stop : Icons.play_arrow, () => _running ? _stop() : _start(), fill: true, big: true),
              _step('+1', 1), _step('+5', 5),
            ]),
            const SizedBox(height: 10),
            Center(child: _btn('Відстукати темп', Icons.touch_app, _tap)),
          ]),
          _card('Долі такту', Icons.radio_button_checked, [
            const Text('Натисніть на долю, щоб перемкнути: акцент → звичайна → тиша', style: TextStyle(color: _dkText, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                children: List.generate(_accents.length, _beatDot)),
          ]),
          _card('Розмір і підрозділ долі', Icons.straighten, [
            Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('Розмір', style: TextStyle(color: _dkText, fontSize: 13)),
              DropdownButton<String>(
                value: _sig, dropdownColor: _dkCard, style: const TextStyle(color: Colors.white),
                iconEnabledColor: _gold, underline: Container(height: 1, color: _gold),
                items: _signatures.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) { if (v == null) return; setState(() { _sig = v; _accents = _defaultAccents(); }); _save(); _restartIfRunning(); },
              ),
              const SizedBox(width: 8),
              const Text('Підрозділ', style: TextStyle(color: _dkText, fontSize: 13)),
              for (final (n, sym, title) in _subdivisions)
                Tooltip(message: title, child: _btn(sym, null, () { setState(() => _sub = n); _save(); _restartIfRunning(); }, fill: _sub == n)),
            ]),
          ]),
          _card('Звук', Icons.volume_up, [
            Row(children: [
              const Text('Гучність', style: TextStyle(color: _dkText, fontSize: 13)),
              Expanded(child: Slider(value: _volume, min: 0, max: 1, activeColor: _gold, inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() => _volume = v), onChangeEnd: (_) => _save())),
            ]),
            const Text('Сильна доля — СОЛЬ2, слабкі — ДО2, підрозділи — тихе ДО.', style: TextStyle(color: _dkText, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  double _phase() {
    if (!_running) return 0.25;
    final period = _beatSeconds * 2;
    final t = _clock.elapsedMicroseconds / 1e6 - 0.05 - _beatSeconds * 0.5;
    return (t % period) / period;
  }

  Widget _beatDot(int i) {
    final acc = _accents[i];
    final active = i == _curBeat && _running;
    final size = acc == 2 ? 44.0 : acc == 1 ? 36.0 : 28.0;
    return GestureDetector(
      onTap: () { setState(() => _accents[i] = (_accents[i] + 2) % 3); _save(); },
      child: Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: acc == 0 ? _dkText.withValues(alpha: .3) : _gold, width: 2),
          color: active ? (acc == 2 ? const Color(0xFFFFE9A6) : _gold) : (acc == 2 ? _gold.withValues(alpha: .35) : acc == 1 ? _gold.withValues(alpha: .15) : Colors.transparent),
          boxShadow: active ? [BoxShadow(color: _gold.withValues(alpha: .9), blurRadius: 16)] : null,
        ),
        child: Text('${i + 1}', style: TextStyle(color: active ? _dkBg : _dkText, fontWeight: FontWeight.bold, fontSize: 13)),
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
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(SiteInfo.college, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFFFFF1C1), fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'serif')),
            Text(SiteInfo.ensemble, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xCCF5E6C8), fontSize: 11)),
          ]),
        ),
        const Text('𝄞 ♩ ♩ ♩ ♩', style: TextStyle(color: _gold, fontSize: 14, letterSpacing: 3)),
      ]),
    );
  }

  Widget _card(String? title, IconData? icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _dkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _dkBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (title != null) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [Icon(icon, color: _gold, size: 16), const SizedBox(width: 8), Text(title, style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 13))]),
        ),
        ...children,
      ]),
    );
  }

  Widget _btn(String label, IconData? icon, VoidCallback onTap, {bool fill = false, bool big = false}) {
    final fg = fill ? _dkBg : _gold;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: fill ? _gold : Colors.transparent, side: const BorderSide(color: _gold),
        padding: EdgeInsets.symmetric(horizontal: big ? 24 : 12, vertical: big ? 12 : 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: big ? 16 : 13)),
      ]),
    );
  }

  Widget _step(String label, int d) => _btn(label, null, () => _setBpm(_bpm + d));
}

/// Маятник механічного метронома: дерев'яна дуга з поділками, латунний
/// грузик; за долю робить пів коливання.
class _PendulumPainter extends CustomPainter {
  final double phase;
  final bool running;
  _PendulumPainter({required this.phase, required this.running});

  @override
  void paint(Canvas g, Size size) {
    final w = size.width, hgt = size.height;
    final angle = sin(phase * pi * 2) * 0.55;
    final px = w / 2, py = hgt * 0.92, len = hgt * 0.78;
    final bob = Offset(px + sin(angle) * len, py - cos(angle) * len);
    final arc = Rect.fromCircle(center: Offset(px, py), radius: len + 8);
    g.drawArc(arc, pi * 1.22, pi * 0.56, false, Paint()..color = const Color(0xE65A3B1C)..style = PaintingStyle.stroke..strokeWidth = 10);
    g.drawArc(arc, pi * 1.22, pi * 0.56, false, Paint()..color = _gold.withValues(alpha: .5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    for (var i = -3; i <= 3; i++) {
      final an = i * 0.19;
      g.drawLine(Offset(px + sin(an) * (len + 2), py - cos(an) * (len + 2)), Offset(px + sin(an) * (len + 14), py - cos(an) * (len + 14)),
          Paint()..color = const Color(0x99F5E6C8)..strokeWidth = i == 0 ? 2 : 1);
    }
    g.drawLine(Offset(px, py), bob, Paint()..color = const Color(0xFFB07A3E)..strokeWidth = 4..strokeCap = StrokeCap.round);
    g.drawCircle(bob, 13, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF1C1), _gold, Color(0xFF8A6410)], stops: [0, .5, 1], center: Alignment(-.3, -.3)).createShader(Rect.fromCircle(center: bob, radius: 13)));
    g.drawCircle(Offset(px, py), 7, Paint()..color = const Color(0xFF3B2410));
    g.drawCircle(Offset(px, py), 3, Paint()..color = _gold);
  }

  @override
  bool shouldRepaint(covariant _PendulumPainter old) => old.phase != phase || old.running != running;
}
