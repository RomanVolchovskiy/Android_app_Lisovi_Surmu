import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_event.dart';
import 'package:hunting_signals/services/events_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/category_header.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<HuntingEvent> _events = [];
  bool _loading = true;

  static const _types = ['Полювання', 'Змагання', 'Фестиваль', 'Навчання'];

  static const _typeIcons = {
    'Полювання': Icons.forest,
    'Змагання': Icons.emoji_events,
    'Фестиваль': Icons.celebration,
    'Навчання': Icons.school,
  };

  static const _typeColors = {
    'Полювання': Colors.green,
    'Змагання': Colors.amber,
    'Фестиваль': Colors.purple,
    'Навчання': Colors.blue,
  };

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await EventsService.getEvents();
    if (mounted) {
      setState(() {
        _events = events;
        _loading = false;
      });
    }
  }

  void _showCreateEventDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String selectedType = _types.first;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String? selectedSignalId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Створити подію'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Назва події *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Опис',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Місце',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Тип події',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder(
                  future: HuntingDataService.getAllSignals(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final signals = snap.data!;
                    return InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Пов\'язаний сигнал (необов\'язково)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButton<String?>(
                        value: selectedSignalId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— немає —')),
                          ...signals.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) => setDialogState(() => selectedSignalId = v),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введіть назву події')),
                  );
                  return;
                }
                final event = HuntingEvent(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  location: locationCtrl.text.trim(),
                  date: selectedDate,
                  type: selectedType,
                  relatedSignalId: selectedSignalId,
                );
                await EventsService.addEvent(event);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadEvents();
              },
              child: const Text('Зберегти'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(HuntingEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EventDetailsSheet(
        event: event,
        onDelete: () async {
          await EventsService.deleteEvent(event.id);
          _loadEvents();
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CategoryHeader(
            title: 'Мисливські Події',
            subtitle: 'Організуйте свої мисливські заходи',
            icon: Icons.event,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateEventDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Створити подію'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HuntingTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Майбутні події',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_events.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Подій ще немає',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ...(_events.map((event) => _buildEventCard(event))),
          const SizedBox(height: 24),
          Text(
            'Рекомендовані сигнали',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: HuntingDataService.getAllSignals(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.isEmpty) {
                return Text(
                  'Сигнали не знайдено',
                  style: TextStyle(color: Colors.grey[600]),
                );
              }
              final signals = snap.data!.take(3).toList();
              return Column(
                children: signals.map((s) => _buildRecommendedSignal(s.id, s.name, s.category, s.audioUrl)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(HuntingEvent event) {
    final color = _typeColors[event.type] ?? Colors.grey;
    final icon = _typeIcons[event.type] ?? Icons.event;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, color.withValues(alpha: 0.05)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(event.date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (event.location.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.location_on, size: 13, color: Colors.grey[600]),
                        Expanded(
                          child: Text(
                            event.location,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.type,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
              onPressed: () => _showEventDetails(event),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedSignal(String id, String name, String category, String? audioUrl) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HuntingTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.surround_sound, color: HuntingTheme.primaryDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(category, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_arrow, color: HuntingTheme.primaryColor, size: 24),
              onPressed: () async {
                if (audioUrl == null || audioUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Аудіо не доступне для цього сигналу')),
                  );
                  return;
                }
                try {
                  await AudioService().play(audioUrl);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Відтворення: $name')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Помилка відтворення: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailsSheet extends StatelessWidget {
  final HuntingEvent event;
  final VoidCallback onDelete;

  const _EventDetailsSheet({required this.event, required this.onDelete});

  static const _typeColors = {
    'Полювання': Colors.green,
    'Змагання': Colors.amber,
    'Фестиваль': Colors.purple,
    'Навчання': Colors.blue,
  };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[event.type] ?? Colors.grey;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                event.type,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.calendar_today, text: _formatDate(event.date)),
            if (event.location.isNotEmpty)
              _InfoRow(icon: Icons.location_on, text: event.location),
            const SizedBox(height: 16),
            if (event.description.isNotEmpty) ...[
              const Text('Опис', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(event.description, style: TextStyle(color: Colors.grey[700], height: 1.5)),
              const SizedBox(height: 24),
            ],
            if (event.relatedSignalId != null) ...[
              const Text('Рекомендований сигнал', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              FutureBuilder(
                future: HuntingDataService.getAllSignals(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const CircularProgressIndicator();
                  final signal = snap.data!.where((s) => s.id == event.relatedSignalId).firstOrNull;
                  if (signal == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: Icon(Icons.surround_sound, color: HuntingTheme.primaryColor),
                    title: Text(signal.name),
                    subtitle: Text(signal.category),
                    trailing: IconButton(
                      icon: Icon(Icons.play_arrow, color: HuntingTheme.primaryColor),
                      onPressed: () async {
                        if (signal.audioUrl == null || signal.audioUrl!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Аудіо не доступне')),
                          );
                          return;
                        }
                        await AudioService().play(signal.audioUrl!);
                      },
                    ),
                    tileColor: HuntingTheme.primaryColor.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Видалити подію?'),
                    content: Text('Видалити "${event.title}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ні')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Видалити', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  Navigator.pop(context);
                  onDelete();
                }
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Видалити подію', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }
}
