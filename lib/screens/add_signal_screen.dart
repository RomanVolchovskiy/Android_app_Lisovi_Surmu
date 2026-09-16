import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/media_cache_service.dart';
import 'package:hunting_signals/services/storage_manager.dart';
import 'package:hunting_signals/widgets/notation_editor.dart';

class AddSignalScreen extends StatefulWidget {
  final HuntingSignal? signal;

  const AddSignalScreen({super.key, this.signal});

  @override
  State<AddSignalScreen> createState() => _AddSignalScreenState();
}

class _AddSignalScreenState extends State<AddSignalScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  String? _selectedCategory;
  String? _selectedDifficulty;
  List<SignalCategory> _categories = [];
  final TextEditingController _audioController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  final TextEditingController _video2Controller = TextEditingController();
  final TextEditingController _notationController = TextEditingController();
  final TextEditingController _notationAudioController = TextEditingController();
  final TextEditingController _partitureController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _historicalController = TextEditingController();
  final TextEditingController _usageController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _galleryController = TextEditingController();
  final TextEditingController _signalTextController = TextEditingController();

  List<Map<String, dynamic>> _notationData = [];
  final TextEditingController _tempoController = TextEditingController();

  bool get _isEditMode => widget.signal != null;

  /// Для аудіо/відео — URL для завантаження файлу
  String _convertForMedia(String url) =>
      MediaCacheService.toAudioDownloadUrl(url.trim());

  /// Для зображень/нот/галереї — URL для прямого відображення
  String _convertForImage(String url) =>
      MediaCacheService.toImageUrl(url.trim());

  void _applyMediaConversion(TextEditingController controller) {
    final converted = _convertForMedia(controller.text);
    if (converted != controller.text.trim()) controller.text = converted;
  }

  void _applyImageConversion(TextEditingController controller) {
    final converted = _convertForImage(controller.text);
    if (converted != controller.text.trim()) controller.text = converted;
  }

  @override
  void initState() {
    super.initState();
    HuntingDataService.getCategories().then((cats) {
      setState(() => _categories = cats);
    });
    if (_isEditMode) {
      final s = widget.signal!;
      _nameController.text = s.name;
      _descriptionController.text = s.description;
      _selectedCategory = s.category;
      _selectedDifficulty = s.difficulty;
      _durationController.text = s.duration.toString();
      _audioController.text = s.audioUrl ?? '';
      _videoController.text = s.videoUrl ?? '';
      _video2Controller.text = s.videoUrl2 ?? '';
      _notationController.text = s.notationUrl ?? '';
      _notationAudioController.text = s.notationAudioUrl ?? '';
      _partitureController.text = s.partitureUrl ?? '';
      _imageController.text = s.imageUrl ?? '';
      _historicalController.text = s.historicalInfo ?? '';
      _usageController.text = s.usageInstructions ?? '';
      _tagsController.text = s.tags?.join(', ') ?? '';
      _galleryController.text = s.galleryImages?.join('\n') ?? '';
      _signalTextController.text = s.signalText ?? '';
      _notationData = List<Map<String, dynamic>>.from(s.notationData ?? []);
      _tempoController.text = s.notationTempo?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _audioController.dispose();
    _videoController.dispose();
    _video2Controller.dispose();
    _notationController.dispose();
    _notationAudioController.dispose();
    _partitureController.dispose();
    _tempoController.dispose();
    _imageController.dispose();
    _historicalController.dispose();
    _usageController.dispose();
    _tagsController.dispose();
    _galleryController.dispose();
    _signalTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редагувати сигнал' : 'Додати новий сигнал'),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.brown[100]!, Colors.brown[50]!],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Основна інформація'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nameController,
                  label: 'Назва сигналу *',
                  hint: 'Введіть назву сигналу',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Будь ласка, введіть назву сигналу';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Опис сигналу *',
                  hint: 'Введіть опис сигналу',
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Будь ласка, введіть опис сигналу';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Категорія *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.9),
                  ),
                  items: _categories.map((cat) => DropdownMenuItem(
                    value: cat.name,
                    child: Text(cat.name),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                  validator: (value) => value == null ? 'Будь ласка, оберіть категорію' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _durationController,
                  label: 'Тривалість (секунди)',
                  hint: 'Наприклад: 30',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDifficulty,
                  decoration: InputDecoration(
                    labelText: 'Складність (для аудіо тесту)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.9),
                    prefixIcon: const Icon(Icons.signal_cellular_alt_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('— не вказано —')),
                    DropdownMenuItem(value: 'easy',   child: Text('🟢 Легкий')),
                    DropdownMenuItem(value: 'medium', child: Text('🟡 Середній')),
                    DropdownMenuItem(value: 'hard',   child: Text('🔴 Важкий')),
                  ],
                  onChanged: (v) => setState(() => _selectedDifficulty = v),
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Мультимедійні файли'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _audioController,
                  label: 'Аудіо файл',
                  hint: 'URL або Google Drive посилання',
                  icon: Icons.audiotrack,
                  onEditingComplete: () => _applyMediaConversion(_audioController),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _videoController,
                  label: 'Відео 1 (кнопка «Дивитися»)',
                  hint: 'URL або Google Drive посилання',
                  icon: Icons.videocam,
                  onEditingComplete: () => _applyMediaConversion(_videoController),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _video2Controller,
                  label: 'Відео 2 (кнопка «Відео» в деталях)',
                  hint: 'URL або Google Drive посилання',
                  icon: Icons.videocam_outlined,
                  onEditingComplete: () => _applyMediaConversion(_video2Controller),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _notationController,
                  label: 'Файл з нотами (зображення)',
                  hint: 'URL або Google Drive посилання',
                  icon: Icons.music_note,
                  onEditingComplete: () => _applyImageConversion(_notationController),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _notationAudioController,
                  label: 'Аудіо до нот (спів із сигналом)',
                  hint: 'URL або Google Drive посилання',
                  icon: Icons.mic,
                  onEditingComplete: () => _applyMediaConversion(_notationAudioController),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _partitureController,
                  label: 'Партитура (захищене зображення)',
                  hint: 'URL або Google Drive посилання',
                  icon: Icons.library_music,
                  onEditingComplete: () => _applyImageConversion(_partitureController),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _signalTextController,
                  label: 'Текст сигналу (слова)',
                  hint: 'Слова до мелодії сигналу, які відображатимуться під нотами',
                  icon: Icons.text_fields_rounded,
                  maxLines: 6,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _imageController,
                  label: 'Зображення (обкладинка)',
                  hint: 'URL або Google Drive посилання',
                  icon: Icons.image,
                  onEditingComplete: () => _applyImageConversion(_imageController),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _galleryController,
                  label: 'Фотогалерея',
                  hint: 'Кожне посилання з нового рядка',
                  icon: Icons.photo_library,
                  maxLines: 5,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Графічне відображення нот'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.brown[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tempo field
                      Row(
                        children: [
                          const Icon(Icons.speed, color: Colors.brown, size: 20),
                          const SizedBox(width: 8),
                          const Text('Темп сигналу (BPM):',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.brown)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: _tempoController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '80',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('ударів/хв', style: TextStyle(fontSize: 12, color: Colors.brown)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      NotationEditorWidget(
                        initialNotes: _notationData,
                        onChanged: (data) => setState(() => _notationData = data),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Додаткова інформація'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _historicalController,
                  label: 'Історична інформація',
                  hint: 'Історична довідка про сигнал',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _usageController,
                  label: 'Інструкції з використання',
                  hint: 'Коли і як використовувати цей сигнал',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _tagsController,
                  label: 'Теги',
                  hint: 'Через кому, наприклад: традиція, святковий, трофей',
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _isEditMode ? 'Зберегти зміни' : 'Зберегти сигнал',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLines,
    TextInputType? keyboardType,
    IconData? icon,
    String? Function(String?)? validator,
    VoidCallback? onEditingComplete,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines ?? 1,
      keyboardType: keyboardType,
      onEditingComplete: onEditingComplete,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
      ),
      validator: validator,
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      bool success = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final signal = HuntingSignal(
          id: _isEditMode
              ? widget.signal!.id
              : DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory ?? '',
          duration: int.tryParse(_durationController.text) ?? 0,
          audioUrl: _audioController.text.isNotEmpty ? _convertForMedia(_audioController.text) : null,
          videoUrl: _videoController.text.isNotEmpty ? _convertForMedia(_videoController.text) : null,
          videoUrl2: _video2Controller.text.isNotEmpty ? _convertForMedia(_video2Controller.text) : null,
          notationUrl: _notationController.text.isNotEmpty ? _convertForImage(_notationController.text) : null,
          notationAudioUrl: _notationAudioController.text.isNotEmpty ? _convertForMedia(_notationAudioController.text) : null,
          partitureUrl: _partitureController.text.isNotEmpty ? _convertForImage(_partitureController.text) : null,
          imageUrl: _imageController.text.isNotEmpty ? _convertForImage(_imageController.text) : null,
          historicalInfo: _historicalController.text.isNotEmpty ? _historicalController.text : null,
          usageInstructions: _usageController.text.isNotEmpty ? _usageController.text : null,
          tags: _tagsController.text.isNotEmpty
              ? _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : null,
          galleryImages: _galleryController.text.isNotEmpty
              ? _galleryController.text.split('\n').map((e) => _convertForImage(e)).where((e) => e.isNotEmpty).toList()
              : null,
          isFavorite: _isEditMode ? widget.signal!.isFavorite : false,
          difficulty: _selectedDifficulty,
          signalText: _signalTextController.text.isNotEmpty ? _signalTextController.text : null,
          notationData: _notationData.isNotEmpty ? _notationData : null,
          notationTempo: _tempoController.text.isNotEmpty
              ? int.tryParse(_tempoController.text)
              : null,
        );

        if (_isEditMode) {
          success = await HuntingDataService.updateSignal(signal);
        } else {
          success = await HuntingDataService.addSignal(signal);
        }

        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) Navigator.pop(context);
        debugPrint('Помилка збереження: $e');
      }

      if (success) {
        final storageType = StorageManager.currentStorage;
        final storageName = storageType == StorageType.googleDrive ? 'Google Drive' : 'локальне сховище';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode
                    ? 'Сигнал успішно оновлено в $storageName'
                    : 'Сигнал успішно збережено в $storageName',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Помилка при збереженні сигналу'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
