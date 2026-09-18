import 'dart:convert';
import 'dart:io' if (dart.library.html) 'package:hunting_signals/stubs/dart_io_stub.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/services/media_cache_service.dart';
import 'package:hunting_signals/services/study_plan_service.dart';
import 'package:hunting_signals/services/practical_service.dart';
import 'package:hunting_signals/screens/level_thematic_screen.dart';

class AdminEducationScreen extends StatefulWidget {
  const AdminEducationScreen({super.key});

  @override
  State<AdminEducationScreen> createState() => _AdminEducationScreenState();
}

class _AdminEducationScreenState extends State<AdminEducationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<EducationTopic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управління навчанням'),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.topic_rounded, size: 18), text: 'Теми'),
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Матеріали'),
            Tab(icon: Icon(Icons.style_rounded, size: 18), text: 'Флеш-картки'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: 'Тести'),
            Tab(icon: Icon(Icons.checklist_rounded, size: 18), text: 'План'),
            Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'Практичні'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _TopicsTab(topics: _topics, onChanged: _loadTopics),
                _MaterialsTab(topics: _topics),
                _FlashcardsTab(topics: _topics),
                _TestQuestionsTab(topics: _topics),
                _AdminStudyPlanTab(topics: _topics),
                const _AdminPracticalTab(),
              ],
            ),
    );
  }
}

