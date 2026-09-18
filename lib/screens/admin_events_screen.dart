import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_event.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/events_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/widgets/signal_event_tile.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  static const _types = ['Полювання', 'Змагання', 'Фестиваль', 'Навчання'];

  static const _typeColors = {
    'Полювання': Color(0xFF2F4F2F),
    'Змагання': Color(0xFFD4A017),
    'Фестиваль': Color(0xFF4A7C3F),
    'Навчання': Color(0xFF1C3A1C),
  };

  static const _typeIcons = {
    'Полювання': Icons.forest,
    'Змагання': Icons.emoji_events,
    'Фестиваль': Icons.celebration,
    'Навчання': Icons.school,
  };

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  // ── SIGNAL PICKER ────────────────────────────────────────────────

  Future<String?> _pickSignal(
    BuildContext context,
    List<HuntingSignal> available,
  ) {
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Усі сигнали вже додано')),
      );
      return Future.value(null);
    }
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Обрати сигнал'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (ctx, i) {
              final s = available[i];
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.surround_sound,
                  color: Colors.brown[600],
                  size: 20,
                ),
                title: Text(s.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  s.category,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(ctx, s.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати'),
          ),
        ],
      ),
    );
  }

  // ── SIGNAL SECTION BUILDER ───────────────────────────────────────

  Widget _buildSignalSection({
    required BuildContext ctx,
    required String label,
    required String sublabel,
    required Color accentColor,
    required List<String> selectedIds,
    required List<HuntingSignal> allSignals,
    required List<String> allSelectedIds,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            sublabel,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 8),
        if (selectedIds.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selectedIds.map((id) {
              final signal =
                  allSignals.where((s) => s.id == id).firstOrNull;
              return Chip(
                label: Text(
                  signal?.name ?? id,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: accentColor.withValues(alpha: 0.1),
                side: BorderSide(
                  color: accentColor.withValues(alpha: 0.3),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => onRemove(id),
              );
            }).toList(),
          ),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
            padding: EdgeInsets.zero,
          ),
          onPressed: () async {
            final available = allSignals
                .where((s) => !allSelectedIds.contains(s.id))
                .toList();
            final picked = await _pickSignal(ctx, available);
            if (picked != null) onAdd(picked);
          },
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Додати сигнал'),
        ),
      ],
    );
  }

  // ── EVENT DIALOG ─────────────────────────────────────────────────

  void _showEventDialog(BuildContext context, {HuntingEvent? editEvent}) async {
    final allSignals = await HuntingDataService.getAllSignals();
    if (!context.mounted) return;

    final isEditing = editEvent != null;
    final titleCtrl = TextEditingController(text: editEvent?.title ?? '');
    final descCtrl =
        TextEditingController(text: editEvent?.description ?? '');
    final locationCtrl =
        TextEditingController(text: editEvent?.location ?? '');
    String selectedType = editEvent?.type ?? _types.first;
    DateTime selectedDate =
        editEvent?.date ?? DateTime.now().add(const Duration(days: 7));
    final mainIds = List<String>.from(editEvent?.mainSignalIds ?? []);
    final accompIds =
        List<String>.from(editEvent?.accompanyingSignalIds ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title:
              Text(isEditing ? 'Редагувати подію' : 'Нова загальна подія'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _types
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedType = v!),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_formatDate(selectedDate)),
                ),
                const SizedBox(height: 16),
                const Divider(),

                // ── Основні сигнали ──────────────────────────────
                _buildSignalSection(
                  ctx: ctx,
                  label: 'Основні сигнали',
                  sublabel: 'Обов\'язкові для застосування на події',
                  accentColor: const Color(0xFF2F4F2F),
                  selectedIds: mainIds,
                  allSignals: allSignals,
                  allSelectedIds: [...mainIds, ...accompIds],
                  onAdd: (id) => setDialogState(() => mainIds.add(id)),
                  onRemove: (id) =>
                      setDialogState(() => mainIds.remove(id)),
                ),
                const Divider(),

                // ── Сопутні сигнали ──────────────────────────────
                _buildSignalSection(
                  ctx: ctx,
                  label: 'Сопутні сигнали',
                  sublabel: 'Рекомендовані залежно від ситуації події',
                  accentColor: const Color(0xFFD4A017),
                  selectedIds: accompIds,
                  allSignals: allSignals,
                  allSelectedIds: [...mainIds, ...accompIds],
                  onAdd: (id) =>
                      setDialogState(() => accompIds.add(id)),
                  onRemove: (id) =>
                      setDialogState(() => accompIds.remove(id)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Введіть назву події')),
                  );
                  return;
                }
                final event = HuntingEvent(
                  id: editEvent?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  location: locationCtrl.text.trim(),
                  date: selectedDate,
                  type: selectedType,
                  mainSignalIds: mainIds,
                  accompanyingSignalIds: accompIds,
                  isGlobal: true,
                );
                final success = isEditing
                    ? await EventsService.updateGlobalEvent(event)
                    : await EventsService.createGlobalEvent(event);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? isEditing
                                ? 'Подію оновлено!'
                                : 'Загальну подію створено!'
                            : 'Помилка збереження',
                      ),
                      backgroundColor:
                          success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: Text(isEditing ? 'Зберегти' : 'Створити'),
            ),
          ],
        ),
      ),
    );
  }

  // ── PROMOTE DIALOG ───────────────────────────────────────────────

  void _showPromoteDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Імпортувати подію користувача'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Введіть код події користувача, щоб зробити її загальнодоступною для всіх:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Код події',
                border: OutlineInputBorder(),
                counterText: '',
                hintText: 'XXXXXX',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Код повинен містити 6 символів'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final error = await EventsService.promoteToGlobal(code);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error ?? 'Подію додано для всіх користувачів!',
                    ),
                    backgroundColor:
                        error == null ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Додати для всіх'),
          ),
        ],
      ),
    );
  }

  // ── DELETE CONFIRM ───────────────────────────────────────────────

  void _confirmDelete(BuildContext context, HuntingEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити подію?'),
        content:
            Text('Видалити "${event.title}" для всіх користувачів?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ні'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await EventsService.deleteGlobalEvent(event.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Подію видалено' : 'Помилка видалення',
                    ),
                    backgroundColor:
                        success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Видалити',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── EVENT DETAILS (admin) ────────────────────────────────────────

  void _showEventDetails(BuildContext context, HuntingEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _AdminEventDetailsSheet(
          event: event,
          scrollCtrl: scrollCtrl,
          onEdit: () {
            Navigator.pop(ctx);
            _showEventDialog(context, editEvent: event);
          },
          onDelete: () {
            Navigator.pop(ctx);
            _confirmDelete(context, event);
          },
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управління подіями'),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => _showPromoteDialog(context),
            icon: const Icon(Icons.qr_code_scanner,
                color: Colors.white70),
            label: const Text(
              'Ввести код',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Нова подія'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<HuntingEvent>>(
        stream: EventsService.globalEventsStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Помилка: ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Загальних подій немає',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Натисніть "Нова подія", щоб створити',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: events.length,
            itemBuilder: (ctx, i) =>
                _buildEventCard(context, events[i]),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, HuntingEvent event) {
    final color = _typeColors[event.type] ?? const Color(0xFF2F4F2F);
    final icon = _typeIcons[event.type] ?? Icons.event;
    final signalCount = event.mainSignalIds.length +
        event.accompanyingSignalIds.length;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: () => _showEventDetails(context, event),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF8E7), Color(0xFFE8C87A)],
            ),
            border: Border.all(
              color: const Color(0xFFD4A017),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 11, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(event.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (event.location.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.location_on,
                              size: 11, color: Colors.grey[600]),
                          Expanded(
                            child: Text(
                              event.location,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.type,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (signalCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.music_note,
                            size: 11,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$signalCount сигн.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit,
                    color: Colors.brown, size: 20),
                tooltip: 'Редагувати',
                onPressed: () =>
                    _showEventDialog(context, editEvent: event),
              ),
              IconButton(
                icon: const Icon(Icons.delete,
                    color: Colors.red, size: 20),
                tooltip: 'Видалити',
                onPressed: () => _confirmDelete(context, event),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ADMIN EVENT DETAILS SHEET ─────────────────────────────────────

class _AdminEventDetailsSheet extends StatefulWidget {
  final HuntingEvent event;
  final ScrollController scrollCtrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminEventDetailsSheet({
    required this.event,
    required this.scrollCtrl,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AdminEventDetailsSheet> createState() =>
      _AdminEventDetailsSheetState();
}

class _AdminEventDetailsSheetState extends State<_AdminEventDetailsSheet> {
  static const _typeColors = {
    'Полювання': Color(0xFF2F4F2F),
    'Змагання': Color(0xFFD4A017),
    'Фестиваль': Color(0xFF4A7C3F),
    'Навчання': Color(0xFF1C3A1C),
  };

  late List<String> _mainIds;
  late List<String> _accompIds;
  List<HuntingSignal> _allSignals = [];

  @override
  void initState() {
    super.initState();
    _mainIds = List.from(widget.event.mainSignalIds);
    _accompIds = List.from(widget.event.accompanyingSignalIds);
    _loadSignals();
  }

  Future<void> _loadSignals() async {
    final signals = await HuntingDataService.getAllSignals();
    if (mounted) setState(() => _allSignals = signals);
  }

  Future<void> _saveOrder() async {
    final updated = HuntingEvent(
      id: widget.event.id,
      title: widget.event.title,
      description: widget.event.description,
      location: widget.event.location,
      date: widget.event.date,
      type: widget.event.type,
      mainSignalIds: _mainIds,
      accompanyingSignalIds: _accompIds,
      isGlobal: widget.event.isGlobal,
      shareCode: widget.event.shareCode,
    );
    EventsService.updateGlobalEvent(updated); // fire-and-forget
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Widget _buildReorderableSignals({
    required List<String> ids,
    required Color accentColor,
    required ValueChanged<int> onRemove,
    required void Function(int, int) onReorder,
  }) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return ReorderableListView(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: onReorder,
      children: ids.asMap().entries.map((entry) {
        final i = entry.key;
        final id = entry.value;
        final s = _allSignals.where((s) => s.id == id).firstOrNull;
        if (s == null) return SizedBox(key: ValueKey(id));
        return Row(
          key: ValueKey(id),
          children: [
            ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, color: Colors.grey[400]),
              ),
            ),
            Expanded(
              child: SignalEventTile(
                signal: s,
                number: i + 1,
                accentColor: accentColor,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[widget.event.type] ?? Colors.grey;
    final hasSignals = _mainIds.isNotEmpty || _accompIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: widget.scrollCtrl,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.event.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.brown),
                tooltip: 'Редагувати',
                onPressed: widget.onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.event.type,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                _formatDate(widget.event.date),
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
          if (widget.event.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.event.location,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
          if (widget.event.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Опис',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.event.description,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
          ],

          // ── Signals ─────────────────────────────────────────
          if (hasSignals) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            if (_allSignals.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mainIds.isNotEmpty) ...[
                    const SignalSectionHeader(
                      title: 'Основні сигнали',
                      subtitle: 'Обов\'язкові для застосування',
                      accentColor: Color(0xFF2F4F2F),
                    ),
                    const SizedBox(height: 10),
                    _buildReorderableSignals(
                      ids: _mainIds,
                      accentColor: const Color(0xFF2F4F2F),
                      onRemove: (_) {},
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final id = _mainIds.removeAt(oldIndex);
                          _mainIds.insert(newIndex, id);
                        });
                        _saveOrder();
                      },
                    ),
                  ],
                  if (_accompIds.isNotEmpty) ...[
                    if (_mainIds.isNotEmpty) const SizedBox(height: 16),
                    const SignalSectionHeader(
                      title: 'Сопутні сигнали',
                      subtitle: 'Рекомендовані залежно від ситуації',
                      accentColor: Color(0xFFD4A017),
                    ),
                    const SizedBox(height: 10),
                    _buildReorderableSignals(
                      ids: _accompIds,
                      accentColor: const Color(0xFFD4A017),
                      onRemove: (_) {},
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final id = _accompIds.removeAt(oldIndex);
                          _accompIds.insert(newIndex, id);
                        });
                        _saveOrder();
                      },
                    ),
                  ],
                ],
              ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text(
              'Видалити подію',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
