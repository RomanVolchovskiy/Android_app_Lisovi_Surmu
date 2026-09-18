import 'dart:io' if (dart.library.html) 'package:hunting_signals/stubs/dart_io_stub.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/services/practical_service.dart';
import 'package:hunting_signals/services/study_plan_service.dart';
import 'package:hunting_signals/utils/docx_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _levelLabel = {
  'basic':        'Базовий',
  'standard':     'Стандартний',
  'professional': 'Професійний',
  'expert':       'Експертний',
};

// ── Ширини фіксованих колонок ──────────────────────────────────────────────────
const double _cNum   = 48.0;
const double _cTotal = 72.0;
const double _cLect  = 72.0;
const double _cPract = 90.0;
const double _cSelf  = 90.0;
// Мінімальна ширина колонки "Назва теми"
const double _cNameMin = 200.0;

// Сума всіх фіксованих колонок + 6 вертикальних роздільників (по 1px)
const double _fixedWidth = _cNum + _cTotal + _cLect + _cPract + _cSelf + 6;

const _darkGreen  = Color(0xFF1C3A1C);
const _lightGreen = Color(0xFF2E5E2E);
const _gold       = Color(0xFFD4A017);
const _cream      = Color(0xFFFFF8E7);
const _rowBorder  = Color(0xFFE8C87A);

class LevelThematicScreen extends StatefulWidget {
  final String level;
  const LevelThematicScreen({super.key, required this.level});

  @override
  State<LevelThematicScreen> createState() => _LevelThematicScreenState();
}