// ── Загальна inline-форма ─────────────────────────────────────────────────────
class _InlineForm extends StatelessWidget {
  final String title;
  final List<Widget> fields;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _InlineForm({
    required this.title,
    required this.fields,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.brown[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.brown[800])),
            const SizedBox(height: 12),
            ...fields,
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown[700],
                      side: BorderSide(color: Colors.brown[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Скасувати'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Зберегти'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDec(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  isDense: true,
);

// ── Вкладка «Теми» ─────────────────────────────────────────────────────────────
class _TopicsTab extends StatefulWidget {
  final List<EducationTopic> topics;
  final VoidCallback onChanged;
  const _TopicsTab({required this.topics, required this.onChanged});

  @override
  State<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicsTabState extends State<_TopicsTab> {
  late List<EducationTopic> _topics;
  bool _showForm = false;
  EducationTopic? _editing;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _topics = List.from(widget.topics);
  }

  @override
  void didUpdateWidget(_TopicsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topics != oldWidget.topics) {
      _topics = List.from(widget.topics);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final t = _topics.removeAt(oldIndex);
      _topics.insert(newIndex, t);
    });
    EducationService.reorderTopics(List.from(_topics));
  }

  void _startAdd() => setState(() {
    _showForm = true; _editing = null;
    _nameCtrl.clear(); _descCtrl.clear();
  });

  void _startEdit(EducationTopic t) => setState(() {
    _showForm = true; _editing = t;
    _nameCtrl.text = t.name; _descCtrl.text = t.description;
  });

  void _cancel() => setState(() { _showForm = false; _editing = null; });

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final t = EducationTopic(
      id: _editing?.id ?? 'topic_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
    );
    await EducationService.saveTopic(t);
    setState(() { _showForm = false; _editing = null; });
    widget.onChanged();
  }

  Future<void> _delete(EducationTopic t) async {
    final ok = await _confirmDelete(context, 'тему "${t.name}"');
    if (ok) { await EducationService.deleteTopic(t.id); widget.onChanged(); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_showForm)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startAdd,
                icon: const Icon(Icons.add),
                label: const Text('Додати тему'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        if (_showForm)
          _InlineForm(
            title: _editing == null ? 'Нова тема' : 'Редагувати тему',
            onSave: _save,
            onCancel: _cancel,
            fields: [
              TextField(controller: _nameCtrl, decoration: _inputDec('Назва теми *')),
              const SizedBox(height: 10),
              TextField(controller: _descCtrl, decoration: _inputDec('Опис'), maxLines: 2),
            ],
          ),
        Expanded(
          child: _topics.isEmpty
              ? const Center(child: Text('Немає тем. Додайте першу.'))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: _topics.length,
                  onReorder: _onReorder,
                  itemBuilder: (_, i) {
                    final t = _topics[i];
                    return Card(
                      key: ValueKey(t.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: Colors.brown[100],
                              child: Text(t.name[0].toUpperCase(),
                                  style: TextStyle(color: Colors.brown[700], fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: t.description.isNotEmpty ? Text(t.description) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.orange), onPressed: () => _startEdit(t)),
                            IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), onPressed: () => _delete(t)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Вкладка «Матеріали» ────────────────────────────────────────────────────────
class _MaterialsTab extends StatefulWidget {
  final List<EducationTopic> topics;
  const _MaterialsTab({required this.topics});

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
  EducationTopic? _selectedTopic;
  List<LearningMaterial> _materials = [];
  bool _loading = false;
  bool _showForm = false;
  LearningMaterial? _editing;

  final _nameCtrl      = TextEditingController();
  final _urlCtrl       = TextEditingController();
  final _thumbnailCtrl = TextEditingController();
  LearningMaterialType _formType = LearningMaterialType.text;

  @override
  void dispose() {
    _nameCtrl.dispose(); _urlCtrl.dispose(); _thumbnailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    if (_selectedTopic == null) return;
    setState(() => _loading = true);
    final m = await EducationService.getMaterialsByTopic(_selectedTopic!.id);
    if (mounted) setState(() { _materials = m; _loading = false; });
  }

  void _startAdd() => setState(() {
    _showForm = true; _editing = null;
    _nameCtrl.clear(); _urlCtrl.clear(); _thumbnailCtrl.clear();
    _formType = LearningMaterialType.text;
  });

  void _startEdit(LearningMaterial m) => setState(() {
    _showForm = true; _editing = m;
    _nameCtrl.text = m.name; _urlCtrl.text = m.driveUrl;
    _thumbnailCtrl.text = m.thumbnailUrl ?? '';
    _formType = m.type;
  });

  void _cancel() => setState(() { _showForm = false; _editing = null; });

  Future<void> _save() async {
    if (_selectedTopic == null) return;
    if (_nameCtrl.text.trim().isEmpty || _urlCtrl.text.trim().isEmpty) return;
    final isVideo = _formType == LearningMaterialType.video;
    String? thumbnail = _thumbnailCtrl.text.trim().isNotEmpty
        ? MediaCacheService.toImageUrl(_thumbnailCtrl.text.trim())
        : null;
    // Auto-generate thumbnail if no thumbnail set
    if (thumbnail == null && isVideo) {
      final ytId = _extractYouTubeId(_urlCtrl.text.trim());
      if (ytId != null) {
        thumbnail = 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
      } else {
        // Google Drive thumbnail
        final gdId = _extractGoogleDriveId(_urlCtrl.text.trim());
        if (gdId != null) {
          thumbnail = 'https://drive.google.com/thumbnail?id=$gdId&sz=w480';
        }
      }
    }
    final m = LearningMaterial(
      id: _editing?.id ?? 'lm_${DateTime.now().millisecondsSinceEpoch}',
      topicId: _selectedTopic!.id,
      type: _formType,
      name: _nameCtrl.text.trim(),
      driveUrl: _urlCtrl.text.trim(),
      mediaType: null,
      thumbnailUrl: isVideo ? thumbnail : null,
    );
    await EducationService.saveLearningMaterial(m);
    setState(() { _showForm = false; _editing = null; });
    _loadMaterials();
  }

  String? _extractYouTubeId(String url) {
    final m1 = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m2 != null) return m2.group(1);
    final m3 = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (m3 != null) return m3.group(1);
    return null;
  }

  String? _extractGoogleDriveId(String url) {
    final m1 = RegExp(r'drive\.google\.com/file/d/([^/?]+)').firstMatch(url);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'[?&]id=([^&]+)').firstMatch(url);
    if (m2 != null) return m2.group(1);
    final m3 = RegExp(r'drive\.usercontent\.google\.com/download\?id=([^&]+)').firstMatch(url);
    if (m3 != null) return m3.group(1);
    return null;
  }

  Future<void> _delete(LearningMaterial m) async {
    await EducationService.deleteLearningMaterial(m.id);
    _loadMaterials();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicSelector(
          topics: widget.topics,
          selected: _selectedTopic,
          onSelected: (t) {
            setState(() { _selectedTopic = t; _materials = []; _showForm = false; });
            _loadMaterials();
          },
        ),
        if (_selectedTopic != null) ...[
          if (!_showForm)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Додати матеріал'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          if (_showForm)
            _InlineForm(
              title: _editing == null ? 'Новий матеріал' : 'Редагувати матеріал',
              onSave: _save,
              onCancel: _cancel,
              fields: [
                TextField(controller: _nameCtrl, decoration: _inputDec('Назва *')),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlCtrl,
                  decoration: _inputDec('Посилання на відео/файл *', hint: 'https://drive.google.com/... або YouTube'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<LearningMaterialType>(
                  value: _formType,
                  decoration: _inputDec('Тип'),
                  items: LearningMaterialType.values.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t.label))
                  ).toList(),
                  onChanged: (v) => setState(() => _formType = v!),
                ),
                if (_formType == LearningMaterialType.video) ...[
                  const SizedBox(height: 10),
                  if (true) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _thumbnailCtrl,
                      decoration: _inputDec(
                        'Обкладинка відео (URL зображення)',
                        hint: 'Залиште порожнім — для YouTube буде автоматично',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Для YouTube-відео обкладинка підбирається автоматично',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? const Center(child: Text('Немає матеріалів. Додайте перший.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: _materials.length,
                        itemBuilder: (_, i) {
                          final m = _materials[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                m.type == LearningMaterialType.video
                                    ? Icons.videocam_rounded
                                    : m.type == LearningMaterialType.audio
                                        ? Icons.headphones_rounded
                                        : m.type == LearningMaterialType.presentation
                                            ? Icons.slideshow_rounded
                                            : m.type == LearningMaterialType.infographic
                                                ? Icons.bar_chart_rounded
                                                : m.type == LearningMaterialType.image
                                                    ? Icons.image_rounded
                                                    : Icons.article_rounded,
                                color: Colors.brown[600],
                              ),
                              title: Text(m.name),
                              subtitle: Text(m.type.label, style: const TextStyle(fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.orange), onPressed: () => _startEdit(m)),
                                  IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), onPressed: () => _delete(m)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ] else
          const Expanded(child: Center(child: Text('Оберіть тему зверху'))),
      ],
    );
  }
}

// ── Вкладка «Флеш-картки» ──────────────────────────────────────────────────────
class _FlashcardsTab extends StatefulWidget {
  final List<EducationTopic> topics;
  const _FlashcardsTab({required this.topics});

  @override
  State<_FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<_FlashcardsTab> {
  EducationTopic? _selectedTopic;
  List<Flashcard> _cards = [];
  bool _loading = false;
  bool _showForm = false;

  final _qCtrl = TextEditingController();
  final _aCtrl = TextEditingController();

  @override
  void dispose() {
    _qCtrl.dispose(); _aCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    if (_selectedTopic == null) return;
    setState(() => _loading = true);
    final cards = await EducationService.getFlashcardsByTopic(_selectedTopic!.id);
    if (mounted) setState(() { _cards = cards; _loading = false; });
  }

  void _startAdd() => setState(() { _showForm = true; _qCtrl.clear(); _aCtrl.clear(); });
  void _cancel()   => setState(() { _showForm = false; });

  Future<void> _save() async {
    if (_selectedTopic == null) return;
    if (_qCtrl.text.trim().isEmpty || _aCtrl.text.trim().isEmpty) return;
    final card = Flashcard(
      id: 'fc_${DateTime.now().millisecondsSinceEpoch}',
      topicId: _selectedTopic!.id,
      question: _qCtrl.text.trim(),
      answer: _aCtrl.text.trim(),
    );
    await EducationService.saveFlashcard(card);
    setState(() { _showForm = false; });
    _loadCards();
  }

  Future<void> _uploadCsv() async {
    if (_selectedTopic == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString(encoding: utf8);
    } else {
      return;
    }
    final count = await EducationService.saveFlashcardsFromCsv(_selectedTopic!.id, content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Додано $count флеш-карток'), backgroundColor: Colors.green),
      );
    }
    _loadCards();
  }

  Future<void> _deleteAll() async {
    if (_selectedTopic == null) return;
    final ok = await _confirmDelete(context, 'всі флеш-картки для цієї теми');
    if (ok) { await EducationService.deleteAllFlashcardsForTopic(_selectedTopic!.id); _loadCards(); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicSelector(
          topics: widget.topics,
          selected: _selectedTopic,
          onSelected: (t) {
            setState(() { _selectedTopic = t; _cards = []; _showForm = false; });
            _loadCards();
          },
        ),
        if (_selectedTopic != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadCsv,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Завантажити CSV'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showForm ? _cancel : _startAdd,
                  icon: Icon(_showForm ? Icons.close : Icons.add, size: 18),
                  label: Text(_showForm ? 'Закрити' : 'Вручну'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700], foregroundColor: Colors.white),
                ),
                if (_cards.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                    tooltip: 'Видалити всі',
                    onPressed: _deleteAll,
                  ),
                ],
              ],
            ),
          ),
          if (_showForm)
            _InlineForm(
              title: 'Нова флеш-картка',
              onSave: _save,
              onCancel: _cancel,
              fields: [
                TextField(controller: _qCtrl, decoration: _inputDec('Питання *'), maxLines: 3),
                const SizedBox(height: 10),
                TextField(controller: _aCtrl, decoration: _inputDec('Відповідь *'), maxLines: 3),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Row(
              children: [
                Text('Формат CSV: питання,відповідь', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _cards.isEmpty
                    ? const Center(child: Text('Немає карток. Додайте або завантажте CSV.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _cards.length,
                        itemBuilder: (_, i) {
                          final c = _cards[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(c.question, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(c.answer, style: TextStyle(color: Colors.grey[600])),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                onPressed: () async {
                                  await EducationService.deleteFlashcard(c.id);
                                  _loadCards();
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ] else
          const Expanded(child: Center(child: Text('Оберіть тему зверху'))),
      ],
    );
  }
}

// ── Вкладка «Тести» ────────────────────────────────────────────────────────────
class _TestQuestionsTab extends StatefulWidget {
  final List<EducationTopic> topics;
  const _TestQuestionsTab({required this.topics});

  @override
  State<_TestQuestionsTab> createState() => _TestQuestionsTabState();
}

class _TestQuestionsTabState extends State<_TestQuestionsTab> {
  EducationTopic? _selectedTopic;
  List<TestQuestion> _questions = [];
  bool _loading = false;
  bool _showForm = false;

  final _qCtrl   = TextEditingController();
  final _expCtrl = TextEditingController();
  final _opts    = List.generate(4, (_) => TextEditingController());
  int _correctIdx = 0;

  @override
  void dispose() {
    _qCtrl.dispose(); _expCtrl.dispose();
    for (final c in _opts) c.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (_selectedTopic == null) return;
    setState(() => _loading = true);
    final q = await EducationService.getTestQuestionsByTopic(_selectedTopic!.id);
    if (mounted) setState(() { _questions = q; _loading = false; });
  }

  void _startAdd() => setState(() {
    _showForm = true;
    _qCtrl.clear(); _expCtrl.clear();
    for (final c in _opts) c.clear();
    _correctIdx = 0;
  });

  void _cancel() => setState(() { _showForm = false; });

  Future<void> _save() async {
    if (_selectedTopic == null) return;
    if (_qCtrl.text.trim().isEmpty || _opts.any((c) => c.text.trim().isEmpty)) return;
    final q = TestQuestion(
      id: 'tq_${DateTime.now().millisecondsSinceEpoch}',
      topicId: _selectedTopic!.id,
      question: _qCtrl.text.trim(),
      options: _opts.map((c) => c.text.trim()).toList(),
      correctIndex: _correctIdx,
      explanation: _expCtrl.text.trim().isNotEmpty ? _expCtrl.text.trim() : null,
    );
    await EducationService.saveTestQuestion(q);
    setState(() { _showForm = false; });
    _loadQuestions();
  }

  Future<void> _uploadCsv() async {
    if (_selectedTopic == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString(encoding: utf8);
    } else {
      return;
    }
    final count = await EducationService.saveTestQuestionsFromCsv(_selectedTopic!.id, content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Додано $count питань'), backgroundColor: Colors.green),
      );
    }
    _loadQuestions();
  }

  Widget _buildManualForm() {
    final labels = ['A', 'B', 'C', 'D'];
    return _InlineForm(
      title: 'Нове питання',
      onSave: _save,
      onCancel: _cancel,
      fields: [
        TextField(controller: _qCtrl, decoration: _inputDec('URL аудіо сигналу (Google Drive) *'), maxLines: 2),
        const SizedBox(height: 10),
        ...List.generate(4, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Radio<int>(
                value: i,
                groupValue: _correctIdx,
                onChanged: (v) => setState(() => _correctIdx = v!),
                activeColor: Colors.green,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: TextField(
                  controller: _opts[i],
                  decoration: _inputDec(
                    'Варіант ${labels[i]}${i == _correctIdx ? " ✓ правильний" : ""}',
                  ),
                ),
              ),
            ],
          ),
        )),
        TextField(controller: _expCtrl, decoration: _inputDec('Пояснення (опціонально)'), maxLines: 2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicSelector(
          topics: widget.topics,
          selected: _selectedTopic,
          onSelected: (t) {
            setState(() { _selectedTopic = t; _questions = []; _showForm = false; });
            _loadQuestions();
          },
        ),
        if (_selectedTopic != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadCsv,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Завантажити CSV'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showForm ? _cancel : _startAdd,
                  icon: Icon(_showForm ? Icons.close : Icons.add, size: 18),
                  label: Text(_showForm ? 'Закрити' : 'Вручну'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700], foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          if (_showForm) _buildManualForm(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Text(
              'CSV: питання,варA,варB,варC,варD,правильний(0-3),пояснення',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? const Center(child: Text('Немає питань.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _questions.length,
                        itemBuilder: (_, i) {
                          final q = _questions[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              title: Text(q.question,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              children: [
                                ...q.options.asMap().entries.map((e) => ListTile(
                                  dense: true,
                                  leading: Icon(
                                    e.key == q.correctIndex
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: e.key == q.correctIndex ? Colors.green : Colors.grey,
                                    size: 18,
                                  ),
                                  title: Text('${['A', 'B', 'C', 'D'][e.key]}. ${e.value}',
                                      style: const TextStyle(fontSize: 13)),
                                )),
                                if (q.explanation != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                    child: Text('💡 ${q.explanation}',
                                        style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 16),
                                    label: const Text('Видалити',
                                        style: TextStyle(color: Colors.red, fontSize: 12)),
                                    onPressed: () async {
                                      await EducationService.deleteTestQuestion(q.id);
                                      _loadQuestions();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ] else
          const Expanded(child: Center(child: Text('Оберіть тему зверху'))),
      ],
    );
  }
}

// ── Вибір теми ────────────────────────────────────────────────────────────────
class _TopicSelector extends StatelessWidget {
  final List<EducationTopic> topics;
  final EducationTopic? selected;
  final ValueChanged<EducationTopic> onSelected;

  const _TopicSelector({required this.topics, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return Container(
        color: Colors.brown[50],
        padding: const EdgeInsets.all(12),
        child: const Text('Спочатку додайте теми у вкладці «Теми»'),
      );
    }
    return Container(
      color: Colors.brown[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DropdownButtonFormField<EducationTopic>(
        value: selected,
        decoration: InputDecoration(
          labelText: 'Тема',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
        ),
        hint: const Text('Оберіть тему'),
        items: topics.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
        onChanged: (t) { if (t != null) onSelected(t); },
      ),
    );
  }
}

// ── Підтвердження видалення ───────────────────────────────────────────────────
Future<bool> _confirmDelete(BuildContext context, String what) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Видалити?'),
      content: Text('Буде видалено: $what'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Видалити'),
        ),
      ],
    ),
  );
  return result == true;
}

// ── Вкладка управління планом навчання ────────────────────────────────────────
class _AdminStudyPlanTab extends StatefulWidget {
  final List<EducationTopic> topics;
  const _AdminStudyPlanTab({required this.topics});

  @override
  State<_AdminStudyPlanTab> createState() => _AdminStudyPlanTabState();
}

class _AdminStudyPlanTabState extends State<_AdminStudyPlanTab> {
  List<StudyPlanEntry>  _plan         = [];
  List<EducationTopic>  _practTopics  = [];
  bool _loading = true;
  bool _saving  = false;
  String _activeLevel = 'basic';

  static const _levels = [
    (key: 'basic',        label: 'Базовий'),
    (key: 'standard',     label: 'Стандартний'),
    (key: 'professional', label: 'Професійний'),
    (key: 'expert',       label: 'Експертний'),
  ];

  static const _typesMeta = [
    (key: 'theoretical', label: 'Теоретичні',  icon: Icons.menu_book_rounded,    color: Color(0xFF1C3A1C)),
    (key: 'practical',   label: 'Практичні',   icon: Icons.construction_rounded,  color: Color(0xFFBF360C)),
    (key: 'selfStudy',   label: 'Самостійні',  icon: Icons.self_improvement_rounded, color: Color(0xFF6A1B9A)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      StudyPlanService.getAdminPlanByLevel(_activeLevel),
      PracticalService.getTopics(),
    ]);
    if (mounted) {
      setState(() {
        _plan        = results[0] as List<StudyPlanEntry>;
        _practTopics = results[1] as List<EducationTopic>;
        _loading     = false;
      });
    }
  }

  EducationTopic? _topicById(String id, String type) {
    final list = type == 'practical' ? _practTopics : widget.topics;
    try { return list.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }

  ({String key, String label, IconData icon, Color color}) _typeMeta(String type) {
    return _typesMeta.firstWhere((m) => m.key == type,
        orElse: () => _typesMeta[0]);
  }

  Future<void> _addEntry() async {
    // Крок 1: обираємо тип
    final typeKey = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Тип теми'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _typesMeta.map((m) => ListTile(
            leading: Icon(m.icon, color: m.color),
            title: Text(m.label, style: TextStyle(fontWeight: FontWeight.w600, color: m.color)),
            onTap: () => Navigator.pop(context, m.key),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
        ],
      ),
    );
    if (typeKey == null || !mounted) return;

    // Крок 2: обираємо тему зі списку відповідного типу
    final allTopics = typeKey == 'practical' ? _practTopics : widget.topics;
    final usedIds = _plan.where((e) => e.topicType == typeKey).map((e) => e.topicId).toSet();
    final available = allTopics.where((t) => !usedIds.contains(t.id)).toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Всі теми цього типу вже додані до плану')),
        );
      }
      return;
    }

    final meta = _typeMeta(typeKey);
    final selected = await showDialog<EducationTopic>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(meta.icon, color: meta.color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${meta.label} — ${_levels.firstWhere((l) => l.key == _activeLevel).label}')),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (_, i) => ListTile(
              leading: Icon(meta.icon, color: meta.color, size: 20),
              title: Text(available[i].name, style: const TextStyle(fontSize: 14)),
              subtitle: available[i].description.isNotEmpty
                  ? Text(available[i].description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11))
                  : null,
              onTap: () => Navigator.pop(context, available[i]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
        ],
      ),
    );
    if (selected == null || !mounted) return;

    // Крок 3: вказуємо кількість годин
    final hours = await _askHours(context, selected.name) ?? 0;
    if (!mounted) return;

    setState(() => _saving = true);
    final id = 'sp_${DateTime.now().millisecondsSinceEpoch}';
    final entry = StudyPlanEntry(
      id: id,
      topicId: selected.id,
      order: _plan.length,
      level: _activeLevel,
      topicType: typeKey,
      hours: hours,
    );
    final ok = await StudyPlanService.saveAdminEntry(entry);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Помилка збереження'), backgroundColor: Colors.red),
      );
    }
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  static Future<int?> _askHours(BuildContext ctx, String topicName, {int initial = 0}) async {
    final ctrl = TextEditingController(text: initial > 0 ? '$initial' : '');
    final result = await showDialog<int>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Кількість годин'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topicName, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Годин',
                border: OutlineInputBorder(),
                suffixText: 'год',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text) ?? 0),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700], foregroundColor: Colors.white),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    return result; // null = скасовано
  }

