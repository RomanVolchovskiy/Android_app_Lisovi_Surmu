import 'dart:async';
import 'package:flutter/foundation.dart' show Uint8List;
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/models/exam_models.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/services/exam_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';

const _darkGreen = Color(0xFF1C3A1C);
const _gold      = Color(0xFFD4A017);

// ── Вхід в іспит: введення коду і імені ──────────────────────────────────────
class ExamEntryScreen extends StatefulWidget {
  const ExamEntryScreen({super.key});

  @override
  State<ExamEntryScreen> createState() => _ExamEntryScreenState();
}

class _ExamEntryScreenState extends State<ExamEntryScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Введіть 6-значний код сесії');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Введіть ваше ім\'я');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final session = await ExamService.getSessionByCode(code);
    if (!mounted) return;

    if (session == null) {
      setState(() { _loading = false; _error = 'Сесію не знайдено. Перевірте код.'; });
      return;
    }
    if (!session.isActive) {
      setState(() { _loading = false; _error = 'Ця сесія вже закрита або ще не активна.'; });
      return;
    }
    if (session.isExpired) {
      setState(() { _loading = false; _error = 'Час для здачі цієї сесії вичерпано.'; });
      return;
    }

    final already = await ExamService.hasSubmitted(session.id, name);
    if (!mounted) return;
    if (already) {
      setState(() { _loading = false; _error = 'Ви вже здали цю сесію.'; });
      return;
    }

    setState(() => _loading = false);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ExamTakingScreen(session: session, studentName: name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: const Text('Вхід до іспиту'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _darkGreen.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, size: 56, color: _darkGreen),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Код сесії', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 6),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold,
                  letterSpacing: 8, color: _darkGreen),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '______',
                hintStyle: TextStyle(letterSpacing: 8, color: Colors.grey[400]),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _gold)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _darkGreen, width: 2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Ваше ім\'я', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'Прізвище Ім\'я',
                filled: true, fillColor: Colors.white,
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _gold)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _darkGreen, width: 2)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _enter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Почати іспит',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Проходження іспиту ────────────────────────────────────────────────────────
enum _ExamStep { intro, theory, audio, file, submitting, done }

