import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/screens/account_screen.dart';
import 'package:hunting_signals/screens/education_topic_screen.dart';
import 'package:hunting_signals/screens/flashcard_screen.dart';
import 'package:hunting_signals/screens/metronome_screen.dart';
import 'package:hunting_signals/screens/practice_screen.dart';
import 'package:hunting_signals/screens/test_screen.dart';
import 'package:hunting_signals/screens/theory_practice_test_screen.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/services/practical_service.dart';
import 'package:hunting_signals/services/practice_core.dart';
import 'package:hunting_signals/services/practice_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/practice_widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Екран одного кроку практики (як openStep у site/js/views/practice.js):
/// підказка, статус, коментар викладача й дія за видом кроку.
class PracticeStepScreen extends StatefulWidget {
  final PracticeStep step;
  final PracticeData data;
  final List<EducationTopic> days;
  const PracticeStepScreen({super.key, required this.step, required this.data, required this.days});

  @override
  State<PracticeStepScreen> createState() => _PracticeStepScreenState();
}

class _PracticeStepScreenState extends State<PracticeStepScreen> {
  late PracticeData _data = widget.data;
  bool _busy = false;
  String _progress = '';
  List<EducationTopic>? _topics;

  // поля форм — створюються один раз із збережених даних
  late final TextEditingController _note = TextEditingController(text: _stepWork['note']?.toString() ?? '');
  late final Map<String, TextEditingController> _diary = {
    for (final (k, _) in diaryFields) k: TextEditingController(text: _map(_map(_data.work['diary'])['d${widget.step.day}'])[k]?.toString() ?? ''),
  };
  late final Map<String, List<bool>> _breath = {
    for (final d in breathDates)
      d: List.generate(breathExercises.length, (i) => (_map(_map(_data.work['breath'])[d])['ex'] as List?)?.elementAtOrNull(i) == true),
  };
  late final Map<String, TextEditingController> _breathSec = {
    for (final d in breathDates) d: TextEditingController(text: _map(_map(_data.work['breath'])[d])['sec']?.toString() ?? ''),
  };
  late final Map<String, Map<String, bool>> _signals = {
    for (final s in trackedSignals)
      s: {for (final (k, _) in signalSkills) k: _map(_map(_data.work['signals'])[s])[k] == true},
  };

  /// Щоденник і таблиці перевіряє викладач.
  static const _saved = 'Збережено — викладач підтвердить';

  PracticeStep get step => widget.step;
  Map<String, dynamic> get _stepWork => _map(_map(_data.work['steps'])[step.id]);
  List<Map<String, dynamic>> get _files =>
      ((_stepWork['files'] as List?) ?? []).map((f) => Map<String, dynamic>.from(f as Map)).toList();

  static Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : {};