  Future<void> _editHours(StudyPlanEntry entry) async {
    final topic = _topicById(entry.topicId, entry.topicType);
    final hours = await _askHours(context, topic?.name ?? entry.topicId, initial: entry.hours);
    if (hours == null || !mounted) return; // скасовано
    setState(() => _saving = true);
    await StudyPlanService.saveAdminEntry(entry.copyWith(hours: hours));
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete(StudyPlanEntry entry) async {
    final topic = _topicById(entry.topicId, entry.topicType);
    final ok = await _confirmDelete(context, topic?.name ?? entry.topicId);
    if (!ok) return;
    setState(() => _saving = true);
    await StudyPlanService.deleteAdminEntry(entry.id);
    final remaining = _plan.where((e) => e.id != entry.id).toList();
    for (int i = 0; i < remaining.length; i++) {
      remaining[i] = remaining[i].copyWith(order: i);
    }
    if (remaining.isNotEmpty) await StudyPlanService.reorderAdminPlan(remaining);
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _moveUp(int index) async {
    if (index == 0) return;
    final list = List<StudyPlanEntry>.from(_plan);
    final tmp = list[index]; list[index] = list[index - 1]; list[index - 1] = tmp;
    for (int i = 0; i < list.length; i++) list[i] = list[i].copyWith(order: i);
    setState(() { _plan = list; _saving = true; });
    await StudyPlanService.reorderAdminPlan(list);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _moveDown(int index) async {
    if (index >= _plan.length - 1) return;
    final list = List<StudyPlanEntry>.from(_plan);
    final tmp = list[index]; list[index] = list[index + 1]; list[index + 1] = tmp;
    for (int i = 0; i < list.length; i++) list[i] = list[i].copyWith(order: i);
    setState(() { _plan = list; _saving = true; });
    await StudyPlanService.reorderAdminPlan(list);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Вибір рівня
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _levels.map((lvl) {
                final isActive = _activeLevel == lvl.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(lvl.label),
                    selected: isActive,
                    onSelected: (_) { setState(() => _activeLevel = lvl.key); _load(); },
                    selectedColor: Colors.brown[700],
                    labelStyle: TextStyle(
                        color: isActive ? Colors.white : Colors.brown[700],
                        fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Кнопка "Тематичний план"
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LevelThematicScreen(level: _activeLevel),
                ),
              ),
              icon: const Icon(Icons.table_chart_rounded, size: 16),
              label: const Text('Тематичний план'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.brown[800],
                side: BorderSide(color: Colors.brown[400]!),
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        // Панель дій
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_levels.firstWhere((l) => l.key == _activeLevel).label} рівень',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (_saving)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : _addEntry,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Додати тему'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Список
        Expanded(
          child: _plan.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt_rounded, size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('План порожній. Додайте теми.',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _plan.length,
                  itemBuilder: (_, i) {
                    final entry = _plan[i];
                    final topic = _topicById(entry.topicId, entry.topicType);
                    final meta  = _typeMeta(entry.topicType);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: meta.color.withValues(alpha: 0.12),
                          child: Icon(meta.icon, color: meta.color, size: 18),
                        ),
                        title: Text(topic?.name ?? entry.topicId,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: meta.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: meta.color.withValues(alpha: 0.4)),
                              ),
                              child: Text(meta.label,
                                  style: TextStyle(fontSize: 10, color: meta.color, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.brown[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.brown[300]!),
                              ),
                              child: Text('${entry.hours} год',
                                  style: TextStyle(fontSize: 10, color: Colors.brown[700], fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.access_time_rounded, size: 18),
                              onPressed: _saving ? null : () => _editHours(entry),
                              color: Colors.brown[600],
                              tooltip: 'Змінити години',
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                              onPressed: _saving || i == 0 ? null : () => _moveUp(i),
                              color: Colors.brown,
                              tooltip: 'Вгору',
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                              onPressed: _saving || i == _plan.length - 1 ? null : () => _moveDown(i),
                              color: Colors.brown,
                              tooltip: 'Вниз',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              onPressed: _saving ? null : () => _delete(entry),
                              color: Colors.red,
                              tooltip: 'Видалити',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Вкладка управління практичними завданнями ─────────────────────────────────
class _AdminPracticalTab extends StatefulWidget {
  const _AdminPracticalTab();

  @override
  State<_AdminPracticalTab> createState() => _AdminPracticalTabState();
}

class _AdminPracticalTabState extends State<_AdminPracticalTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;
  List<EducationTopic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
    _loadTopics();
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    setState(() => _loading = true);
    final topics = await PracticalService.getTopics();
    if (mounted) setState(() { _topics = topics; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _subTabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.brown[800],
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Теми практичних'),
            Tab(text: 'Матеріали'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _subTabController,
                  children: [
                    _PracticalTopicsSection(topics: _topics, onChanged: _loadTopics),
                    _PracticalMaterialsSection(topics: _topics),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Секція тем практичних ─────────────────────────────────────────────────────
class _PracticalTopicsSection extends StatefulWidget {
  final List<EducationTopic> topics;
  final VoidCallback onChanged;
  const _PracticalTopicsSection({required this.topics, required this.onChanged});

  @override
  State<_PracticalTopicsSection> createState() => _PracticalTopicsSectionState();
}

class _PracticalTopicsSectionState extends State<_PracticalTopicsSection> {
  bool _showForm = false;
  bool _saving   = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final id = 'pt_${DateTime.now().millisecondsSinceEpoch}';
    final topic = EducationTopic(
      id: id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      sortOrder: widget.topics.length,
    );
    await PracticalService.saveTopic(topic);
    _nameCtrl.clear();
    _descCtrl.clear();
    setState(() { _showForm = false; _saving = false; });
    widget.onChanged();
  }

  Future<void> _delete(EducationTopic topic) async {
    final ok = await _confirmDelete(context, topic.name);
    if (!ok) return;
    await PracticalService.deleteTopic(topic.id);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_showForm)
          _InlineForm(
            title: 'Нова тема практичного заняття',
            fields: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Назва теми *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Опис (необов\'язково)',
                    border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
            onSave: _saving ? () {} : _save,
            onCancel: () => setState(() => _showForm = false),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Додати тему'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ...widget.topics.map((t) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.assignment_rounded,
                    color: Color(0xFFBF360C)),
                title: Text(t.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: t.description.isNotEmpty
                    ? Text(t.description,
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 20),
                  onPressed: () => _delete(t),
                ),
              ),
            )),
      ],
    );
  }
}

// ── Секція матеріалів практичних завдань ──────────────────────────────────────
class _PracticalMaterialsSection extends StatefulWidget {
  final List<EducationTopic> topics;
  const _PracticalMaterialsSection({required this.topics});

  @override
  State<_PracticalMaterialsSection> createState() =>
      _PracticalMaterialsSectionState();
}

class _PracticalMaterialsSectionState
    extends State<_PracticalMaterialsSection> {
  EducationTopic? _selectedTopic;
  List<LearningMaterial> _materials = [];
  bool _loadingMaterials = false;
  bool _showForm = false;
  bool _saving   = false;

  final _nameCtrl = TextEditingController();
  final _urlCtrl  = TextEditingController();
  LearningMaterialType _formType = LearningMaterialType.text;

  static const _typeIcons = {
    LearningMaterialType.text:         Icons.article_rounded,
    LearningMaterialType.video:        Icons.videocam_rounded,
    LearningMaterialType.audio:        Icons.headphones_rounded,
    LearningMaterialType.presentation: Icons.slideshow_rounded,
    LearningMaterialType.infographic:  Icons.bar_chart_rounded,
    LearningMaterialType.image:        Icons.image_rounded,
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials(EducationTopic topic) async {
    setState(() {
      _selectedTopic = topic;
      _loadingMaterials = true;
      _showForm = false;
    });
    final materials = await PracticalService.getMaterialsByTopic(topic.id);
    if (mounted) {
      setState(() { _materials = materials; _loadingMaterials = false; });
    }
  }

  Future<void> _saveMaterial() async {
    if (_selectedTopic == null || _nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final id = 'pm_${DateTime.now().millisecondsSinceEpoch}';
    final material = LearningMaterial(
      id: id,
      topicId: _selectedTopic!.id,
      type: _formType,
      name: _nameCtrl.text.trim(),
      driveUrl: _urlCtrl.text.trim(),
    );
    await PracticalService.saveMaterial(material);
    _nameCtrl.clear();
    _urlCtrl.clear();
    setState(() { _showForm = false; _saving = false; });
    await _loadMaterials(_selectedTopic!);
  }

  Future<void> _deleteMaterial(LearningMaterial m) async {
    final ok = await _confirmDelete(context, m.name);
    if (!ok) return;
    await PracticalService.deleteMaterial(m.id);
    await _loadMaterials(_selectedTopic!);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<EducationTopic>(
            value: _selectedTopic,
            decoration: const InputDecoration(
              labelText: 'Тема практичного заняття',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Оберіть тему'),
            items: widget.topics
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (t) { if (t != null) _loadMaterials(t); },
          ),
        ),
        if (_selectedTopic != null)
          Expanded(
            child: _loadingMaterials
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      if (_showForm)
                        _InlineForm(
                          title: 'Новий матеріал практичного заняття',
                          fields: [
                            DropdownButtonFormField<LearningMaterialType>(
                              value: _formType,
                              decoration: const InputDecoration(
                                  labelText: 'Тип матеріалу',
                                  border: OutlineInputBorder()),
                              items: LearningMaterialType.values
                                  .map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Row(children: [
                                          Icon(_typeIcons[t], size: 16),
                                          const SizedBox(width: 8),
                                          Text(t.label),
                                        ]),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _formType = v);
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Назва *',
                                  border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _urlCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Посилання (URL)',
                                  border: OutlineInputBorder()),
                            ),
                          ],
                          onSave: _saving ? () {} : _saveMaterial,
                          onCancel: () => setState(() => _showForm = false),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                setState(() => _showForm = true),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Додати матеріал'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ..._materials.map((m) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Icon(
                                  _typeIcons[m.type] ??
                                      Icons.insert_drive_file_rounded,
                                  color: Colors.brown[600]),
                              title: Text(m.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(m.type.label,
                                  style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                    size: 20),
                                onPressed: () => _deleteMaterial(m),
                              ),
                            ),
                          )),
                    ],
                  ),
          )
        else
          const Expanded(
            child: Center(
              child: Text('Оберіть тему, щоб переглянути матеріали',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }
}

