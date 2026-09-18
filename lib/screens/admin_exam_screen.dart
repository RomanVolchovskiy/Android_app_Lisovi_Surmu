import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/models/exam_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/services/exam_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _darkGreen = Color(0xFF1C3A1C);
const _gold      = Color(0xFFD4A017);

class AdminExamScreen extends StatefulWidget {
  const AdminExamScreen({super.key});

  @override
  State<AdminExamScreen> createState() => _AdminExamScreenState();
}

class _AdminExamScreenState extends State<AdminExamScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<ExamSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _sessions = await ExamService.getAllSessions();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: const Text('Управління іспитами'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _gold,
          labelColor: _gold,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'Сесії'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Результати'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Створити сесію',
            onPressed: _createSession,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _SessionList(
                  sessions: _sessions,
                  onRefresh: _load,
                  onCreate: _createSession,
                  onChangeStatus: _changeStatus,
                  onDelete: _deleteSession,
                ),
                _ResultsTab(sessions: _sessions),
              ],
            ),
    );
  }

  Future<void> _createSession() async {
    final result = await Navigator.push<ExamSession>(context,
        MaterialPageRoute(builder: (_) => const _CreateSessionScreen()));
    if (result != null) {
      final ok = await ExamService.saveSession(result);
      if (!mounted) return;
      if (ok) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сесію "${result.title}" створено. Код: ${result.code}'),
              backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _changeStatus(ExamSession s, String newStatus) async {
    await ExamService.updateSessionStatus(s.id, newStatus);
    _load();
  }

  Future<void> _deleteSession(ExamSession s) async {
    final confirm = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text('Видалити сесію?'),
          content: Text('Сесія "${s.title}" буде видалена.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Скасувати')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Видалити', style: TextStyle(color: Colors.white)),
            ),
          ],
        ));
    if (confirm == true) { await ExamService.deleteSession(s.id); _load(); }
  }
}

// ── Список сесій ─────────────────────────────────────────────────────────────
class _SessionList extends StatelessWidget {
  final List<ExamSession> sessions;
  final VoidCallback onRefresh, onCreate;
  final Future<void> Function(ExamSession, String) onChangeStatus;
  final Future<void> Function(ExamSession) onDelete;

  const _SessionList({
    required this.sessions, required this.onRefresh,
    required this.onCreate, required this.onChangeStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Icon(Icons.event_note_rounded, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text('Сесії відсутні', style: TextStyle(
            color: Colors.grey[600], fontSize: 15)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Створити першу сесію'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, i) => _SessionCard(
        session: sessions[i],
        onChangeStatus: onChangeStatus,
        onDelete: onDelete,
        onTapResults: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _SessionResultsScreen(session: sessions[i]),
        )),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ExamSession session;
  final Future<void> Function(ExamSession, String) onChangeStatus;
  final Future<void> Function(ExamSession) onDelete;
  final VoidCallback onTapResults;

  const _SessionCard({required this.session, required this.onChangeStatus,
      required this.onDelete, required this.onTapResults});

  static const _statusColors = {
    'draft':  Color(0xFF9E9E9E),
    'active': Color(0xFF2E7D32),
    'closed': Color(0xFFC62828),
  };
  static const _statusLabels = {
    'draft':  'Чернетка',
    'active': 'Активна',
    'closed': 'Закрита',
  };

  @override
  Widget build(BuildContext context) {
    final s = session;
    final color = _statusColors[s.status] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text(_statusLabels[s.status] ?? s.status,
                  style: TextStyle(fontSize: 11, color: color,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 6),
          // Код
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _darkGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(s.code,
                  style: const TextStyle(color: _gold,
                      fontWeight: FontWeight.bold, fontSize: 16,
                      letterSpacing: 4)),
            ),
            const SizedBox(width: 10),
            Text('${s.totalMaxPoints} балів',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (s.deadline != null) ...[
              const SizedBox(width: 10),
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text(_formatDate(s.deadline!),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ]),
          const SizedBox(height: 8),
          // Components
          Wrap(spacing: 6, children: [
            if (s.theoryEnabled) _Chip(
                Icons.menu_book_rounded, '${s.theoryMaxPoints} теорія', Colors.blue),
            if (s.audioEnabled) _Chip(
                Icons.headphones_rounded, '${s.audioMaxPoints} аудіо', Colors.purple),
            if (s.fileEnabled) _Chip(
                Icons.upload_file_rounded, '${s.fileMaxPoints} файл', Colors.orange),
          ]),
          const Divider(height: 16),
          Row(children: [
            // Змінити статус
            if (s.status == 'draft') _ActionBtn(
                Icons.play_arrow_rounded, 'Активувати', Colors.green,
                () => onChangeStatus(s, 'active')),
            if (s.status == 'active') _ActionBtn(
                Icons.lock_rounded, 'Закрити', Colors.orange,
                () => onChangeStatus(s, 'closed')),
            if (s.status == 'closed') _ActionBtn(
                Icons.lock_open_rounded, 'Відкрити', Colors.green,
                () => onChangeStatus(s, 'active')),
            const Spacer(),
            _ActionBtn(Icons.bar_chart_rounded, 'Результати', _darkGreen,
                onTapResults),
            const SizedBox(width: 4),
            _ActionBtn(Icons.delete_outline_rounded, 'Видалити', Colors.red,
                () => onDelete(s)),
          ]),
        ]),
      ),
    );
  }
}

