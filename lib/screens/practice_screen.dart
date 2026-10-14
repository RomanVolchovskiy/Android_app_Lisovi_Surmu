import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/exam_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/practical_service.dart';
import 'package:hunting_signals/services/practice_core.dart';
import 'package:hunting_signals/services/practice_service.dart';
import 'package:hunting_signals/screens/education_topic_screen.dart';
import 'package:hunting_signals/screens/my_quiz_results_screen.dart';
import 'package:hunting_signals/screens/practice_step_screen.dart';
import 'package:hunting_signals/screens/study_plan_screen.dart';
import 'package:hunting_signals/screens/test_screen.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/practice_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Тег сигналів, які студенти вивчають на навчальній практиці (ТЗ 3.6).
const kPracticeTag = 'практика';

/// Окремий розділ «Практика» (нижня навігація), як на сайті (#/practice):
/// послідовність робіт практики за «Покроковою інструкцією студента» —
/// відмітки, файли, щоденник, самоконтроль, автоматичні результати тестів і
/// іспиту; угорі — бали, допуск до заліку й підсумкова оцінка.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<EducationTopic> _days = [];
  bool _hasPracticeSignals = false;
  PracticeData? _data;
  String? _error;
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
    PracticeData? data;
    String? error;
    try {
      data = await PracticeService.loadMine();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) {
      setState(() {
        _days = days;
        _hasPracticeSignals = tagged >= 4;
        _data = data;
        _error = error;
        _loading = false;
      });
    }
  }

  /// Після тесту, «Мій акаунт», кроку тощо — оновити автоматичні статуси.
  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  void _openStep(PracticeStep step) => _push(PracticeStepScreen(step: step, data: _data!, days: _days));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final data = _data;
    final children = <Widget>[];
    if (data == null) {
      children.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('Не вдалося завантажити практику. Перевірте інтернет і спробуйте ще раз.',
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Спробувати ще')),
          ]),
        ),
      ));
    } else {
      final t = practiceTotals(data.work, data.grades, data.ctx);
      final next = nextPracticeStep(data.work, data.grades, data.ctx);
      children.add(PracticeSummaryCard(t));
      if (next != null) {
        children.add(Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD4A017), width: 1.5),
          ),
          child: ListTile(
            leading: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFB8860B)),
            title: Text('Далі', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            subtitle: Text(next.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openStep(next),
          ),
        ));
      }
    }
    children.add(Wrap(spacing: 8, runSpacing: 4, children: [
      ActionChip(
        avatar: const Icon(Icons.history_rounded, size: 18),
        label: const Text('Мої результати'),
        onPressed: () => _push(const MyQuizResultsScreen()),
      ),
      ActionChip(
        avatar: const Icon(Icons.checklist_rounded, size: 18),
        label: const Text('План навчання'),
        onPressed: () => _push(Scaffold(
          backgroundColor: HuntingTheme.backgroundColor,
          appBar: AppBar(title: const Text('План навчання')),
          body: const StudyPlanScreen(),
        )),
      ),
      if (_hasPracticeSignals)
        ActionChip(
          avatar: const Icon(Icons.campaign_rounded, size: 18),
          label: const Text('Сигнали практики'),
          onPressed: () => _push(const TestScreen(tag: kPracticeTag)),
        ),
    ]));

    if (data != null) {
      var n = 0;
      for (final stage in practiceStages) {
        final sts = [for (final s in stage.steps) stepStatus(s, data.work, data.grades, data.ctx)];
        final ok = sts.where((s) => const [PracticeState.done, PracticeState.graded, PracticeState.review].contains(s.state)).length;
        final topic = stage.day == null ? null : practiceDayTopic(_days, stage.day!);
        children.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stage.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4E342E))),
            Text('${stage.date} · $ok/${stage.steps.length}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ));
        if (topic != null) {
          children.add(Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _push(EducationTopicScreen(topic: topic, materialLoader: PracticalService.getMaterialsByTopic)),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Матеріали дня і «Пробний тест дня»'),
            ),
          ));
        }
        for (var i = 0; i < stage.steps.length; i++) {
          n++;
          final step = stage.steps[i];
          final st = sts[i];
          children.add(Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openStep(step),
              child: Container(
                decoration: BoxDecoration(border: Border(left: BorderSide(color: practiceStateStyle(st.state).color, width: 4))),
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PracticeNumberBadge(n, st.state),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(step.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      PracticeStatusChip(st),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ]),
              ),
            ),
          ));
        }
      }
    }
    children
      ..add(const SizedBox(height: 18))
      ..add(const _SectionTitle(icon: Icons.school_rounded, title: 'Залік'))
      ..add(const ExamOnSiteCard());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: children),
    );
  }
}

/// Тема «День N …» серед практичних тем.
EducationTopic? practiceDayTopic(List<EducationTopic> days, int n) {
  final re = RegExp('^\\s*День\\s*$n\\b');
  for (final t in days) {
    if (re.hasMatch(t.name)) return t;
  }
  return null;
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
