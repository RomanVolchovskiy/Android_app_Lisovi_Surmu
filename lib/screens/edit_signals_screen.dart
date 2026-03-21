import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/screens/add_signal_screen.dart';

class EditSignalsScreen extends StatefulWidget {
  const EditSignalsScreen({super.key});

  @override
  State<EditSignalsScreen> createState() => _EditSignalsScreenState();
}

class _EditSignalsScreenState extends State<EditSignalsScreen> {
  List<HuntingSignal> _signals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  Future<void> _loadSignals() async {
    final signals = await HuntingDataService.getAllSignals();
    if (mounted) {
      setState(() {
        _signals = signals;
        _loading = false;
      });
    }
  }

  Future<void> _deleteSignal(HuntingSignal signal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити сигнал?'),
        content: Text('Видалити "${signal.name}"? Цю дію не можна скасувати.'),
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
      await HuntingDataService.deleteSignal(signal.id);
      _loadSignals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редагувати сигнали'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _signals.isEmpty
              ? const Center(child: Text('Сигнали відсутні'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _signals.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final signal = _signals[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        child: const Icon(Icons.surround_sound, color: Colors.orange),
                      ),
                      title: Text(signal.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(signal.category, style: TextStyle(color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddSignalScreen(signal: signal),
                                ),
                              );
                              if (updated == true) _loadSignals();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteSignal(signal),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
