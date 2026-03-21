import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/storage_manager.dart';

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
  List<SignalCategory> _categories = [];
  final TextEditingController _audioController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  final TextEditingController _notationController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _historicalController = TextEditingController();
  final TextEditingController _usageController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  bool get _isEditMode => widget.signal != null;

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
      _durationController.text = s.duration.toString();
      _audioController.text = s.audioUrl ?? '';
      _videoController.text = s.videoUrl ?? '';
      _notationController.text = s.notationUrl ?? '';
      _imageController.text = s.imageUrl ?? '';
      _historicalController.text = s.historicalInfo ?? '';
      _usageController.text = s.usageInstructions ?? '';
      _tagsController.text = s.tags?.join(', ') ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _audioController.dispose();
    _videoController.dispose();
    _notationController.dispose();
    _imageController.dispose();
    _historicalController.dispose();
    _usageController.dispose();
    _tagsController.dispose();
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
                const SizedBox(height: 32),
                _buildSectionTitle('Мультимедійні файли'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _audioController,
                  label: 'Аудіо файл',
                  hint: 'URL або шлях до аудіо файлу',
                  icon: Icons.audiotrack,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _videoController,
                  label: 'Відео файл',
                  hint: 'URL або шлях до відео файлу',
                  icon: Icons.videocam,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _notationController,
                  label: 'Файл з нотами',
                  hint: 'URL або шлях до файлу з нотами',
                  icon: Icons.music_note,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _imageController,
                  label: 'Зображення',
                  hint: 'URL або шлях до зображення',
                  icon: Icons.image,
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
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines ?? 1,
      keyboardType: keyboardType,
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
          audioUrl: _audioController.text.isNotEmpty ? _audioController.text : null,
          videoUrl: _videoController.text.isNotEmpty ? _videoController.text : null,
          notationUrl: _notationController.text.isNotEmpty ? _notationController.text : null,
          imageUrl: _imageController.text.isNotEmpty ? _imageController.text : null,
          historicalInfo: _historicalController.text.isNotEmpty ? _historicalController.text : null,
          usageInstructions: _usageController.text.isNotEmpty ? _usageController.text : null,
          tags: _tagsController.text.isNotEmpty
              ? _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : null,
          isFavorite: _isEditMode ? widget.signal!.isFavorite : false,
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
