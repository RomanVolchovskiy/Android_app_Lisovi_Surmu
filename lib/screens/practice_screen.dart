import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/exam_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/practical_service.dart';
import 'package:hunting_signals/screens/education_topic_screen.dart';
import 'package:hunting_signals/screens/my_quiz_results_screen.dart';
import 'package:hunting_signals/screens/study_plan_screen.dart';
import 'package:hunting_signals/screens/test_screen.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Тег сигналів, які студенти вивчають на навчальній практиці (ТЗ 3.6).
const kPracticeTag = 'практика';

/// Окремий розділ «Практика» (нижня навігація), як на сайті (#/practice):
/// дні практики з тестом дня, «Сигнали практики», мої результати, план і залік.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<EducationTopic> _days = [];
  bool _hasPracticeSignals = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      PracticalService.getTopics(),
      HuntingDataService.getAllSignals(),
    ]);
    final days = results[0] as List<EducationTopic>;
    final signals = results[1] as List<HuntingSignal>;
    // «Сигнали практики» — лише коли з тегом і аудіо є щонайменше 4 сигнали
    final tagged = signals.where((s) =>
        (s.tags?.contains(kPracticeTag) ?? false) && (s.audioUrl?.isNotEmpty ?? false)).length;
    if (mounted) {
      setState(() {
        _days = days;
        _hasPracticeSignals = tagged >= 4;
        _loading = false;
      });
    }
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionTitle(icon: Icons.assignment_rounded, title: 'Дні практики'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Відкрийте день — там матеріали і «Пробний тест дня».',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          if (_days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Дні практики ще не додані', style: TextStyle(color: Colors.grey[600])),
            ),
          for (var i = 0; i < _days.length; i++)
            _Tile(
              leading: _NumberBadge(i + 1),
              title: _days[i].name,
              subtitle: _days[i].description,
              onTap: () => _push(EducationTopicScreen(
                topic: _days[i],
                materialLoader: PracticalService.getMaterialsByTopic,
              )),
            ),
          const SizedBox(height: 12),
          const _SectionTitle(icon: Icons.quiz_rounded, title: 'Тренування'),
          if (_hasPracticeSignals)
            _Tile(
              leading: const _IconBadge(Icons.campaign_rounded, Color(0xFF5D4037)),
              title: 'Сигнали практики',
              subtitle: 'Аудіотест: впізнайте сигнал на слух',
              onTap: () => _push(const TestScreen(tag: kPracticeTag)),
            ),
          _Tile(
            leading: const _IconBadge(Icons.history_rounded, Color(0xFF5D4037)),
            title: 'Мої результати',
            subtitle: 'Останні 50 пробних тестів — для щоденника практики',
            onTap: () => _push(const MyQuizResultsScreen()),
          ),
          _Tile(
            leading: const _IconBadge(Icons.checklist_rounded, Color(0xFF2E7D32)),
            title: 'План навчання',
            subtitle: 'Тематичний план і години',
            onTap: () => _push(Scaffold(
              backgroundColor: HuntingTheme.backgroundColor,
              appBar: AppBar(title: const Text('План навчання')),
              body: const StudyPlanScreen(),
            )),
          ),
          const SizedBox(height: 12),
          const _SectionTitle(icon: Icons.school_rounded, title: 'Залік'),
          const ExamOnSiteCard(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 22, color: const Color(0xFF4E342E)),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF4E342E))),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _Tile({required this.leading, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: leading,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: (subtitle?.isNotEmpty ?? false) ? Text(subtitle!) : null,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

class _NumberBadge extends StatelessWidget {
  final int n;
  const _NumberBadge(this.n);

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HuntingTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$n', style: TextStyle(fontWeight: FontWeight.bold, color: HuntingTheme.primaryColor)),
      );
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge(this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color),
      );
}

/// Іспит у додатку не проводиться (ТЗ практики, розділ 7): спроби, таймер і
/// автозбереження реалізовані лише на сайті, тож тут — повідомлення й посилання.
class ExamOnSiteCard extends StatelessWidget {
  const ExamOnSiteCard({super.key});

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(ExamService.siteExamUrl), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося відкрити браузер. Відкрийте ${ExamService.siteUrl} вручну')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3A1C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8,
            offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Іспит проходьте на сайті',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SelectableText(ExamService.siteUrl.replaceFirst('https://', ''),
            style: const TextStyle(color: Color(0xFFD4A017), fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Увійдіть тим самим акаунтом, відкрийте «Практика» → «Ввести код сесії» і введіть код від викладача.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('Відкрити сайт'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4A017),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Скопіювати посилання',
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: ExamService.siteExamUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Посилання скопійовано')),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
          ),
        ]),
      ]),
    );
  }
}
