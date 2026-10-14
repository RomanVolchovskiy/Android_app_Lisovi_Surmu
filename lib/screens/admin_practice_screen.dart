import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hunting_signals/services/practice_core.dart';
import 'package:hunting_signals/services/practice_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/practice_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Адмін: «Практика: роботи й оцінки» (як site/js/views/admin-practice.js) —
/// журнал студентів, сторінка студента з файлами, щоденником і таблицями,
/// оцінювання кроків (бали + коментар або «на доопрацювання»), експорт CSV.
class AdminPracticeScreen extends StatefulWidget {
  const AdminPracticeScreen({super.key});

  @override
  State<AdminPracticeScreen> createState() => _AdminPracticeScreenState();
}

class _AdminPracticeScreenState extends State<AdminPracticeScreen> {
  List<PracticeData>? _students;
  String? _error;
  String _group = '';
  bool _onlyReview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _students = null;
      _error = null;
    });
    try {
      final s = await PracticeService.loadAll();
      if (mounted) setState(() => _students = s);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HuntingTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Практика: роботи й оцінки', style: TextStyle(fontSize: 17)),
        actions: [IconButton(tooltip: 'Оновити', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Помилка завантаження: $_error')));
    final students = _students;
    if (students == null) return const Center(child: CircularProgressIndicator());
    final groups = {for (final s in students) if (s.group.isNotEmpty) s.group}.toList()..sort();
    final rows = [
      for (final s in students)
        (s: s, t: practiceTotals(s.work, s.grades, s.ctx)),
    ].where((r) => (_group.isEmpty || r.s.group == _group) && (!_onlyReview || r.t.review > 0)).toList();
    final reviewTotal = students.fold<int>(0, (a, s) => a + practiceTotals(s.work, s.grades, s.ctx).review);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Студентів: ${students.length} · робіт на перевірці: $reviewTotal', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Поточна робота — макс. $maxCurrent (допуск від $admissionMin), залік — макс. $maxExam. Тести й іспит рахуються автоматично.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(height: 8),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                DropdownButton<String>(
                  value: groups.contains(_group) ? _group : '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Усі групи')),
                    for (final g in groups) DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setState(() => _group = v ?? ''),
                ),
                FilterChip(
                  label: const Text('Лише на перевірці'),
                  selected: _onlyReview,
                  onSelected: (v) => setState(() => _onlyReview = v),
                ),
                OutlinedButton.icon(onPressed: () => _exportCsv(rows), icon: const Icon(Icons.download_rounded), label: const Text('CSV')),
              ]),
            ]),
          ),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Тут з’являться студенти, які заповнили групу в «Мої дані» або почали практику', textAlign: TextAlign.center),
          ),
        for (final r in rows)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => _StudentScreen(uid: r.s.uid, email: r.s.email)));
                if (mounted) _load();
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(width: 4, color: r.t.review > 0
                      ? const Color(0xFF1565C0)
                      : r.t.admitted ? const Color(0xFF2E7D32) : const Color(0xFFBDBDBD))),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.s.fullName.isNotEmpty ? r.s.fullName : (r.s.email.isNotEmpty ? r.s.email : r.s.uid),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${r.s.group.isNotEmpty ? r.s.group : 'група не вказана'} · виконано ${r.t.done}/${r.t.count}'
                          '${r.t.review > 0 ? ' · на перевірці: ${r.t.review}' : ''}', style: const TextStyle(fontSize: 13)),
                      Text('Поточна ${_n(r.t.current)}/$maxCurrent${r.t.admitted ? ' ✓ допуск' : ''} · залік ${_n(r.t.exam)}/$maxExam',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ]),
                  ),
                  Column(children: [
                    Text(_n(r.t.total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: HuntingTheme.primaryColor)),
                    Text(r.t.exam > 0 ? r.t.grade.ects : '—', style: const TextStyle(fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Future<void> _exportCsv(List<({PracticeData s, PracticeTotals t})> rows) async {
    final steps = allPracticeSteps.where((s) => s.group != null).toList();
    String q(Object? v) {
      final s = '${v ?? ''}';
      return RegExp(r'[",;\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final lines = [
      ['ПІБ', 'Група', 'Email', for (final s in steps) '${s.title} (${s.points})', 'Поточна (60)', 'Залік (40)', 'Разом', 'ЄКТС', 'Оцінка', 'Допуск', 'Виконано пунктів', 'На перевірці'],
      for (final r in rows)
        [
          r.s.fullName, r.s.group, r.s.email,
          for (final st in steps) stepStatus(st, r.s.work, r.s.grades, r.s.ctx).points ?? '',
          _n(r.t.current), _n(r.t.exam), _n(r.t.total), r.t.grade.ects, r.t.grade.nat, r.t.admitted ? 'так' : 'ні', '${r.t.done}/${r.t.count}', r.t.review,
        ],
    ];
    // BOM — щоб Excel відкрив кирилицю
    final csv = '﻿${lines.map((l) => l.map(q).join(',')).join('\r\n')}';
    try {
      final d = DateTime.now();
      String p2(int v) => v.toString().padLeft(2, '0');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Практика_оцінки_${d.year}-${p2(d.month)}-${p2(d.day)}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], subject: 'Практика: оцінки');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не вдалося експортувати: $e')));
    }
  }
}

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _StudentScreen extends StatefulWidget {
  final String uid, email;
  const _StudentScreen({required this.uid, required this.email});

  @override
  State<_StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<_StudentScreen> {
  PracticeData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await PracticeService.loadStudent(widget.uid, email: widget.email);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _grade(PracticeStep step, {num? points, String comment = '', String status = 'graded'}) async {
    try {
      await PracticeService.saveGrade(widget.uid, step.id, points: points, comment: comment, status: status);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Збережено')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не збережено: $e'), backgroundColor: const Color(0xFFC62828)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: HuntingTheme.backgroundColor,
      appBar: AppBar(title: const Text('Робота студента')),
      body: _error != null
          ? Center(child: Text('Помилка: $_error'))
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                    child: ListTile(
                      title: Text(d.fullName.isNotEmpty ? d.fullName : d.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${d.group.isNotEmpty ? d.group : '—'} · ${d.email}'),
                    ),
                  ),
                  PracticeSummaryCard(practiceTotals(d.work, d.grades, d.ctx)),
                  ..._steps(d),
                ]),
    );
  }

  List<Widget> _steps(PracticeData d) {
    final out = <Widget>[];
    var n = 0;
    for (final stage in practiceStages) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text('${stage.title} · ${stage.date}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4E342E))),
      ));
      for (final step in stage.steps) {
        n++;
        out.add(_StepGradeCard(
          key: ValueKey('${step.id}_${d.grades[step.id].hashCode}'),
          num: n, step: step, data: d,
          onGrade: ({num? points, String comment = '', String status = 'graded'}) =>
              _grade(step, points: points, comment: comment, status: status),
        ));
      }
    }
    return out;
  }
}

