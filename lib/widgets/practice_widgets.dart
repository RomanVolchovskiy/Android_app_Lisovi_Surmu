import 'package:flutter/material.dart';
import 'package:hunting_signals/services/practice_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Спільні віджети розділу «Практика» — для студента й викладача
/// (як statusChip, summaryCard, fileList… у site/js/views/practice.js).

typedef StateStyle = ({Color color, Color bg, IconData icon});

StateStyle practiceStateStyle(PracticeState s) => switch (s) {
      PracticeState.todo => (color: const Color(0xFF757575), bg: const Color(0xFFF1F1F1), icon: Icons.radio_button_unchecked),
      PracticeState.done => (color: const Color(0xFF2E7D32), bg: const Color(0xFFE8F5E9), icon: Icons.check_circle),
      PracticeState.review => (color: const Color(0xFF1565C0), bg: const Color(0xFFE3F2FD), icon: Icons.hourglass_top),
      PracticeState.revise => (color: const Color(0xFFC62828), bg: const Color(0xFFFFEBEE), icon: Icons.replay),
      PracticeState.graded => (color: const Color(0xFF2E7D32), bg: const Color(0xFFE8F5E9), icon: Icons.verified),
      PracticeState.teacher => (color: const Color(0xFF8D6E63), bg: const Color(0xFFEFEBE9), icon: Icons.person),
    };

class PracticeStatusChip extends StatelessWidget {
  final StepStatus status;
  const PracticeStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = practiceStateStyle(status.state);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 15, color: s.color),
        const SizedBox(width: 4),
        Flexible(child: Text(status.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.color, height: 1.3))),
      ]),
    );
  }
}

class PracticeNumberBadge extends StatelessWidget {
  final int n;
  final PracticeState state;
  const PracticeNumberBadge(this.n, this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = practiceStateStyle(state);
    return Container(
      width: 30, height: 30, alignment: Alignment.center,
      decoration: BoxDecoration(color: s.bg, shape: BoxShape.circle),
      child: Text('$n', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: s.color)),
    );
  }
}

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Підсумок: виконано, поточні бали, залік, загальна кількість балів, оцінка.
class PracticeSummaryCard extends StatelessWidget {
  final PracticeTotals t;
  const PracticeSummaryCard(this.t, {super.key});

  Widget _cell(String label, String value, String? sub, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: const Color(0xFF2F4F2F).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Виконано ${t.done} з ${t.count} пунктів', style: const TextStyle(fontWeight: FontWeight.w600))),
          if (t.review > 0)
            Text('на перевірці: ${t.review}', style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: t.done / t.count, minHeight: 8, backgroundColor: Colors.white,
            color: const Color(0xFF4A7C4A),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          // дві колонки на телефоні, три — ширше
          final w = c.maxWidth >= 460 ? (c.maxWidth - 16) / 3 : (c.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(width: w, child: _cell('Поточна робота', '${_n(t.current)} / $maxCurrent',
                t.admitted ? 'Допуск до заліку ✓' : 'для допуску — $admissionMin',
                t.admitted ? const Color(0xFF2E7D32) : const Color(0xFF1C3A1C))),
            SizedBox(width: w, child: _cell('Залік', '${_n(t.exam)} / $maxExam', 'тест 20 · аудіо 6 · сигнал 8 · ритм 6', const Color(0xFF1C3A1C))),
            SizedBox(
              width: c.maxWidth >= 460 ? w : c.maxWidth,
              child: _cell('Загальна кількість балів', '${_n(t.total)} / 100',
                  t.exam > 0 ? '${t.grade.ects} · ${t.grade.nat}' : 'оцінка — після заліку', const Color(0xFF4E342E)),
            ),
          ]);
        }),
      ]),
    );
  }
}

String fmtFileSize(num n) => n > 1048576 ? '${(n / 1048576).toStringAsFixed(1)} МБ' : '${(n / 1024).round().clamp(1, 1024)} КБ';

Future<void> openPracticeFile(BuildContext context, Map<String, dynamic> f) async {
  final ok = await launchUrl(Uri.parse(f['url'].toString()), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не вдалося відкрити файл')));
  }
}

/// Список файлів кроку; кнопка видалення — якщо [onDelete].
class PracticeFileList extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  final void Function(Map<String, dynamic>)? onDelete;
  const PracticeFileList(this.files, {super.key, this.onDelete});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final f in files)
          InkWell(
            onTap: () => openPracticeFile(context, f),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                Icon(f['type'].toString().startsWith('image/') ? Icons.image_outlined : Icons.description_outlined,
                    color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(child: Text(f['name'].toString(), style: const TextStyle(color: Color(0xFF2F4F2F), decoration: TextDecoration.underline))),
                Text(fmtFileSize((f['size'] as num?) ?? 0), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (onDelete != null)
                  IconButton(tooltip: 'Видалити файл', icon: const Icon(Icons.delete_outline), onPressed: () => onDelete!(f)),
              ]),
            ),
          ),
      ]);
}

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : {};

/// Перегляд запису щоденника (для викладача).
class PracticeDiaryView extends StatelessWidget {
  final Object? entry;
  const PracticeDiaryView(this.entry, {super.key});

  @override
  Widget build(BuildContext context) {
    final e = _map(entry);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (k, label) in diaryFields) ...[
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text((e[k]?.toString() ?? '').isEmpty ? '—' : e[k].toString()),
        ),
      ],
    ]);
  }
}

class PracticeBreathView extends StatelessWidget {
  final Object? table;
  const PracticeBreathView(this.table, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = _map(table);
    const st = TextStyle(fontSize: 13);
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4)},
      children: [
        TableRow(children: [
          const Text('Дата', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          for (var i = 0; i < breathExercises.length; i++)
            Center(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          const Center(child: Text('Видих, с', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        for (final d in breathDates)
          TableRow(children: [
            Text(d, style: st),
            for (var i = 0; i < breathExercises.length; i++)
              Center(child: Text(((_map(t[d])['ex'] as List?)?.elementAtOrNull(i) == true) ? '+' : '', style: st)),
            Center(child: Text(_map(t[d])['sec']?.toString() ?? '', style: st)),
          ]),
      ],
    );
  }
}

class PracticeSignalsView extends StatelessWidget {
  final Object? table;
  const PracticeSignalsView(this.table, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = _map(table);
    return Table(
      columnWidths: const {0: FlexColumnWidth(2.2)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          const Text('Сигнал', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          for (final (_, l) in signalSkills) Center(child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        ]),
        for (final s in trackedSignals)
          TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(s, style: const TextStyle(fontSize: 13))),
            for (final (k, _) in signalSkills) Center(child: Text(_map(t[s])[k] == true ? '✓' : '')),
          ]),
      ],
    );
  }
}
