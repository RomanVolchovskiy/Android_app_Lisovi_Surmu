import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/screens/education_topic_screen.dart';
import 'package:hunting_signals/screens/flashcard_screen.dart';
import 'package:hunting_signals/screens/test_screen.dart';
import 'package:hunting_signals/screens/theory_practice_test_screen.dart';
import 'package:hunting_signals/screens/exam_taking_screen.dart';
import 'package:hunting_signals/screens/study_plan_screen.dart';
import 'package:hunting_signals/screens/practical_tasks_screen.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<EducationTopic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTopics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final topics = await EducationService.getTopics();
    if (mounted) setState(() { _topics = topics; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Вкладки ────────────────────────────────────────────────────
        Container(
          color: HuntingTheme.primaryColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: HuntingTheme.accentColor,
            indicatorWeight: 3,
            labelColor: HuntingTheme.accentColor,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'Теоретичні матеріали'),
              Tab(icon: Icon(Icons.assignment_rounded, size: 20), text: 'Практичні матеріали'),
              Tab(icon: Icon(Icons.checklist_rounded, size: 20), text: 'План навчання'),
              Tab(icon: Icon(Icons.style_rounded, size: 20), text: 'Флеш-картки'),
              Tab(icon: Icon(Icons.quiz_rounded, size: 20), text: 'Тестування'),
            ],
          ),
        ),
        // ── Вміст вкладок ───────────────────────────────────────────────
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TopicList(
                        topics: _topics,
                        mode: _EducationMode.materials,
                        icon: Icons.menu_book_rounded,
                        emptyHint: 'Адмін ще не додав теми',
                        onRefresh: () { setState(() => _loading = true); _loadTopics(); },
                      ),
                      const PracticalTasksScreen(),
                      const StudyPlanScreen(),
                      _TopicList(
                        topics: _topics,
                        mode: _EducationMode.flashcards,
                        icon: Icons.style_rounded,
                        emptyHint: 'Адмін ще не додав теми',
                        onRefresh: () { setState(() => _loading = true); _loadTopics(); },
                      ),
                      const _TestingHub(),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Режим відображення ────────────────────────────────────────────────────────
enum _EducationMode { materials, flashcards, test }

// ── Список тем ────────────────────────────────────────────────────────────────
class _TopicList extends StatelessWidget {
  final List<EducationTopic> topics;
  final _EducationMode mode;
  final IconData icon;
  final String emptyHint;
  final VoidCallback onRefresh;

  const _TopicList({
    required this.topics,
    required this.mode,
    required this.icon,
    required this.emptyHint,
    required this.onRefresh,
  });

  void _openTopic(BuildContext context, EducationTopic topic) {
    switch (mode) {
      case _EducationMode.materials:
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => EducationTopicScreen(topic: topic),
        ));
      case _EducationMode.flashcards:
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => FlashcardScreen(topic: topic),
        ));
      case _EducationMode.test:
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const TestScreen(),
        ));
    }
  }

  String get _actionLabel {
    switch (mode) {
      case _EducationMode.materials:  return 'Переглянути';
      case _EducationMode.flashcards: return 'Флеш-картки';
      case _EducationMode.test:       return 'Пройти тест';
    }
  }

  IconData get _actionIcon {
    switch (mode) {
      case _EducationMode.materials:  return Icons.menu_book_rounded;
      case _EducationMode.flashcards: return Icons.style_rounded;
      case _EducationMode.test:       return Icons.quiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(emptyHint, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Оновити'),
              style: TextButton.styleFrom(foregroundColor: HuntingTheme.primaryColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: topics.length,
      itemBuilder: (context, i) {
        final topic = topics[i];
        return GestureDetector(
          onTap: () => _openTopic(context, topic),
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
                        decoration: BoxDecoration(
                          color: HuntingTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(icon, color: HuntingTheme.primaryDark, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (topic.description.isNotEmpty)
                              Text(
                                topic.description,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _CardBtn(
                      label: _actionLabel,
                      icon: _actionIcon,
                      onTap: () => _openTopic(context, topic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

// ── Хаб тестування ────────────────────────────────────────────────────────────
class _TestingHub extends StatelessWidget {
  const _TestingHub();

  static const _levels = [
    (difficulty: 'easy',   label: 'Легкий',   emoji: '🟢', color: Color(0xFF2E7D32)),
    (difficulty: 'medium', label: 'Середній', emoji: '🟡', color: Color(0xFFF57F17)),
    (difficulty: 'hard',   label: 'Важкий',   emoji: '🔴', color: Color(0xFFC62828)),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Пробне тестування ──────────────────────────────────────────
          _HubSection(
            icon: Icons.science_rounded,
            title: 'Пробне тестування',
            subtitle: 'Перевір знання без збереження результатів',
            color: HuntingTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _BigCard(
                icon: Icons.menu_book_rounded,
                emoji: '📝',
                title: 'Теоретичний тест',
                desc: 'Питання по темах навчання',
                color: Colors.blue[700]!,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const TheoryPracticeTestScreen(),
                )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigCard(
                icon: Icons.headphones_rounded,
                emoji: '🎺',
                title: 'Аудіо тест',
                desc: 'Розпізнавання мисливських сигналів',
                color: Colors.purple[700]!,
                onTap: () => _showAudioDifficultySheet(context),
              ),
            ),
          ]),

          const SizedBox(height: 28),

          // ── Іспит ─────────────────────────────────────────────────────
          _HubSection(
            icon: Icons.school_rounded,
            title: 'Іспит',
            subtitle: 'Введіть код сесії, наданий адміністратором',
            color: const Color(0xFF1C3A1C),
          ),
          const SizedBox(height: 12),
          _ExamCodeCard(),
        ],
      ),
    );
  }

  void _showAudioDifficultySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Рівень складності',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._levels.map((lvl) => ListTile(
            leading: Text(lvl.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(lvl.label,
                style: TextStyle(fontWeight: FontWeight.w600, color: lvl.color)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TestScreen(difficulty: lvl.difficulty),
              ));
            },
          )),
          ListTile(
            leading: const Text('🎯', style: TextStyle(fontSize: 24)),
            title: const Text('Усі сигнали',
                style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const TestScreen(),
              ));
            },
          ),
        ]),
      ),
    );
  }
}

class _HubSection extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _HubSection({required this.icon, required this.title,
      required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ])),
  ]);
}

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String emoji, title, desc;
  final Color color;
  final VoidCallback onTap;
  const _BigCard({required this.icon, required this.emoji, required this.title,
      required this.desc, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const Color(0xFFFFF8E7), const Color(0xFFE8C87A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6,
            offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 3),
        Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Почати',
                style: TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ),
  );
}

class _ExamCodeCard extends StatefulWidget {
  @override
  State<_ExamCodeCard> createState() => _ExamCodeCardState();
}

class _ExamCodeCardState extends State<_ExamCodeCard> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3A1C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8,
            offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        const Text('Введіть код сесії',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  letterSpacing: 6, color: Color(0xFFD4A017)),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '______',
                hintStyle: TextStyle(letterSpacing: 6, color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD4A017))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFD4A017), width: 2)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              if (_ctrl.text.trim().length == 6) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ExamEntryScreen(),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A017),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 24),
          ),
        ]),
      ]),
    );
  }
}

// ── Кнопка на картці ─────────────────────────────────────────────────────────
class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CardBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HuntingTheme.primaryColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
