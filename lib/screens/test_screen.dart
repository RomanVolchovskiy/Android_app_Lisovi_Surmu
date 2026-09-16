import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';

// Скільки питань в одному тесті (або менше, якщо сигналів з аудіо замало)
const _kTestCount = 10;

class _AudioQuestion {
  final String audioUrl;
  final String signalName;
  final List<String> options; // 4 варіанти назв
  final int correctIndex;

  const _AudioQuestion({
    required this.audioUrl,
    required this.signalName,
    required this.options,
    required this.correctIndex,
  });
}

class TestScreen extends StatefulWidget {
  final String? difficulty;

  const TestScreen({super.key, this.difficulty});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<_AudioQuestion> _questions = [];
  bool _loading = true;
  int _currentIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _score = 0;
  bool _finished = false;
  final List<int?> _userAnswers = [];

  // Аудіо — ValueNotifier щоб не перебудовувати весь екран
  final AudioPlayer _audio = AudioPlayer();
  final ValueNotifier<({bool loading, bool playing, bool played})> _audioState =
      ValueNotifier((loading: false, playing: false, played: false));

  // Таймер — ValueNotifier щоб не перебудовувати весь екран
  final ValueNotifier<int> _timeNotifier = ValueNotifier(30);
  Timer? _timer;

  static const _bgColor   = Color(0xFF1A0F00);
  static const _woodColor = Color(0xFF2C1A0A);
  static const _goldColor = Color(0xFFD4A017);
  static const _goldLight = Color(0xFFFFD966);