  @override
  void initState() {
    super.initState();
    if (step.kind == StepKind.quiz || step.kind == StepKind.retest) _loadTopics();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in [..._diary.values, ..._breathSec.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final t = await EducationService.getTopics();
    if (mounted) setState(() => _topics = t);
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? const Color(0xFFC62828) : null,
      duration: Duration(seconds: error ? 5 : 2),
    ));
  }

  /// Оновити автоматичні статуси (після тесту, «Мій акаунт»).
  Future<void> _reload() async {
    try {
      final d = await PracticeService.loadMine();
      if (mounted) setState(() => _data = d);
    } catch (_) {/* лишаємо попередні дані */}
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  /// Зберегти й оновити локально (merge одного рівня глибини, як у Firestore).
  Future<void> _persist(Map<String, dynamic> patch, String okText) async {
    setState(() => _busy = true);
    try {
      await PracticeService.saveWork(patch, fullName: _data.fullName, group: _data.group);
      for (final e in patch.entries) {
        _data.work[e.key] = {..._map(_data.work[e.key]), ...(e.value as Map<String, dynamic>)};
      }
      if (mounted) _toast(okText);
    } catch (e) {
      final denied = e.toString().contains('permission-denied');
      if (mounted) _toast('Не збережено: ${denied ? 'база не прийняла запис (немає доступу). Повідомте викладача' : e}', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveStep(Map<String, dynamic> fields, String okText) =>
      _persist({'steps': {step.id: {..._stepWork, ...fields}}}, okText);

  // ── Файли ──────────────────────────────────────────────────────────────────

  Future<void> _upload(List<(String, Future<Uint8List> Function())> picked) async {
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    final added = <Map<String, dynamic>>[];
    for (var i = 0; i < picked.length; i++) {
      final (name, read) = picked[i];
      setState(() => _progress = 'Завантаження ${i + 1} з ${picked.length}: $name…');
      try {
        final bytes = await read();
        added.add(await PracticeService.uploadStepFile(step.id, name, bytes));
      } catch (e) {
        final msg = e.toString().contains('unauthorized') ? 'Сховище не прийняло файл (немає доступу). Повідомте викладача' : e.toString().replaceFirst('Exception: ', '');
        if (mounted) _toast(msg, error: true);
      }
    }
    if (!mounted) return;
    setState(() => _progress = '');
    if (added.isNotEmpty) {
      await _saveStep({'files': [..._files, ...added]}, 'Додано файлів: ${added.length}');
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickFiles() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: PracticeService.allowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (r == null) return;
    await _upload([
      for (final f in r.files)
        if (f.bytes != null) (f.name, () async => f.bytes!),
    ]);
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
    if (x == null) return;
    // назва з камери — службова (scaled_<uuid>.jpg); викладачу зрозуміліша дата
    final d = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    final name = 'Фото_${d.year}-${p2(d.month)}-${p2(d.day)}_${p2(d.hour)}-${p2(d.minute)}-${p2(d.second)}.jpg';
    await _upload([(name, x.readAsBytes)]);
  }

  Future<void> _deleteFile(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Видалити файл?'),
        content: Text(f['name'].toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Скасувати')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Видалити', style: TextStyle(color: Color(0xFFC62828)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PracticeService.deleteStepFile(f);
    } catch (e) {
      if (mounted) _toast(e.toString(), error: true);
      return;
    }
    await _saveStep({'files': _files.where((x) => x['path'] != f['path']).toList()}, 'Файл видалено');
  }

  // ── Побудова ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final st = stepStatus(step, _data.work, _data.grades, _data.ctx);
    final g = _map(_data.grades[step.id]);
    final comment = g['comment']?.toString() ?? '';
    return Scaffold(
      backgroundColor: HuntingTheme.backgroundColor,
      appBar: AppBar(title: Text(step.title, maxLines: 2, style: const TextStyle(fontSize: 17))),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (step.hint != null) Text(step.hint!, style: const TextStyle(height: 1.45)),
              if (step.due != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Здати до ${step.due}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ),
              const SizedBox(height: 4),
              PracticeStatusChip(st),
              if (comment.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Коментар викладача: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: comment),
                  ])),
                ),
            ])),
            if (_busy) const LinearProgressIndicator(),
            if (_progress.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_progress, style: const TextStyle(fontSize: 13))),
            const SizedBox(height: 8),
            ..._kindContent(st),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      );

  Widget _primary(IconData icon, String label, VoidCallback onPressed) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label, textAlign: TextAlign.center),
            style: ElevatedButton.styleFrom(
              backgroundColor: HuntingTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );

  Widget _secondary(IconData icon, String label, VoidCallback onPressed) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label, textAlign: TextAlign.center),
            style: OutlinedButton.styleFrom(
              foregroundColor: HuntingTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );

  Widget? _dayMaterials() {
    final topic = step.day == null ? null : practiceDayTopic(widget.days, step.day!);
    if (topic == null) return null;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _open(EducationTopicScreen(topic: topic, materialLoader: PracticalService.getMaterialsByTopic)),
        icon: const Icon(Icons.folder_open_rounded),
        label: const Text('Матеріали дня'),
      ),
    );
  }

  List<Widget> _kindContent(StepStatus st) {
    switch (step.kind) {
      case StepKind.profile:
        return [_primary(Icons.person_rounded, 'Відкрити «Мій акаунт» → «Мої дані»', () => _open(const AccountScreen()))];
      case StepKind.check:
        return [
          if (step.action == 'metronome') _secondary(Icons.timer_rounded, 'Відкрити метроном', () => _open(const MetronomeScreen())),
          if (step.action == 'cards') _secondary(Icons.style_rounded, 'Флеш-картки', () => _open(const _CardsTopicsScreen())),
          if (st.state == PracticeState.review)
            _secondary(Icons.undo_rounded, 'Зняти відмітку', () => _saveStep({'done': false}, 'Відмітку знято'))
          else if (st.state != PracticeState.graded)
            _primary(Icons.check_rounded, st.state == PracticeState.revise ? 'Позначити виконаним знову' : 'Позначити виконаним',
                () => _saveStep({'done': true, 'doneAt': DateTime.now().millisecondsSinceEpoch}, 'Відмітку надіслано викладачу')),
        ];
      case StepKind.submit:
        return _submitContent(st);
      case StepKind.quiz:
      case StepKind.retest:
        return _quizContent();
      case StepKind.audio:
        return [
          _primary(Icons.campaign_rounded, 'Аудіотест «Сигнали практики»', () => _open(const TestScreen(tag: kPracticeTag))),
          _secondary(Icons.headphones_rounded, 'Аудіотест — легкий рівень', () => _open(const TestScreen(difficulty: 'easy'))),
        ];
      case StepKind.diary:
        return [
          ?_dayMaterials(),
          for (final (k, label) in diaryFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _diary[k],
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(labelText: label, alignLabelWithHint: true, filled: true, fillColor: Colors.white,
                    border: const OutlineInputBorder()),
              ),
            ),
          _primary(Icons.save_rounded, 'Зберегти запис', () {
            FocusScope.of(context).unfocus();
            _persist({
              'diary': {'d${step.day}': {for (final e in _diary.entries) e.key: e.value.text.trim()}},
              'steps': {step.id: {'submittedAt': DateTime.now().millisecondsSinceEpoch}},
            }, _saved);
          }),
        ];
      case StepKind.breath:
        return _breathContent();
      case StepKind.signals:
        return _signalsContent();
      case StepKind.exam:
        return [const ExamOnSiteCard()];
      case StepKind.teacher:
        return [];
    }
  }

  List<Widget> _submitContent(StepStatus st) {
    final locked = st.state == PracticeState.graded;
    final files = _files;
    void submit() {
      if (step.fileRequired && files.isEmpty) {
        _toast('Спершу додайте хоча б один файл (фото або документ)', error: true);
        return;
      }
      FocusScope.of(context).unfocus();
      _saveStep({'note': _note.text.trim(), 'done': true, 'submittedAt': DateTime.now().millisecondsSinceEpoch}, 'Здано на перевірку');
    }

    return [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Файли${step.fileRequired ? ' (обов’язково)' : ' (за потреби)'}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (files.isEmpty)
          Text('Ще немає файлів. Можна фото сторінок зошита/щоденника, PDF, DOCX, PPTX — до 20 МБ.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))
        else
          PracticeFileList(files, onDelete: locked ? null : _deleteFile),
        if (!locked) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Фото'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Файли'),
              ),
            ),
          ]),
        ],
      ])),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _note,
          enabled: !locked,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Коментар для викладача (необов’язково)', alignLabelWithHint: true,
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(),
          ),
        ),
      ),
      if (!locked)
        if (st.state == PracticeState.review) ...[
          _primary(Icons.save_rounded, 'Оновити здану роботу', submit),
          _secondary(Icons.undo_rounded, 'Скасувати здачу', () => _saveStep({'done': false}, 'Здачу скасовано')),
        ] else
          _primary(Icons.task_alt_rounded, st.state == PracticeState.revise ? 'Здати повторно' : 'Позначити виконаним і здати на перевірку', submit),
    ];
  }

  List<Widget> _quizContent() {
    final topics = _topics;
    if (topics == null) return [const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))];
    final best = bestByTopic(_data.ctx.quizResults);
    return [
      for (final n in step.topics)
        Builder(builder: (context) {
          final re = RegExp('Тема\\s+$n\\b');
          final t = topics.where((x) => re.hasMatch(x.name)).firstOrNull;
          final b = best[n];
          final ok = b != null && (step.kind != StepKind.retest || b >= step.threshold);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? const Color(0xFF2E7D32) : Colors.grey),
              title: Text(t?.name ?? 'Тема $n', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(b != null ? 'Найкращий результат: $b %' : 'Ще не пройдено'),
              trailing: t == null
                  ? const Text('тему не знайдено', style: TextStyle(fontSize: 12))
                  : FilledButton(
                      onPressed: () async {
                        await startTheoryPracticeTest(context, t);
                        if (mounted) _reload();
                      },
                      child: const Text('Пройти'),
                    ),
            ),
          );
        }),
    ];
  }

  List<Widget> _breathContent() => [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < breathExercises.length; i++)
            Text('${i + 1} — ${breathExercises[i]}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {0: FixedColumnWidth(48), 5: FixedColumnWidth(72)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                const Text('Дата', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                for (var i = 0; i < breathExercises.length; i++)
                  Center(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                const Center(child: Text('Видих, с', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
              for (final d in breathDates)
                TableRow(children: [
                  Text(d, style: const TextStyle(fontSize: 13)),
                  for (var i = 0; i < breathExercises.length; i++)
                    Checkbox(
                      value: _breath[d]![i],
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => _breath[d]![i] = v ?? false),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: _breathSec[d],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                ]),
            ],
          ),
        ])),
        _primary(Icons.save_rounded, 'Зберегти таблицю', () {
          FocusScope.of(context).unfocus();
          _persist({
            'breath': {
              for (final d in breathDates)
                d: {'ex': List<bool>.from(_breath[d]!), 'sec': int.tryParse(_breathSec[d]!.text.trim())},
            },
            'steps': {step.id: {'submittedAt': DateTime.now().millisecondsSinceEpoch}},
          }, _saved);
        }),
      ];

  List<Widget> _signalsContent() => [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Table(
            columnWidths: const {0: FlexColumnWidth(2)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                const Text('Сигнал', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                for (final (_, l) in signalSkills)
                  Center(child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ]),
              for (final s in trackedSignals)
                TableRow(children: [
                  Text(s, style: const TextStyle(fontSize: 13)),
                  for (final (k, _) in signalSkills)
                    Checkbox(
                      value: _signals[s]![k],
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => _signals[s]![k] = v ?? false),
                    ),
                ]),
            ],
          ),
        ])),
        _primary(Icons.save_rounded, 'Зберегти', () => _persist({
              'signals': {for (final e in _signals.entries) e.key: Map<String, bool>.from(e.value)},
              'steps': {step.id: {'submittedAt': DateTime.now().millisecondsSinceEpoch}},
            }, _saved)),
      ];
}

/// Вибір теми для флеш-карток.
class _CardsTopicsScreen extends StatelessWidget {
  const _CardsTopicsScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: HuntingTheme.backgroundColor,
        appBar: AppBar(title: const Text('Флеш-картки')),
        body: FutureBuilder<List<EducationTopic>>(
          future: EducationService.getTopics(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final topics = snap.data!;
            if (topics.isEmpty) return const Center(child: Text('Теми ще не додані'));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final t in topics)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.style_rounded),
                      title: Text(t.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardScreen(topic: t))),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}
