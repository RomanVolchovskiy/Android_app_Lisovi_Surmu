import 'dart:io' if (dart.library.html) 'package:hunting_signals/stubs/dart_io_stub.dart';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Синтез звуку сурми для тренажера «Чарівна сурма».
///
/// П'ять нот натурального звукоряду рога (C4, G4, C5, E5, G5) генеруються
/// один раз як короткі WAV-файли (пила + трикутник, м'який фільтр, огинаюча,
/// легке вібрато — той самий тембр, що й у веб-версії) і програються через
/// SoundPool (PlayerMode.lowLatency): затримка від дотику до звуку мінімальна.
class HornSynth {
  static const List<double> frequencies = [261.63, 392.00, 523.25, 659.25, 783.99];
  static const List<String> labels = ['ДО', 'СОЛЬ', 'ДО2', 'МІ2', 'СОЛЬ2'];

  static const int _sampleRate = 22050;
  static const double _seconds = 0.7;

  final List<AudioPlayer> _players = [];
  bool _ready = false;
  Future<void>? _init;

  Future<void> ensureReady() => _init ??= _prepare();

  Future<void> _prepare() async {
    for (var i = 0; i < frequencies.length; i++) {
      final wav = _renderWav(frequencies[i]);
      final player = AudioPlayer(playerId: 'horn_$i');
      await player.setReleaseMode(ReleaseMode.stop);
      if (kIsWeb) {
        await player.setSource(BytesSource(wav));
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/horn_$i.wav');
        if (!await file.exists() || await file.length() != wav.length) {
          await file.writeAsBytes(wav, flush: true);
        }
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(DeviceFileSource(file.path));
      }
      _players.add(player);
    }
    _ready = true;
  }

  /// Грає ноту доріжки [lane] (0 = ДО … 4 = СОЛЬ2).
  Future<void> play(int lane) async {
    if (!_ready || lane < 0 || lane >= _players.length) return;
    final p = _players[lane];
    try {
      await p.stop();
      await p.resume();
    } catch (e) {
      debugPrint('HornSynth: $e');
    }
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
    _players.clear();
    _ready = false;
  }

  /// Рендерить ноту в 16-бітний mono WAV.
  static Uint8List _renderWav(double freq) {
    final n = (_sampleRate * _seconds).round();
    final samples = Float64List(n);
    double lp = 0; // одно-полюсний фільтр низьких частот
    final alpha = 1 - exp(-2 * pi * 1400 / _sampleRate);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final vib = 1 + 0.004 * sin(2 * pi * 5.5 * t);
      final ph = (freq * vib * t) % 1.0;
      final saw = 2 * ph - 1;
      final tri = ph < 0.5 ? 4 * ph - 1 : 3 - 4 * ph;
      final raw = 0.35 * saw + 0.65 * tri;
      lp += alpha * (raw - lp);
      // огинаюча: атака 30 мс, утримання, спад в останні 150 мс
      double env;
      if (t < 0.03) {
        env = t / 0.03;
      } else if (t > _seconds - 0.15) {
        env = (_seconds - t) / 0.15;
      } else {
        env = 1;
      }
      samples[i] = lp * env * 0.6;
    }
    final data = ByteData(44 + n * 2);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(off + i, s.codeUnitAt(i));
      }
    }
    str(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _sampleRate, Endian.little);
    data.setUint32(28, _sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