class ExamTakingScreen extends StatefulWidget {
  final ExamSession session;
  final String studentName;
  const ExamTakingScreen({super.key, required this.session, required this.studentName});

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> {
  _ExamStep _step = _ExamStep.intro;
  bool _loading = false;

  // Theory
  List<TestQuestion> _theoryQ = [];
  int _theoryIdx = 0;
  int? _theorySelected;
  bool _theoryAnswered = false;
  int _theoryCorrect = 0;
  final List<int?> _theoryAnswers = [];

  // Audio
  List<_AQ> _audioQ = [];
  int _audioIdx = 0;
  int? _audioSelected;
  bool _audioAnswered = false;
  int _audioCorrect = 0;
  final List<int?> _audioAnswers = [];
  final AudioPlayer _audio = AudioPlayer();
  final ValueNotifier<({bool loading, bool playing})> _audioState =
      ValueNotifier((loading: false, playing: false));
  Timer? _timer;
  final ValueNotifier<int> _timeLeft = ValueNotifier(30);

  // File
  Uint8List? _pickedFile;
  String? _pickedFileName;
  bool _uploading = false;

  // Result
  ExamSubmission? _submission;

  @override
  void initState() {
    super.initState();
    _audio.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      _audioState.value = (loading: false, playing: s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.dispose();
    _audioState.dispose();
    _timeLeft.dispose();
    super.dispose();
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _loadTheory() async {
    setState(() => _loading = true);
    final all = await EducationService.getTestQuestionsByTopic(
        widget.session.theoryTopicId ?? '');
    all.shuffle(Random());
    _theoryQ = all.take(widget.session.theoryQuestionCount).toList();
    setState(() { _loading = false; _step = _ExamStep.theory; });
  }

  Future<void> _loadAudio() async {
    setState(() => _loading = true);
    final all = await HuntingDataService.getAllSignals();
    final seen = <String>{};
    final withAudio = <HuntingSignal>[];
    for (final s in all) {
      final url = s.audioUrl;
      if (url != null && url.isNotEmpty && seen.add(url)) {
        final diff = widget.session.audioDifficulty;
        if (diff == null || s.difficulty == diff) withAudio.add(s);
      }
    }
    withAudio.shuffle(Random());
    final picked = withAudio.take(widget.session.audioQuestionCount).toList();
    final allNames = withAudio.map((s) => s.name).toList();
    final rng = Random();
    _audioQ = picked.map((s) {
      final wrongs = (List<String>.from(allNames)..remove(s.name))..shuffle(rng);
      final opts = [s.name, ...wrongs.take(3)]..shuffle(rng);
      return _AQ(url: s.audioUrl!, name: s.name,
          options: opts, correctIndex: opts.indexOf(s.name));
    }).toList();
    setState(() { _loading = false; _step = _ExamStep.audio; });
    if (_audioQ.isNotEmpty) _startTimer();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timeLeft.value = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      _timeLeft.value--;
      if (_timeLeft.value <= 0) {
        t.cancel();
        if (!_audioAnswered) {
          _audioAnswers.add(null);
          _audio.stop();
          _audioNextOrFinish();
        }
      }
    });
  }

  // ── Theory logic ──────────────────────────────────────────────────────────

  void _theorySelect(int idx) {
    if (_theoryAnswered) return;
    if (_theoryQ[_theoryIdx].correctIndex == idx) _theoryCorrect++;
    _theoryAnswers.add(idx);
    setState(() { _theorySelected = idx; _theoryAnswered = true; });
  }

  void _theoryNext() {
    if (_theoryIdx < _theoryQ.length - 1) {
      setState(() {
        _theoryIdx++;
        _theorySelected = null;
        _theoryAnswered = false;
      });
    } else {
      _afterTheory();
    }
  }

  void _afterTheory() {
    if (widget.session.audioEnabled) {
      _loadAudio();
    } else if (widget.session.fileEnabled) {
      setState(() => _step = _ExamStep.file);
    } else {
      _submit();
    }
  }

  // ── Audio logic ───────────────────────────────────────────────────────────

  Future<void> _playAudio() async {
    _audioState.value = (loading: true, playing: false);
    try {
      await _audio.stop();
      await _audio.play(UrlSource(_audioQ[_audioIdx].url));
      if (mounted) _audioState.value = (loading: false, playing: true);
    } catch (_) {
      if (mounted) _audioState.value = (loading: false, playing: false);
    }
  }

  void _audioSelect(int idx) {
    if (_audioAnswered) return;
    _timer?.cancel();
    _audio.stop();
    if (_audioQ[_audioIdx].correctIndex == idx) _audioCorrect++;
    _audioAnswers.add(idx);
    setState(() { _audioSelected = idx; _audioAnswered = true; });
  }

  void _audioNextOrFinish() {
    _audio.stop();
    if (_audioIdx < _audioQ.length - 1) {
      setState(() {
        _audioIdx++;
        _audioSelected = null;
        _audioAnswered = false;
        _audioState.value = (loading: false, playing: false);
      });
      _startTimer();
    } else {
      _afterAudio();
    }
  }

  void _afterAudio() {
    _timer?.cancel();
    if (widget.session.fileEnabled) {
      setState(() => _step = _ExamStep.file);
    } else {
      _submit();
    }
  }

  // ── File logic ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'odt'],
      // withData обовʼязковий для вебу: там path завжди null, файл приходить у bytes
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedFile = result.files.single.bytes;
        _pickedFileName = result.files.single.name;
      });
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() { _step = _ExamStep.submitting; _uploading = true; });
    final s = widget.session;
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    // Upload file if any
    String? fileUrl;
    if (_pickedFile != null) {
      fileUrl = await ExamService.uploadFile(
          s.id, id, _pickedFile!, _pickedFileName ?? 'submission');
    }

    final theoryAuto = ExamService.scaleScore(
        _theoryCorrect, _theoryQ.length, s.theoryMaxPoints);
    final audioAuto  = ExamService.scaleScore(
        _audioCorrect,  _audioQ.length,  s.audioMaxPoints);

    final sub = ExamSubmission(
      id: id,
      sessionId:   s.id,
      sessionCode: s.code,
      studentName: widget.studentName,
      submittedAt: DateTime.now(),
      theoryCorrect: _theoryCorrect,
      theoryTotal:   _theoryQ.length,
      theoryAutoPoints: theoryAuto,
      audioCorrect: _audioCorrect,
      audioTotal:   _audioQ.length,
      audioAutoPoints: audioAuto,
      fileUrl:  fileUrl,
      fileName: _pickedFileName,
      status: 'pending',
    );

    await ExamService.saveSubmission(sub);
    if (mounted) setState(() { _submission = sub; _step = _ExamStep.done; _uploading = false; });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _ExamStep.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step != _ExamStep.done) {
          _confirmExit(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF0E6),
        appBar: AppBar(
          title: Text(widget.session.title, overflow: TextOverflow.ellipsis),
          backgroundColor: _darkGreen,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: _step == _ExamStep.done,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : switch (_step) {
                _ExamStep.intro      => _buildIntro(),
                _ExamStep.theory     => _buildTheory(),
                _ExamStep.audio      => _buildAudio(),
                _ExamStep.file       => _buildFile(),
                _ExamStep.submitting => _buildSubmitting(),
                _ExamStep.done       => _buildDone(),
              },
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Вийти з іспиту?'),
        content: const Text('Прогрес буде втрачено. Ви впевнені?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Залишитись')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Вийти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) Navigator.pop(context);
  }

  // ── Intro ─────────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    final s = widget.session;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8,
                offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.school_rounded, color: _darkGreen, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(s.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: _darkGreen))),
            ]),
            const Divider(height: 24),
            _InfoRow(Icons.person_rounded, 'Студент', widget.studentName),
            _InfoRow(Icons.tag_rounded, 'Код сесії', s.code),
            if (s.deadline != null)
              _InfoRow(Icons.timer_outlined, 'Дедлайн',
                  _formatDate(s.deadline!)),
            _InfoRow(Icons.check_circle_outline_rounded, 'Прохідний бал',
                '${s.passingScore} балів'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Складові іспиту',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.black54)),
            const SizedBox(height: 8),
            if (s.theoryEnabled) _ComponentRow(
                Icons.menu_book_rounded, 'Теоретичний тест',
                '${s.theoryMaxPoints} балів · ${s.theoryQuestionCount} питань',
                Colors.blue),
            if (s.audioEnabled) _ComponentRow(
                Icons.headphones_rounded, 'Аудіо тест',
                '${s.audioMaxPoints} балів · ${s.audioQuestionCount} сигналів',
                Colors.purple),
            if (s.fileEnabled) _ComponentRow(
                Icons.upload_file_rounded, 'Файлове завдання',
                '${s.fileMaxPoints} балів · ручна перевірка',
                Colors.orange),
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Максимум балів',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${s.totalMaxPoints}',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 18, color: _darkGreen)),
            ]),
          ]),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: s.theoryEnabled ? _loadTheory
                : s.audioEnabled ? _loadAudio
                : s.fileEnabled ? () => setState(() => _step = _ExamStep.file)
                : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Розпочати іспит',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── Theory ────────────────────────────────────────────────────────────────
  Widget _buildTheory() {
    if (_theoryQ.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        const Text('Питання для цієї теми не знайдено',
            style: TextStyle(fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _afterTheory,
          style: ElevatedButton.styleFrom(backgroundColor: _darkGreen,
              foregroundColor: Colors.white),
          child: const Text('Пропустити'),
        ),
      ]));
    }
    final q = _theoryQ[_theoryIdx];
    return Column(children: [
      _ProgressHeader('Теоретичний тест',
          _theoryIdx + 1, _theoryQ.length, Icons.menu_book_rounded),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withValues(alpha: 0.4)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6,
                    offset: const Offset(0, 3))],
              ),
              child: Text(q.question,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      height: 1.4)),
            ),
            const SizedBox(height: 16),
            ...q.options.asMap().entries.map((e) => _AnswerTile(
              label: String.fromCharCode(65 + e.key),
              text: e.value,
              answered: _theoryAnswered,
              selected: _theorySelected == e.key,
              correct: q.correctIndex == e.key,
              onTap: () => _theorySelect(e.key),
            )),
            if (_theoryAnswered) ...[
              if (q.explanation?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(q.explanation!,
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              _NextBtn(
                label: _theoryIdx < _theoryQ.length - 1
                    ? 'Наступне питання →'
                    : 'Завершити тест →',
                onTap: _theoryNext,
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  // ── Audio ─────────────────────────────────────────────────────────────────
  Widget _buildAudio() {
    if (_audioQ.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.music_off_rounded, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        const Text('Немає аудіо сигналів для тесту'),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _afterAudio,
          style: ElevatedButton.styleFrom(backgroundColor: _darkGreen,
              foregroundColor: Colors.white),
          child: const Text('Пропустити'),
        ),
      ]));
    }
    final q = _audioQ[_audioIdx];
    return Column(children: [
      _ProgressHeader('Аудіо тест',
          _audioIdx + 1, _audioQ.length, Icons.headphones_rounded,
          timerNotifier: _timeLeft),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Audio player
            ValueListenableBuilder(
              valueListenable: _audioState,
              builder: (_, audio, __) => GestureDetector(
                onTap: audio.loading ? null
                    : audio.playing
                        ? () { _audio.stop(); }
                        : _playAudio,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A0F00), Color(0xFF3E2008)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _gold.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(children: [
                    const Text('🎺  Прослухайте сигнал',
                        style: TextStyle(color: Color(0xFFFFD966),
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2D5A1B),
                        border: Border.all(color: _gold, width: 2),
                      ),
                      child: audio.loading
                          ? const Padding(padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                  color: _gold, strokeWidth: 2.5))
                          : Icon(
                              audio.playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                              color: const Color(0xFFFFD966), size: 40),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      audio.playing ? 'Грає...' : 'Натисніть для прослуховування',
                      style: TextStyle(
                          color: audio.playing ? _gold : Colors.white54,
                          fontSize: 12),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Оберіть назву сигналу:',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700],
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
            ...q.options.asMap().entries.map((e) => _AnswerTile(
              label: String.fromCharCode(65 + e.key),
              text: e.value,
              answered: _audioAnswered,
              selected: _audioSelected == e.key,
              correct: q.correctIndex == e.key,
              onTap: () => _audioSelect(e.key),
            )),
            if (_audioAnswered) ...[
              const SizedBox(height: 14),
              _NextBtn(
                label: _audioIdx < _audioQ.length - 1
                    ? 'Наступний сигнал →'
                    : 'Завершити аудіо тест →',
                onTap: _audioNextOrFinish,
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  // ── File ──────────────────────────────────────────────────────────────────
  Widget _buildFile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.assignment_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text('Завдання', style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: Colors.orange[800])),
            ]),
            const SizedBox(height: 8),
            Text(widget.session.fileTaskDescription.isNotEmpty
                ? widget.session.fileTaskDescription
                : 'Прикріпіть файл з виконаним завданням.',
                style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 6),
            Text('Максимум: ${widget.session.fileMaxPoints} балів',
                style: TextStyle(fontSize: 12, color: Colors.orange[700],
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Прикріпити файл',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Дозволені формати: PDF, DOC, DOCX, TXT, ODT',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _pickedFile != null ? _darkGreen : Colors.grey[300]!,
                  width: _pickedFile != null ? 2 : 1.5,
                  style: _pickedFile != null ? BorderStyle.solid : BorderStyle.solid),
            ),
            child: Column(children: [
              Icon(
                _pickedFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                size: 40,
                color: _pickedFile != null ? _darkGreen : Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                _pickedFileName ?? 'Натисніть щоб вибрати файл',
                style: TextStyle(
                  fontSize: 14,
                  color: _pickedFile != null ? _darkGreen : Colors.grey[500],
                  fontWeight: _pickedFile != null ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              if (_pickedFile != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => setState(() {
                    _pickedFile = null; _pickedFileName = null;
                  }),
                  child: const Text('Вибрати інший файл',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _uploading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _pickedFile != null ? 'Здати іспит →' : 'Здати без файлу →',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_pickedFile == null) ...[
          const SizedBox(height: 8),
          Center(child: Text('Файл необов\'язковий',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
        ],
      ]),
    );
  }

  Widget _buildSubmitting() => const Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(color: _darkGreen),
      SizedBox(height: 16),
      Text('Надсилання результатів...', style: TextStyle(fontSize: 15)),
    ],
  ));

  // ── Done ──────────────────────────────────────────────────────────────────
  Widget _buildDone() {
    final sub = _submission!;
    final s   = widget.session;
    final auto = sub.theoryAutoPoints + sub.audioAutoPoints;
    final max  = s.theoryMaxPoints + s.audioMaxPoints;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(context).padding.bottom + 24),
      child: Column(children: [
        Container(
          width: 90, height: 90,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 52, color: Colors.green),
        ),
        const SizedBox(height: 16),
        const Text('Іспит здано!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: _darkGreen)),
        const SizedBox(height: 8),
        Text('Дякуємо, ${widget.studentName}!',
            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8,
                offset: const Offset(0, 3))],
          ),
          child: Column(children: [
            if (s.theoryEnabled) _ScoreRow('Теоретичний тест',
                sub.theoryCorrect, sub.theoryTotal, sub.theoryAutoPoints,
                s.theoryMaxPoints, Icons.menu_book_rounded, Colors.blue),
            if (s.audioEnabled) _ScoreRow('Аудіо тест',
                sub.audioCorrect, sub.audioTotal, sub.audioAutoPoints,
                s.audioMaxPoints, Icons.headphones_rounded, Colors.purple),
            if (s.fileEnabled) ...[
              const Divider(height: 20),
              Row(children: [
                const Icon(Icons.upload_file_rounded,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Файлове завдання',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(sub.fileName != null
                      ? 'Файл: ${sub.fileName}'
                      : 'Файл не прикріплено',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Очікує перевірки',
                      style: TextStyle(fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Автоматична оцінка',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('$auto / $max балів',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 16, color: _darkGreen)),
            ]),
            if (s.fileEnabled) ...[
              const SizedBox(height: 4),
              Text('Фінальна оцінка буде виставлена після перевірки файлу',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  textAlign: TextAlign.center),
            ],
          ]),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // pop ExamTakingScreen
              Navigator.pop(context); // pop ExamEntryScreen
            },
            icon: const Icon(Icons.home_rounded),
            label: const Text('На головну'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Audio question model ──────────────────────────────────────────────────────
class _AQ {
  final String url, name;
  final List<String> options;
  final int correctIndex;
  const _AQ({required this.url, required this.name,
      required this.options, required this.correctIndex});
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final String title;
  final int current, total;
  final IconData icon;
  final ValueNotifier<int>? timerNotifier;

  const _ProgressHeader(this.title, this.current, this.total, this.icon,
      {this.timerNotifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _darkGreen,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(children: [
        Icon(icon, color: _gold, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: current / total,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                minHeight: 5,
              ),
            )),
            const SizedBox(width: 10),
            Text('$current / $total',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ])),
        if (timerNotifier != null) ...[
          const SizedBox(width: 12),
          ValueListenableBuilder<int>(
            valueListenable: timerNotifier!,
            builder: (_, t, __) => Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: t <= 10
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(
                    color: t <= 10 ? Colors.red : _gold, width: 2),
              ),
              child: Center(child: Text('$t',
                  style: TextStyle(
                      color: t <= 10 ? Colors.red : _gold,
                      fontWeight: FontWeight.bold, fontSize: 14))),
            ),
          ),
        ],
      ]),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String label, text;
  final bool answered, selected, correct;
  final VoidCallback onTap;

  const _AnswerTile({required this.label, required this.text,
      required this.answered, required this.selected,
      required this.correct, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white, border = Colors.grey[300]!;
    Color lblBg = Colors.grey[200]!, lblFg = Colors.grey[700]!;
    if (answered) {
      if (correct) { bg = Colors.green[50]!; border = Colors.green[400]!;
        lblBg = Colors.green[400]!; lblFg = Colors.white; }
      else if (selected) { bg = Colors.red[50]!; border = Colors.red[400]!;
        lblBg = Colors.red[400]!; lblFg = Colors.white; }
    } else if (selected) { bg = const Color(0xFFFFF8E7); border = _gold; }

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.5)),
        child: Row(children: [
          Container(width: 30, height: 30,
              decoration: BoxDecoration(color: lblBg, shape: BoxShape.circle),
              child: Center(child: Text(label,
                  style: TextStyle(color: lblFg,
                      fontWeight: FontWeight.bold, fontSize: 14)))),
          const SizedBox(width: 12),
          Expanded(child: Text(text,
              style: const TextStyle(fontSize: 15, color: Colors.black87))),
          if (answered && correct)
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          if (answered && selected && !correct)
            const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
        ]),
      ),
    );
  }
}

class _NextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NextBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkGreen, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15)),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey[600]),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _ComponentRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _ComponentRow(this.icon, this.title, this.subtitle, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(title, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ])),
    ]),
  );
}

class _ScoreRow extends StatelessWidget {
  final String title;
  final int correct, total, autoPoints, maxPoints;
  final IconData icon;
  final Color color;
  const _ScoreRow(this.title, this.correct, this.total,
      this.autoPoints, this.maxPoints, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(title, style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13)),
        Text('$correct правильних з $total',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ])),
      Text('$autoPoints / $maxPoints',
          style: TextStyle(fontWeight: FontWeight.bold,
              fontSize: 14, color: color)),
    ]),
  );
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