class _LevelThematicScreenState extends State<LevelThematicScreen> {
  List<StudyPlanEntry> _entries    = [];
  List<EducationTopic> _eduTopics  = [];
  List<EducationTopic> _practTopics= [];
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _downloadDocx() async {
    if (_entries.isEmpty) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Завантаження DOCX не підтримується у веб-версії')),
      );
      return;
    }
    setState(() => _downloading = true);
    try {
      final levelName = _levelLabel[widget.level] ?? widget.level;
      final rows = _entries.map((e) => (
        name:  _name(e),
        total: e.hours,
        lect:  _lect(e),
        pract: _pract(e),
        self:  _self(e),
      )).toList();

      final bytes = DocxGenerator.generate(levelName: levelName, rows: rows);
      final dir   = await getTemporaryDirectory();
      final file  = File('${dir.path}/thematic_plan_${widget.level}.docx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')],
        subject: 'Тематичний план — $levelName рівень',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await Future.wait([
      StudyPlanService.getAdminPlanByLevel(widget.level),
      EducationService.getTopics(),
      PracticalService.getTopics(),
    ]);
    if (mounted) setState(() {
      _entries     = r[0] as List<StudyPlanEntry>;
      _eduTopics   = r[1] as List<EducationTopic>;
      _practTopics = r[2] as List<EducationTopic>;
      _loading     = false;
    });
  }

  String _name(StudyPlanEntry e) {
    final list = e.topicType == 'practical' ? _practTopics : _eduTopics;
    try { return list.firstWhere((t) => t.id == e.topicId).name; }
    catch (_) { return e.topicId; }
  }

  int _lect (StudyPlanEntry e) => e.topicType == 'theoretical' ? e.hours : 0;
  int _pract(StudyPlanEntry e) => e.topicType == 'practical'   ? e.hours : 0;
  int _self (StudyPlanEntry e) => e.topicType == 'selfStudy'   ? e.hours : 0;

  @override
  Widget build(BuildContext context) {
    final levelName = _levelLabel[widget.level] ?? widget.level;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: Text('Тематичний план — $levelName рівень'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _entries.isNotEmpty)
            _downloading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'Завантажити DOCX',
                    onPressed: _downloadDocx,
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.table_chart_rounded, size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Теми не додані до цього рівня',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  ]),
                )
              : LayoutBuilder(
                  builder: (ctx, constraints) {
                    // Ширина колонки "Назва теми" = залишок простору
                    final nameW = (constraints.maxWidth - 32 - _fixedWidth)
                        .clamp(_cNameMin, double.infinity);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildTable(nameW),
                    );
                  },
                ),
    );
  }

  Widget _buildTable(double nameW) {
    final sumTotal = _entries.fold(0, (s, e) => s + e.hours);
    final sumLect  = _entries.fold(0, (s, e) => s + _lect(e));
    final sumPract = _entries.fold(0, (s, e) => s + _pract(e));
    final sumSelf  = _entries.fold(0, (s, e) => s + _self(e));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _darkGreen, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          children: [
            // ── Рядок заголовка 1 ────────────────────────────────────────
            Container(
              color: _darkGreen,
              child: Row(
                children: [
                  _H(w: _cNum,   text: '№',           rows: 2),
                  _VL(header: true),
                  _H(w: nameW,   text: 'Назва теми',  rows: 2),
                  _VL(header: true),
                  // "Кількість годин" охоплює 4 підколонки
                  SizedBox(
                    width: _cTotal + 1 + _cLect + 1 + _cPract + 1 + _cSelf,
                    child: Column(children: [
                      Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: _gold, width: 1)),
                        ),
                        child: const Text('Кількість годин',
                            style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      // Рядок підзаголовків
                      Container(
                        color: _lightGreen,
                        child: Row(children: [
                          _H(w: _cTotal, text: 'Всього',     sub: true),
                          _VL(header: true),
                          _H(w: _cLect,  text: 'Лекції',     sub: true),
                          _VL(header: true),
                          _H(w: _cPract, text: 'Практичні',  sub: true),
                          _VL(header: true),
                          _H(w: _cSelf,  text: 'Самостійні', sub: true),
                        ]),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            // ── Рядки даних ──────────────────────────────────────────────
            ..._entries.asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              final isLast = i == _entries.length - 1;
              return Container(
                decoration: BoxDecoration(
                  color: i % 2 == 0 ? _cream : Colors.white,
                  border: isLast ? null
                      : const Border(bottom: BorderSide(color: _rowBorder, width: 1)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _D(w: _cNum,   text: '${i + 1}', center: true, bold: true),
                      _VL(),
                      SizedBox(
                        width: nameW,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          child: Text(_name(entry),
                              style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ),
                      ),
                      _VL(),
                      _D(w: _cTotal, text: '${entry.hours}', center: true, bold: true, color: _darkGreen),
                      _VL(),
                      _D(w: _cLect,  text: _lect(entry)  > 0 ? '${_lect(entry)}'  : '—', center: true),
                      _VL(),
                      _D(w: _cPract, text: _pract(entry) > 0 ? '${_pract(entry)}' : '—', center: true),
                      _VL(),
                      _D(w: _cSelf,  text: _self(entry)  > 0 ? '${_self(entry)}'  : '—', center: true),
                    ],
                  ),
                ),
              );
            }),
            // ── Підсумок ─────────────────────────────────────────────────
            Container(
              color: const Color(0xFFEAD98B),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _D(w: _cNum, text: ''),
                    _VL(),
                    SizedBox(
                      width: nameW,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Text('Разом',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _darkGreen)),
                      ),
                    ),
                    _VL(),
                    _D(w: _cTotal, text: '$sumTotal', center: true, bold: true, color: _darkGreen),
                    _VL(),
                    _D(w: _cLect,  text: '$sumLect',  center: true, bold: true),
                    _VL(),
                    _D(w: _cPract, text: '$sumPract',  center: true, bold: true),
                    _VL(),
                    _D(w: _cSelf,  text: '$sumSelf',   center: true, bold: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Клітинка заголовка ────────────────────────────────────────────────────────
class _H extends StatelessWidget {
  final double w;
  final String text;
  final bool sub;
  final int rows;
  const _H({required this.w, required this.text, this.sub = false, this.rows = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: sub ? 6 : 7),
        child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sub ? Colors.white70 : _gold,
            fontWeight: FontWeight.w700,
            fontSize: sub ? 11 : 13,
          ),
        ),
      ),
    );
  }
}

// ── Клітинка даних ────────────────────────────────────────────────────────────
class _D extends StatelessWidget {
  final double w;
  final String text;
  final bool center, bold;
  final Color? color;
  const _D({required this.w, required this.text,
      this.center = false, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Text(text,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ── Вертикальний роздільник ───────────────────────────────────────────────────
class _VL extends StatelessWidget {
  final bool header;
  const _VL({this.header = false});

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        color: header ? _gold.withValues(alpha: 0.5) : _rowBorder,
      );
}