// ── Вкладка результатів (загальна) ───────────────────────────────────────────
class _ResultsTab extends StatelessWidget {
  final List<ExamSession> sessions;
  const _ResultsTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final hasSessions = sessions.isNotEmpty;
    if (!hasSessions) {
      return Center(child: Text('Ще немає сесій',
          style: TextStyle(color: Colors.grey[600])));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.event_note_rounded, color: _darkGreen),
        title: Text(sessions[i].title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Код: ${sessions[i].code}'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _SessionResultsScreen(session: sessions[i]),
        )),
      ),
    );
  }
}

// ── Результати конкретної сесії ───────────────────────────────────────────────
class _SessionResultsScreen extends StatefulWidget {
  final ExamSession session;
  const _SessionResultsScreen({required this.session});

  @override
  State<_SessionResultsScreen> createState() => _SessionResultsScreenState();
}

class _SessionResultsScreenState extends State<_SessionResultsScreen> {
  List<ExamSubmission> _subs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _subs = await ExamService.getSubmissionsBySession(widget.session.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: Text(widget.session.title, overflow: TextOverflow.ellipsis),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subs.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.people_outline_rounded, size: 56,
                    color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('Ніхто ще не здав цю сесію',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15)),
              ]))
              : Column(children: [
                  _SummaryBar(session: widget.session, subs: _subs),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subs.length,
                      itemBuilder: (_, i) => _SubmissionCard(
                        sub: _subs[i],
                        session: widget.session,
                        onGrade: () => _gradeDialog(_subs[i]),
                      ),
                    ),
                  ),
                ]),
    );
  }

  Future<void> _gradeDialog(ExamSubmission sub) async {
    final s = widget.session;
    final theoryCtrl = TextEditingController(
        text: sub.adminTheoryPoints?.toString() ??
              sub.theoryAutoPoints.toString());
    final audioCtrl  = TextEditingController(
        text: sub.adminAudioPoints?.toString() ??
              sub.audioAutoPoints.toString());
    final fileCtrl   = TextEditingController(
        text: sub.adminFilePoints?.toString() ?? '');
    final noteCtrl   = TextEditingController(text: sub.adminNote ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Оцінка: ${sub.studentName}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (s.theoryEnabled) ...[
              Text('Теорія (авто: ${sub.theoryAutoPoints} / ${s.theoryMaxPoints})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              TextField(
                controller: theoryCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Балів за теорію (макс ${s.theoryMaxPoints})',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (s.audioEnabled) ...[
              Text('Аудіо (авто: ${sub.audioAutoPoints} / ${s.audioMaxPoints})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              TextField(
                controller: audioCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Балів за аудіо (макс ${s.audioMaxPoints})',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (s.fileEnabled) ...[
              if (sub.fileUrl != null)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(sub.fileUrl!)),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(sub.fileName ?? 'Відкрити файл',
                      style: const TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 4),
              TextField(
                controller: fileCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Балів за файл (макс ${s.fileMaxPoints})',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Коментар (необов\'язково)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () async {
              final updated = sub.copyWith(
                adminTheoryPoints: int.tryParse(theoryCtrl.text.trim()),
                adminAudioPoints:  int.tryParse(audioCtrl.text.trim()),
                adminFilePoints:   int.tryParse(fileCtrl.text.trim()),
                adminNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                status: 'graded',
              );
              await ExamService.updateGrade(updated);
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _darkGreen),
            child: const Text('Зберегти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final ExamSession session;
  final List<ExamSubmission> subs;
  const _SummaryBar({required this.session, required this.subs});

  @override
  Widget build(BuildContext context) {
    final graded = subs.where((s) => s.isGraded).length;
    final avg = subs.isEmpty ? 0
        : (subs.fold(0, (s, sub) => s + sub.totalPoints) / subs.length).round();
    return Container(
      color: _darkGreen,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        _StatBox('${subs.length}', 'Здали'),
        const SizedBox(width: 24),
        _StatBox('$graded', 'Перевірено'),
        const SizedBox(width: 24),
        _StatBox('$avg', 'Середній бал'),
        const Spacer(),
        Text('/ ${session.totalMaxPoints}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  const _StatBox(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: const TextStyle(color: _gold,
          fontWeight: FontWeight.bold, fontSize: 20)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ],
  );
}

class _SubmissionCard extends StatelessWidget {
  final ExamSubmission sub;
  final ExamSession session;
  final VoidCallback onGrade;
  const _SubmissionCard({required this.sub, required this.session,
      required this.onGrade});

  @override
  Widget build(BuildContext context) {
    final total = sub.totalPoints;
    final max   = session.totalMaxPoints;
    final passed = total >= session.passingScore;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(sub.studentName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold))),
            if (sub.isGraded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: passed
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: passed ? Colors.green[300]! : Colors.red[300]!),
                ),
                child: Text(passed ? 'Зараховано' : 'Не зараховано',
                    style: TextStyle(
                        fontSize: 11,
                        color: passed ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Очікує',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700])),
              ),
          ]),
          const SizedBox(height: 6),
          Text(_formatDate(sub.submittedAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Row(children: [
            if (session.theoryEnabled) _MiniScore(
                'Теорія', sub.theoryPoints, session.theoryMaxPoints,
                Colors.blue, sub.adminTheoryPoints != null),
            if (session.audioEnabled) _MiniScore(
                'Аудіо', sub.audioPoints, session.audioMaxPoints,
                Colors.purple, sub.adminAudioPoints != null),
            if (session.fileEnabled) _MiniScore(
                'Файл', sub.filePoints, session.fileMaxPoints,
                Colors.orange, sub.adminFilePoints != null),
            const Spacer(),
            Text('$total / $max',
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold, color: _darkGreen)),
          ]),
          if (sub.fileName != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: sub.fileUrl != null
                  ? () => launchUrl(Uri.parse(sub.fileUrl!))
                  : null,
              icon: const Icon(Icons.attach_file_rounded, size: 14),
              label: Text(sub.fileName!,
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
          if (sub.adminNote != null) ...[
            const SizedBox(height: 4),
            Text('Коментар: ${sub.adminNote}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600],
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGrade,
              icon: const Icon(Icons.rate_review_rounded, size: 16),
              label: Text(sub.isGraded ? 'Редагувати оцінку' : 'Виставити оцінку',
                  style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkGreen,
                side: const BorderSide(color: _darkGreen),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final int points, max;
  final Color color;
  final bool isManual;
  const _MiniScore(this.label, this.points, this.max,
      this.color, this.isManual);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      Row(children: [
        Text('$points/$max',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: color)),
        if (isManual) ...[
          const SizedBox(width: 2),
          Icon(Icons.edit_rounded, size: 10, color: color.withValues(alpha: 0.6)),
        ],
      ]),
    ]),
  );
}

// ── Створення сесії ───────────────────────────────────────────────────────────
class _CreateSessionScreen extends StatefulWidget {
  const _CreateSessionScreen();

  @override
  State<_CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<_CreateSessionScreen> {
  final _titleCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController(text: '60');
  bool _hasDeadline   = false;
  DateTime _deadline  = DateTime.now().add(const Duration(days: 7));

  bool _theoryEnabled = false;
  List<EducationTopic> _topics = [];
  String? _theoryTopicId;
  String? _theoryTopicName;
  final _theoryMaxCtrl  = TextEditingController(text: '40');
  final _theoryCountCtrl = TextEditingController(text: '10');

  bool _audioEnabled = false;
  String? _audioDifficulty;
  final _audioMaxCtrl   = TextEditingController(text: '30');
  final _audioCountCtrl = TextEditingController(text: '10');

  bool _fileEnabled = false;
  final _fileMaxCtrl  = TextEditingController(text: '30');
  final _fileDescCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    EducationService.getTopics().then((t) {
      if (mounted) setState(() => _topics = t);
    });
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _passCtrl, _theoryMaxCtrl, _theoryCountCtrl,
        _audioMaxCtrl, _audioCountCtrl, _fileMaxCtrl, _fileDescCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalMax =>
      (_theoryEnabled ? (int.tryParse(_theoryMaxCtrl.text) ?? 0) : 0) +
      (_audioEnabled  ? (int.tryParse(_audioMaxCtrl.text)  ?? 0) : 0) +
      (_fileEnabled   ? (int.tryParse(_fileMaxCtrl.text)   ?? 0) : 0);

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введіть назву сесії')));
      return;
    }
    if (!_theoryEnabled && !_audioEnabled && !_fileEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оберіть хоча б одну складову')));
      return;
    }
    if (_theoryEnabled && _theoryTopicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оберіть тему для теоретичного тесту')));
      return;
    }

    final session = ExamSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      code: ExamService.generateCode(),
      title: _titleCtrl.text.trim(),
      createdAt: DateTime.now(),
      deadline: _hasDeadline ? _deadline : null,
      status: 'draft',
      passingScore: int.tryParse(_passCtrl.text) ?? 60,
      theoryEnabled: _theoryEnabled,
      theoryTopicId: _theoryTopicId,
      theoryTopicName: _theoryTopicName,
      theoryMaxPoints: int.tryParse(_theoryMaxCtrl.text) ?? 0,
      theoryQuestionCount: int.tryParse(_theoryCountCtrl.text) ?? 10,
      audioEnabled: _audioEnabled,
      audioDifficulty: _audioDifficulty,
      audioMaxPoints: int.tryParse(_audioMaxCtrl.text) ?? 0,
      audioQuestionCount: int.tryParse(_audioCountCtrl.text) ?? 10,
      fileEnabled: _fileEnabled,
      fileMaxPoints: int.tryParse(_fileMaxCtrl.text) ?? 0,
      fileTaskDescription: _fileDescCtrl.text.trim(),
    );
    Navigator.pop(context, session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: const Text('Нова сесія іспиту'),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Зберегти',
                style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section('Основне'),
          _Field(_titleCtrl, 'Назва сесії', icon: Icons.title_rounded),
          const SizedBox(height: 12),
          _Field(_passCtrl, 'Прохідний бал',
              icon: Icons.check_circle_outline_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Дедлайн здачі'),
            subtitle: _hasDeadline
                ? Text(_formatDate(_deadline),
                    style: const TextStyle(fontSize: 12))
                : null,
            value: _hasDeadline,
            activeColor: _darkGreen,
            onChanged: (v) async {
              if (v) {
                final picked = await showDateTimePicker(context, _deadline);
                if (picked != null) setState(() { _hasDeadline = true; _deadline = picked; });
              } else {
                setState(() => _hasDeadline = false);
              }
            },
          ),

          const SizedBox(height: 8),
          _Section('Складові іспиту (загалом: $_totalMax балів)'),

          // Theory
          _ComponentToggle(
            icon: Icons.menu_book_rounded,
            title: 'Теоретичний тест',
            color: Colors.blue,
            enabled: _theoryEnabled,
            onToggle: (v) => setState(() => _theoryEnabled = v),
            children: [
              DropdownButtonFormField<String>(
                value: _theoryTopicId,
                decoration: const InputDecoration(
                    labelText: 'Тема', border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
                items: _topics.map((t) => DropdownMenuItem(
                    value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) {
                  final t = _topics.firstWhere((t) => t.id == v);
                  setState(() { _theoryTopicId = v; _theoryTopicName = t.name; });
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _Field(_theoryMaxCtrl, 'Макс балів',
                    keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(_theoryCountCtrl, 'К-сть питань',
                    keyboardType: TextInputType.number)),
              ]),
            ],
          ),

          // Audio
          _ComponentToggle(
            icon: Icons.headphones_rounded,
            title: 'Аудіо тест сигналів',
            color: Colors.purple,
            enabled: _audioEnabled,
            onToggle: (v) => setState(() => _audioEnabled = v),
            children: [
              DropdownButtonFormField<String?>(
                value: _audioDifficulty,
                decoration: const InputDecoration(
                    labelText: 'Рівень складності',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Усі рівні')),
                  DropdownMenuItem(value: 'easy',   child: Text('🟢 Легкий')),
                  DropdownMenuItem(value: 'medium', child: Text('🟡 Середній')),
                  DropdownMenuItem(value: 'hard',   child: Text('🔴 Важкий')),
                ],
                onChanged: (v) => setState(() => _audioDifficulty = v),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _Field(_audioMaxCtrl, 'Макс балів',
                    keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(_audioCountCtrl, 'К-сть сигналів',
                    keyboardType: TextInputType.number)),
              ]),
            ],
          ),

          // File
          _ComponentToggle(
            icon: Icons.upload_file_rounded,
            title: 'Файлове завдання',
            color: Colors.orange,
            enabled: _fileEnabled,
            onToggle: (v) => setState(() => _fileEnabled = v),
            children: [
              _Field(_fileMaxCtrl, 'Макс балів',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(
                controller: _fileDescCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Опис завдання',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Створити сесію',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Future<DateTime?> showDateTimePicker(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context,
      initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: _darkGreen)),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  const _Field(this.ctrl, this.label, {this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true, fillColor: Colors.white,
    ),
  );
}

class _ComponentToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  const _ComponentToggle({
    required this.icon, required this.title, required this.color,
    required this.enabled, required this.onToggle, required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: enabled ? color.withValues(alpha: 0.5) : Colors.grey[300]!),
    ),
    child: Column(children: [
      SwitchListTile(
        secondary: Icon(icon, color: enabled ? color : Colors.grey),
        title: Text(title, style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.black87 : Colors.grey)),
        value: enabled,
        activeColor: color,
        onChanged: onToggle,
      ),
      if (enabled) ...[
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      ],
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16, color: color),
    label: Text(label, style: TextStyle(fontSize: 12, color: color)),
    style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