typedef _GradeFn = Future<void> Function({num? points, String comment, String status});

class _StepGradeCard extends StatefulWidget {
  final int num;
  final PracticeStep step;
  final PracticeData data;
  final _GradeFn onGrade;
  const _StepGradeCard({super.key, required this.num, required this.step, required this.data, required this.onGrade});

  @override
  State<_StepGradeCard> createState() => _StepGradeCardState();
}

class _StepGradeCardState extends State<_StepGradeCard> {
  late final Map<String, dynamic> _g = _map(widget.data.grades[widget.step.id]);
  late final TextEditingController _pts = TextEditingController(
      text: _g.isNotEmpty && _g['status'] != 'revise' && _g['points'] != null ? _n(_g['points'] as num) : '');
  late final TextEditingController _comment = TextEditingController(text: _g['comment']?.toString() ?? '');

  static Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : {};

  @override
  void dispose() {
    _pts.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), backgroundColor: const Color(0xFFC62828)));

  void _save() {
    final max = widget.step.points;
    FocusScope.of(context).unfocus();
    if (max > 0) {
      final v = int.tryParse(_pts.text.trim());
      if (v == null || v < 0 || v > max) {
        _toast('Бали — ціле число від 0 до $max');
        return;
      }
      widget.onGrade(points: v, comment: _comment.text.trim());
    } else {
      widget.onGrade(points: 0, comment: _comment.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final d = widget.data;
    final st = stepStatus(step, d.work, d.grades, d.ctx);
    final s = _map(_map(d.work['steps'])[step.id]);
    final files = ((s['files'] as List?) ?? []).map((f) => Map<String, dynamic>.from(f as Map)).toList();
    final details = <Widget>[
      if (files.isNotEmpty) PracticeFileList(files),
      if ((s['note']?.toString() ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(TextSpan(children: [
            const TextSpan(text: 'Коментар студента: ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: s['note'].toString()),
          ])),
        ),
      if (step.kind == StepKind.diary) PracticeDiaryView(_map(d.work['diary'])['d${step.day}']),
      if (step.kind == StepKind.breath) PracticeBreathView(d.work['breath']),
      if (step.kind == StepKind.signals) PracticeSignalsView(d.work['signals']),
    ];
    // відмітку, щоденник і таблиці підтверджують, коли студент їх виконав
    final confirm = confirmKinds.contains(step.kind);
    final gradable = const [StepKind.submit, StepKind.teacher, StepKind.exam].contains(step.kind) ||
        (confirm && st.state != PracticeState.todo);
    final max = step.points;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(width: 4, color: practiceStateStyle(st.state).color))),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PracticeNumberBadge(widget.num, st.state),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(step.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                PracticeStatusChip(st),
              ]),
            ),
          ]),
          if (details.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: st.state == PracticeState.review,
              title: Text('Подивитися', style: TextStyle(color: HuntingTheme.primaryColor, fontSize: 14)),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: details,
            ),
          if (gradable) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (max > 0) ...[
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _pts,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true, border: const OutlineInputBorder(),
                      hintText: step.kind == StepKind.exam && st.points != null ? 'авто ${_n(st.points!)}' : null,
                      hintStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('з $max')),
              ],
              Expanded(
                child: TextField(
                  controller: _comment,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Коментар студенту'),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (!(confirm && st.state == PracticeState.graded))
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check, size: 18), label: Text(max > 0 ? 'Оцінити' : confirm ? 'Підтвердити' : 'Прийняти')),
              if (step.kind == StepKind.submit)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                  onPressed: () {
                    if (_comment.text.trim().isEmpty) {
                      _toast('Напишіть у коментарі, що доопрацювати');
                      return;
                    }
                    widget.onGrade(points: null, comment: _comment.text.trim(), status: 'revise');
                  },
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('На доопрацювання'),
                ),
              if (confirm)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                  onPressed: () => widget.onGrade(points: null, comment: _comment.text.trim(), status: 'revise'),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Не підтверджено'),
                ),
              if (_g.isNotEmpty)
                TextButton.icon(
                  onPressed: () => widget.onGrade(points: null, comment: '', status: 'none'),
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  label: Text(step.kind == StepKind.exam ? 'Повернути авто' : 'Скинути'),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
