import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/screens/add_education_screen.dart';

class EditMaterialsScreen extends StatefulWidget {
  const EditMaterialsScreen({super.key});

  @override
  State<EditMaterialsScreen> createState() => _EditMaterialsScreenState();
}

class _EditMaterialsScreenState extends State<EditMaterialsScreen> {
  List<EducationMaterial> _materials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final materials = await HuntingDataService.getEducationMaterials();
    if (mounted) {
      setState(() {
        _materials = materials;
        _loading = false;
      });
    }
  }

  Future<void> _deleteMaterial(EducationMaterial material) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити матеріал?'),
        content: Text('Видалити "${material.title}"? Цю дію не можна скасувати.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Видалити', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await HuntingDataService.deleteMaterial(material.id);
      _loadMaterials();
    }
  }

  String _difficultyLabel(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.beginner: return 'Початківець';
      case DifficultyLevel.intermediate: return 'Середній';
      case DifficultyLevel.advanced: return 'Просунутий';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редагувати навчальні матеріали'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? const Center(child: Text('Навчальні матеріали відсутні'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _materials.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final material = _materials[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.withValues(alpha: 0.15),
                        child: const Icon(Icons.school, color: Colors.purple),
                      ),
                      title: Text(material.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${material.category} · ${_difficultyLabel(material.difficulty)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.purple),
                            onPressed: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddEducationScreen(material: material),
                                ),
                              );
                              if (updated == true) _loadMaterials();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMaterial(material),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
