import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';

class FlashcardScreen extends StatefulWidget {
  final EducationTopic topic;

  const FlashcardScreen({super.key, required this.topic});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  List<Flashcard> _cards = [];
  bool _loading = true;
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _correct = 0;
  int _incorrect = 0;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  static const _bgColor   = Color(0xFF1A0F00);
  static const _goldColor = Color(0xFFD4A017);
  static const _woodColor = Color(0xFF2C1A0A);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cards = await EducationService.getFlashcardsByTopic(widget.topic.id);
    if (mounted) setState(() { _cards = cards; _loading = false; });
  }

  void _shuffle() {
    setState(() {
      _cards.shuffle(Random());
      _currentIndex = 0;
      _showAnswer = false;
      _correct = 0;
      _incorrect = 0;
      _flipController.reset();
    });
  }

  void _flip() {
    if (_showAnswer) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showAnswer = !_showAnswer);
  }

  void _next() {
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
        _flipController.reset();
      });
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showAnswer = false;
        _flipController.reset();
      });
    }
  }

  void _markCorrect() {
    setState(() => _correct++);
    _next();
  }

  void _markIncorrect() {
    setState(() => _incorrect++);
    _next();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6),
      appBar: AppBar(
        title: Text('Флеш-картки: ${widget.topic.name}'),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _cards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.shuffle_rounded),
              tooltip: 'Перемішати',
              onPressed: _shuffle,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_rounded, size: 64, color: Colors.brown[200]),
          const SizedBox(height: 16),
          Text(
            'Для цієї теми ще немає флеш-карток',
            style: TextStyle(color: Colors.brown[400], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final total = _cards.length;
    final card  = _cards[_currentIndex];
    final answered = _correct + _incorrect;

    return Column(
      children: [
        // ── Лічильник ─────────────────────────────────────────────────
        Container(
          color: _bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _ScoreBadge(label: 'Правильно', count: _correct, color: Colors.green[400]!),
              const SizedBox(width: 10),
              _ScoreBadge(label: 'Неправильно', count: _incorrect, color: Colors.red[400]!),
              const Spacer(),
              Text(
                '${_currentIndex + 1} / $total',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        // ── Прогрес-бар ───────────────────────────────────────────────
        LinearProgressIndicator(
          value: total > 0 ? answered / total : 0,
          backgroundColor: Colors.brown[100],
          valueColor: AlwaysStoppedAnimation<Color>(_goldColor),
          minHeight: 4,
        ),
        // ── Картка ────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _flip,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * pi;
                        final isBack = angle > pi / 2;

                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          alignment: Alignment.center,
                          child: isBack
                              ? Transform(
                                  transform: Matrix4.identity()..rotateY(pi),
                                  alignment: Alignment.center,
                                  child: _buildCardFace(
                                    card.answer,
                                    isAnswer: true,
                                  ),
                                )
                              : _buildCardFace(card.question, isAnswer: false),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Натисніть на картку щоб побачити відповідь',
                  style: TextStyle(fontSize: 12, color: Colors.brown[400]),
                ),
                const SizedBox(height: 16),
                // ── Кнопки відповіді або "Показати відповідь" ──────────
                if (_showAnswer)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AnswerBtn(
                        label: 'Неправильно',
                        icon: Icons.close_rounded,
                        color: Colors.red[600]!,
                        onTap: _currentIndex < _cards.length - 1 ? _markIncorrect : null,
                      ),
                      const SizedBox(width: 12),
                      _AnswerBtn(
                        label: 'Правильно',
                        icon: Icons.check_rounded,
                        color: Colors.green[600]!,
                        onTap: _currentIndex < _cards.length - 1 ? _markCorrect : null,
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: 200,
                    child: OutlinedButton.icon(
                      onPressed: _flip,
                      icon: const Icon(Icons.flip_rounded, size: 18),
                      label: const Text('Показати відповідь'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _woodColor,
                        side: BorderSide(color: Colors.brown[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // ── Навігація ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _NavBtn(
                      icon: Icons.arrow_back_ios_rounded,
                      onTap: _currentIndex > 0 ? _prev : null,
                    ),
                    const SizedBox(width: 32),
                    _NavBtn(
                      icon: Icons.arrow_forward_ios_rounded,
                      onTap: _currentIndex < _cards.length - 1 ? _next : null,
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                // ── Кінець сесії ────────────────────────────────────────
                if (_currentIndex == _cards.length - 1 && answered == total)
                  _buildResultBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFace(String text, {required bool isAnswer}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isAnswer
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [_woodColor, const Color(0xFF3E2008)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isAnswer ? 'ВІДПОВІДЬ' : 'ПИТАННЯ',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final total = _correct + _incorrect;
    final pct = total > 0 ? (_correct / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.brown[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFD4A017), size: 28),
          const SizedBox(width: 10),
          Text(
            'Результат: $_correct/$total ($pct%)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _shuffle,
            child: const Text('Повторити'),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ScoreBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap != null ? Colors.brown[700] : Colors.brown[200],
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _AnswerBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AnswerBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