  @override
  void initState() {
    super.initState();
    _audio.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      final cur = _audioState.value;
      _audioState.value = (
        loading: cur.loading,
        playing: state == PlayerState.playing,
        played: cur.played,
      );
    });
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.dispose();
    _audioState.dispose();
    _timeNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final allSignals = await HuntingDataService.getAllSignals();

    // Дедуплікація по audioUrl: кожне унікальне аудіо лише раз
    final seen = <String>{};
    final withAudio = <HuntingSignal>[];
    for (final s in allSignals) {
      final url = s.audioUrl;
      if (url != null && url.isNotEmpty && seen.add(url)) {
        withAudio.add(s);
      }
    }

    if (withAudio.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final filtered = widget.difficulty == null
        ? withAudio
        : withAudio.where((s) => s.difficulty == widget.difficulty).toList();

    if (filtered.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final rng = Random();
    final testSignals = List<HuntingSignal>.from(filtered)..shuffle(rng);
    final picked = testSignals.take(_kTestCount).toList();

    // Use all signals with audio for wrong-answer pool so there are always enough options
    final allNames = withAudio.map((s) => s.name).toList();

    final questions = picked.map((signal) {
      // 3 неправильні назви (відмінні від правильної)
      final wrongs = (List<String>.from(allNames)..remove(signal.name))
          ..shuffle(rng);
      final opts = [signal.name, ...wrongs.take(3)]..shuffle(rng);
      final correctIdx = opts.indexOf(signal.name);
      return _AudioQuestion(
        audioUrl: signal.audioUrl!,
        signalName: signal.name,
        options: List<String>.unmodifiable(opts),
        correctIndex: correctIdx,
      );
    }).toList();

    if (mounted) {
      setState(() { _questions = questions; _loading = false; });
      if (questions.isNotEmpty) _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeNotifier.value = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      _timeNotifier.value--;
      if (_timeNotifier.value <= 0) {
        t.cancel();
        if (!_answered) unawaited(_autoSkip());
      }
    });
  }

  Future<void> _autoSkip() async {
    _userAnswers.add(null);
    await _stopAudio();
    _nextOrFinish();
  }

  Future<void> _playAudio() async {
    final url = _questions[_currentIndex].audioUrl;
    _audioState.value = (loading: true, playing: false, played: _audioState.value.played);
    try {
      await _audio.stop();
      await _audio.play(UrlSource(url));
      if (mounted) _audioState.value = (loading: false, playing: true, played: true);
    } catch (_) {
      if (mounted) _audioState.value = (loading: false, playing: false, played: _audioState.value.played);
    }
  }

  Future<void> _stopAudio() async {
    await _audio.stop();
    if (mounted) {
      final cur = _audioState.value;
      _audioState.value = (loading: cur.loading, playing: false, played: cur.played);
    }
  }

  Future<void> _selectOption(int index) async {
    if (_answered) return;
    _timer?.cancel();
    await _stopAudio();
    if (_questions[_currentIndex].correctIndex == index) _score++;
    _userAnswers.add(index);
    setState(() { _selectedOption = index; _answered = true; });
  }

  Future<void> _nextOrFinish() async {
    await _stopAudio();
    if (_currentIndex < _questions.length - 1) {
      _audioState.value = (loading: false, playing: false, played: false);
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
      _startTimer();
    } else {
      _timer?.cancel();
      setState(() => _finished = true);
    }
  }

  Future<void> _restart() async {
    _timer?.cancel();
    await _stopAudio();
    _audioState.value = (loading: false, playing: false, played: false);
    setState(() {
      _currentIndex = 0;
      _selectedOption = null;
      _answered = false;
      _score = 0;
      _finished = false;
      _userAnswers.clear();
      _loading = true;
    });
    _load();
  }

  String _difficultyLabel() {
    switch (widget.difficulty) {
      case 'easy':   return '🟢 Легкий рівень';
      case 'medium': return '🟡 Середній рівень';
      case 'hard':   return '🔴 Важкий рівень';
      default:       return 'Аудіо тест';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6),
      appBar: AppBar(
        title: Text(_difficultyLabel()),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? _buildEmpty()
              : _finished
                  ? _buildResults()
                  : _buildQuestion(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hearing_rounded, size: 64, color: Colors.brown[200]),
          const SizedBox(height: 16),
          Text(
            widget.difficulty != null
                ? 'Немає сигналів з аудіо для цього рівня'
                : 'Немає сигналів з аудіо для тесту',
            style: TextStyle(color: Colors.brown[400], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIndex];
    final total = _questions.length;
    final progress = (_currentIndex + 1) / total;

    return Column(
      children: [
        // ── Шапка з прогресом і таймером ─────────────────────────────
        Container(
          color: _bgColor,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сигнал ${_currentIndex + 1} з $total',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(_goldColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ValueListenableBuilder<int>(
                valueListenable: _timeNotifier,
                builder: (_, t, __) => Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: t <= 10
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.white12,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t <= 10 ? Colors.red : _goldColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$t',
                      style: TextStyle(
                        color: t <= 10 ? Colors.red : _goldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Аудіо плеєр ──────────────────────────────────────────────
        ValueListenableBuilder<({bool loading, bool playing, bool played})>(
          valueListenable: _audioState,
          builder: (_, audio, __) => Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_woodColor, Color(0xFF3E2008)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _goldColor.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  '🎺  Прослухайте сигнал',
                  style: TextStyle(
                    color: _goldLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: audio.loading ? null : (audio.playing ? _stopAudio : _playAudio),
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2D5A1B),
                      border: Border.all(color: _goldColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _goldColor.withValues(alpha: 0.4),
                          blurRadius: 16, spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: audio.loading
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: _goldColor, strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            audio.playing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            color: _goldLight,
                            size: 44,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  audio.playing
                      ? 'Грає...'
                      : audio.played
                          ? 'Прослухати ще раз'
                          : 'Натисніть для прослуховування',
                  style: TextStyle(
                    color: audio.playing ? _goldColor : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 22,
                  child: AnimatedOpacity(
                    opacity: audio.playing ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _WaveIndicator(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Оберіть назву сигналу який ви прослухали:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.brown[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20, 0, 20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              children: [
                ...q.options.asMap().entries.map((entry) {
                  final idx = entry.key;
                  return _OptionCard(
                    index: idx,
                    text: entry.value,
                    answered: _answered,
                    selected: _selectedOption == idx,
                    correct: q.correctIndex == idx,
                    onTap: () => _selectOption(idx),
                  );
                }),
                if (_answered) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextOrFinish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bgColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentIndex < _questions.length - 1
                            ? 'Наступний сигнал →'
                            : 'Завершити тест',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final total = _questions.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    final Color resultColor;
    final String resultText;
    final IconData resultIcon;

    if (pct >= 80) {
      resultColor = Colors.green[700]!;
      resultText  = 'Відмінно!';
      resultIcon  = Icons.emoji_events_rounded;
    } else if (pct >= 60) {
      resultColor = Colors.orange[700]!;
      resultText  = 'Добре!';
      resultIcon  = Icons.thumb_up_rounded;
    } else {
      resultColor = Colors.red[700]!;
      resultText  = 'Потрібно більше практики';
      resultIcon  = Icons.replay_rounded;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(resultIcon, size: 52, color: resultColor),
          ),
          const SizedBox(height: 16),
          Text(resultText,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: resultColor)),
          const SizedBox(height: 8),
          Text('$_score з $total правильних ($pct%)',
              style: const TextStyle(fontSize: 18, color: Colors.black54)),
          const SizedBox(height: 32),
          const Text('Детальні результати',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ..._questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            final userAnswer = i < _userAnswers.length ? _userAnswers[i] : null;
            final isCorrect = userAnswer == q.correctIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isCorrect ? Colors.green[200]! : Colors.red[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isCorrect ? Colors.green[600] : Colors.red[600],
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.music_note_rounded, size: 14, color: Colors.black45),
                            const SizedBox(width: 4),
                            Text('Сигнал ${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (!isCorrect)
                          Text(
                            'Ваша відповідь: ${userAnswer != null ? q.options[userAnswer] : "Не відповіли"}',
                            style: TextStyle(fontSize: 12, color: Colors.red[700]),
                          ),
                        Text(
                          'Правильно: ${q.signalName}',
                          style: TextStyle(fontSize: 12, color: Colors.green[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Назад'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.brown[700],
                    side: BorderSide(color: Colors.brown[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Новий тест'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bgColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Анімована хвиля ────────────────────────────────────────────────────────────
class _WaveIndicator extends StatefulWidget {
  @override
  State<_WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends State<_WaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final phase = (i / 6 + _ctrl.value) % 1.0;
            final height = 6 + 16 * (0.5 - (phase - 0.5).abs()) * 2;
            return Container(
              width: 4,
              height: height.clamp(4, 22),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4A017),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Картка варіанту відповіді ──────────────────────────────────────────────────
class _OptionCard extends StatelessWidget {
  final int index;
  final String text;
  final bool answered;
  final bool selected;
  final bool correct;
  final VoidCallback onTap;

  const _OptionCard({
    required this.index,
    required this.text,
    required this.answered,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    Color bg      = Colors.white;
    Color border  = Colors.grey[300]!;
    Color labelBg = Colors.grey[200]!;
    Color labelFg = Colors.grey[700]!;

    if (answered) {
      if (correct) {
        bg = Colors.green[50]!; border = Colors.green[400]!;
        labelBg = Colors.green[400]!; labelFg = Colors.white;
      } else if (selected) {
        bg = Colors.red[50]!; border = Colors.red[400]!;
        labelBg = Colors.red[400]!; labelFg = Colors.white;
      }
    } else if (selected) {
      bg = Colors.brown[50]!; border = Colors.brown[400]!;
    }

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: labelBg, shape: BoxShape.circle),
              child: Center(
                child: Text(_labels[index],
                    style: TextStyle(
                        color: labelFg, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 15, color: Colors.black87)),
            ),
            if (answered && correct)
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
            if (answered && selected && !correct)
              const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }
}
