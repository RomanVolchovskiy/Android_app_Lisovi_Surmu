import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';

const _darkGreen  = Color(0xFF1C3A1C);
const _gold       = Color(0xFFD4A017);

// ── Вибір теми ───────────────────────────────────────────────────────────────
class TheoryPracticeTestScreen extends StatefulWidget {
  const TheoryPracticeTestScreen({super.key});

  @override
  State<TheoryPracticeTestScreen> createState() => _TheoryPracticeTestScreenState();
}

class _TheoryPracticeTestScreenState extends State<TheoryPracticeTestScreen> {
  List<EducationTopic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final topics = await EducationService.getTopics();
    if (mounted) setState(() { _topics = topics; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: const Text('Пробний теоретичний тест'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _topics.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.quiz_rounded, size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Теми ще не додані',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  ]),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      color: _darkGreen.withValues(alpha: 0.07),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'Оберіть тему для тестування',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _topics.length,
                        itemBuilder: (context, i) {
                          final topic = _topics[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: _darkGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.quiz_rounded,
                                    color: _darkGreen, size: 22),
                              ),
                              title: Text(topic.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: topic.description.isNotEmpty
                                  ? Text(topic.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey[600]))
                                  : null,
                              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 16, color: _darkGreen),
                              onTap: () => _startTest(context, topic),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _startTest(BuildContext context, EducationTopic topic) async {
    final questions = await EducationService.getTestQuestionsByTopic(topic.id);
    if (!context.mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('До цієї теми ще не додані питання')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _TheoryTestQuizScreen(topic: topic, questions: questions),
    ));
  }
}

// ── Тест ─────────────────────────────────────────────────────────────────────
class _TheoryTestQuizScreen extends StatefulWidget {
  final EducationTopic topic;
  final List<TestQuestion> questions;
  const _TheoryTestQuizScreen({required this.topic, required this.questions});

  @override
  State<_TheoryTestQuizScreen> createState() => _TheoryTestQuizScreenState();
}

class _TheoryTestQuizScreenState extends State<_TheoryTestQuizScreen> {
  int _currentIndex = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  bool _finished = false;
  final List<int?> _userAnswers = [];

  TestQuestion get _q => widget.questions[_currentIndex];

  void _select(int idx) {
    if (_answered) return;
    if (_q.correctIndex == idx) _correct++;
    _userAnswers.add(idx);
    setState(() { _selected = idx; _answered = true; });
  }

  void _next() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selected = null;
        _answered = false;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: Text(widget.topic.name,
            style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
      ),
      body: _finished ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final total = widget.questions.length;
    return Column(
      children: [
        // Прогрес
        Container(
          color: _darkGreen,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Питання ${_currentIndex + 1} з $total',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / total,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Питання
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _gold.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 6,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    _q.question,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: Colors.black87, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                // Варіанти
                ..._q.options.asMap().entries.map((e) {
                  final idx = e.key;
                  final text = e.value;
                  return _AnswerCard(
                    label: String.fromCharCode(65 + idx), // A, B, C, D
                    text: text,
                    answered: _answered,
                    selected: _selected == idx,
                    correct: _q.correctIndex == idx,
                    onTap: () => _select(idx),
                  );
                }),
                if (_answered) ...[
                  if (_q.explanation != null && _q.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_q.explanation!,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.blue[800])),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _darkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _currentIndex < widget.questions.length - 1
                            ? 'Наступне питання →'
                            : 'Завершити тест',
                        style: const TextStyle(fontSize: 15),
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

  Widget _buildResult() {
    final total  = widget.questions.length;
    final score  = ((_correct / total) * 100).round();

    String grade;
    Color gradeColor;
    if (score >= 90)      { grade = 'Відмінно!';  gradeColor = Colors.green[700]!; }
    else if (score >= 75) { grade = 'Добре!';      gradeColor = Colors.blue[700]!; }
    else if (score >= 60) { grade = 'Задовільно';  gradeColor = Colors.orange[700]!; }
    else                  { grade = 'Незадовільно'; gradeColor = Colors.red[700]!; }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          // Оцінка
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10,
                  offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              Text('$score', style: TextStyle(
                  fontSize: 72, fontWeight: FontWeight.bold, color: gradeColor)),
              Text('балів зі 100', style: TextStyle(
                  fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                ),
                child: Text(grade, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: gradeColor)),
              ),
              const SizedBox(height: 12),
              Text('$_correct правильних з $total питань',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ]),
          ),
          const SizedBox(height: 20),
          // Детальні результати
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Детальні результати',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          ..._userAnswers.asMap().entries.map((e) {
            final i = e.key;
            final q = widget.questions[i];
            final userIdx = e.value;
            final isCorrect = userIdx == q.correctIndex;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isCorrect ? Colors.green[200]! : Colors.red[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isCorrect ? Colors.green[600] : Colors.red[600],
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${q.question}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        if (!isCorrect && userIdx != null)
                          Text('Ваша відповідь: ${q.options[userIdx]}',
                              style: TextStyle(fontSize: 11, color: Colors.red[700])),
                        Text('Правильно: ${q.options[q.correctIndex]}',
                            style: TextStyle(fontSize: 11, color: Colors.green[700])),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('До тем'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _darkGreen,
                  side: const BorderSide(color: _darkGreen),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => setState(() {
                  _currentIndex = 0; _selected = null;
                  _answered = false; _correct = 0;
                  _finished = false; _userAnswers.clear();
                }),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Пройти знову'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Картка відповіді ──────────────────────────────────────────────────────────
class _AnswerCard extends StatelessWidget {
  final String label;
  final String text;
  final bool answered, selected, correct;
  final VoidCallback onTap;

  const _AnswerCard({
    required this.label, required this.text,
    required this.answered, required this.selected,
    required this.correct, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white, border = Colors.grey[300]!;
    Color lblBg = Colors.grey[200]!, lblFg = Colors.grey[700]!;

    if (answered) {
      if (correct) {
        bg = Colors.green[50]!; border = Colors.green[400]!;
        lblBg = Colors.green[400]!; lblFg = Colors.white;
      } else if (selected) {
        bg = Colors.red[50]!; border = Colors.red[400]!;
        lblBg = Colors.red[400]!; lblFg = Colors.white;
      }
    } else if (selected) {
      bg = const Color(0xFFFFF8E7); border = _gold;
    }

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: lblBg, shape: BoxShape.circle),
              child: Center(child: Text(label,
                  style: TextStyle(color: lblFg,
                      fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text,
                style: const TextStyle(fontSize: 15, color: Colors.black87))),
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
