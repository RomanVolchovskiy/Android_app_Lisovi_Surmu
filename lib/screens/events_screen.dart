import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunting_signals/models/hunting_event.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/events_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/signal_event_tile.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<HuntingEvent> _userEvents = [];
  bool _loadingUser = true;

  static const _types = ['Полювання', 'Змагання', 'Фестиваль', 'Навчання'];

  static const _typeIcons = {
    'Полювання': Icons.forest,
    'Змагання': Icons.emoji_events,
    'Фестиваль': Icons.celebration,
    'Навчання': Icons.school,
  };

  static const _typeColors = {
    'Полювання': Color(0xFF2F4F2F),
    'Змагання': Color(0xFFD4A017),
    'Фестиваль': Color(0xFF4A7C3F),
    'Навчання': Color(0xFF1C3A1C),
  };

  @override
  void initState() {
    super.initState();
    _loadUserEvents();
  }

  Future<void> _loadUserEvents() async {
    final events = await EventsService.getUserEvents();
    if (mounted) {
      setState(() {
        _userEvents = events;
        _loadingUser = false;
      });
    }
  }

  // ── SIGNAL PICKER ────────────────────────────────────────────────

  /// Opens a dialog to pick one signal from [available]. Returns signal id or null.
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
                  color: HuntingTheme.primaryColor,
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

  // ── CREATE EVENT ─────────────────────────────────────────────────

  void _showCreateEventDialog() async {
    final allSignals = await HuntingDataService.getAllSignals();
    if (!mounted) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String selectedType = _types.first;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    final mainIds = <String>[];
    final accompIds = <String>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Створити особисту подію'),
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      firstDate: DateTime.now(),
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
                  sublabel:
                      'Рекомендовані залежно від ситуації події',
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
                backgroundColor: HuntingTheme.primaryColor,
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
                final event = await EventsService.createUserEvent(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  location: locationCtrl.text.trim(),
                  date: selectedDate,
                  type: selectedType,
                  mainSignalIds: mainIds,
                  accompanyingSignalIds: accompIds,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadUserEvents();
                if (mounted) _showShareCode(event);
              },
              child: const Text('Зберегти'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the signal selection section used inside the event dialog.
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

  // ── ENTER SHARE CODE ─────────────────────────────────────────────

  void _showEnterCodeDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ввести код події'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Введіть 6-символьний код, отриманий від іншого користувача:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
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
              backgroundColor: HuntingTheme.primaryColor,
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пошук події...')),
                );
              }
              final error =
                  await EventsService.importEventByCode(code);
              if (mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Подію успішно додано!'),
                    backgroundColor:
                        error == null ? Colors.green : Colors.red,
                  ),
                );
                if (error == null) _loadUserEvents();
              }
            },
            child: const Text('Додати'),
          ),
        ],
      ),
    );
  }

  // ── SHOW SHARE CODE ──────────────────────────────────────────────

  void _showShareCode(HuntingEvent event) {
    if (event.shareCode == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Код для обміну'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Поділіться цим кодом, щоб інші могли додати вашу подію:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color:
                    HuntingTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD4A017),
                  width: 2,
                ),
              ),
              child: Text(
                event.shareCode!,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                  color: HuntingTheme.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: event.shareCode!),
                );
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Код скопійовано')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Скопіювати код'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HuntingTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрити'),
          ),
        ],
      ),
    );
  }

  // ── EVENT DETAILS ────────────────────────────────────────────────

  void _showUserEventDetails(HuntingEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EventDetailsSheet(
        event: event,
        canDelete: true,
        onDelete: () async {
          await EventsService.deleteUserEvent(event.id);
          _loadUserEvents();
        },
        onShare: event.shareCode != null
            ? () => _showShareCode(event)
            : null,
      ),
    );
  }

  void _showGlobalEventDetails(HuntingEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EventDetailsSheet(
        event: event,
        canDelete: false,
        onDelete: () {},
        onShare: null,
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  // ── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color:
                  HuntingTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD4A017),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event,
                    color: HuntingTheme.primaryDark, size: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мисливські події',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HuntingTheme.primaryDark,
                      ),
                    ),
                    Text(
                      'Загальні та особисті заходи',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateEventDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Створити подію'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HuntingTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _showEnterCodeDialog,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Ввести код'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HuntingTheme.primaryDark,
                  side: BorderSide(
                    color: HuntingTheme.primaryColor,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Global Events ──────────────────────────────────────
          _buildSectionTitle(
            'Загальні події',
            Icons.public,
            const Color(0xFF1C3A1C),
          ),
          const SizedBox(height: 2),
          Text(
            'Створені адміністратором для всіх користувачів',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<HuntingEvent>>(
            stream: EventsService.globalEventsStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final events = snap.data ?? [];
              if (events.isEmpty) {
                return _buildEmptyState(
                  'Загальних подій немає',
                  Icons.event_note,
                );
              }
              return Column(
                children: events
                    .map((e) => _buildEventCard(
                          e,
                          isGlobal: true,
                          onTap: () => _showGlobalEventDetails(e),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),

          // ── My Events ─────────────────────────────────────────
          _buildSectionTitle(
            'Мої події',
            Icons.person,
            HuntingTheme.primaryColor,
          ),
          const SizedBox(height: 2),
          Text(
            'Ваші особисті події. Поділіться кодом з іншими',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          if (_loadingUser)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_userEvents.isEmpty)
            _buildEmptyState(
              'Ваших подій немає.\nНатисніть "Створити подію"',
              Icons.event_busy,
            )
          else
            Column(
              children: _userEvents
                  .map((e) => _buildEventCard(
                        e,
                        isGlobal: false,
                        onTap: () => _showUserEventDetails(e),
                        onShare: e.shareCode != null
                            ? () => _showShareCode(e)
                            : null,
                      ))
                  .toList(),
            ),
          const SizedBox(height: 28),

          // ── Recommended Signals ───────────────────────────────
          _buildSectionTitle(
            'Рекомендовані сигнали',
            Icons.queue_music,
            Colors.grey.shade700,
          ),
          const SizedBox(height: 12),
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
                children: signals
                    .map((s) => _buildRecommendedSignal(
                          s.name,
                          s.category,
                          s.audioUrl,
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
    HuntingEvent event, {
    required bool isGlobal,
    required VoidCallback onTap,
    VoidCallback? onShare,
  }) {
    final color = _typeColors[event.type] ?? Colors.grey;
    final icon = _typeIcons[event.type] ?? Icons.event;
    final signalCount =
        event.mainSignalIds.length + event.accompanyingSignalIds.length;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isGlobal)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C3A1C)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Для всіх',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF1C3A1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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
                          const SizedBox(width: 6),
                          Icon(Icons.music_note,
                              size: 11, color: Colors.grey[500]),
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
              if (onShare != null)
                IconButton(
                  icon: Icon(
                    Icons.share,
                    color: HuntingTheme.primaryColor,
                    size: 20,
                  ),
                  tooltip: 'Показати код',
                  onPressed: onShare,
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedSignal(
    String name,
    String category,
    String? audioUrl,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
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
              child: Icon(
                Icons.surround_sound,
                color: HuntingTheme.primaryDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    category,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.play_arrow,
                color: HuntingTheme.primaryColor,
                size: 24,
              ),
              onPressed: () async {
                if (audioUrl == null || audioUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Аудіо не доступне')),
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
                      SnackBar(content: Text('Помилка: $e')),
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

// ── EVENT DETAILS BOTTOM SHEET ────────────────────────────────────

class _EventDetailsSheet extends StatelessWidget {
  final HuntingEvent event;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback? onShare;

  const _EventDetailsSheet({
    required this.event,
    required this.canDelete,
    required this.onDelete,
    this.onShare,
  });

  static const _typeColors = {
    'Полювання': Color(0xFF2F4F2F),
    'Змагання': Color(0xFFD4A017),
    'Фестиваль': Color(0xFF4A7C3F),
    'Навчання': Color(0xFF1C3A1C),
  };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[event.type] ?? Colors.grey;
    final hasSignals = event.mainSignalIds.isNotEmpty ||
        event.accompanyingSignalIds.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollCtrl,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (event.isGlobal)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C3A1C)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Загальна',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1C3A1C),
                        fontWeight: FontWeight.w600,
                      ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                event.type,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.calendar_today,
              text: _formatDate(event.date),
            ),
            if (event.location.isNotEmpty)
              _InfoRow(icon: Icons.location_on, text: event.location),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Опис',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: TextStyle(color: Colors.grey[700], height: 1.5),
              ),
            ],

            // ── Signals section ──────────────────────────────────
            if (hasSignals) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              FutureBuilder(
                future: HuntingDataService.getAllSignals(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final allSignals = snap.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main signals
                      if (event.mainSignalIds.isNotEmpty) ...[
                        const SignalSectionHeader(
                          title: 'Основні сигнали',
                          subtitle: 'Обов\'язкові для застосування',
                          accentColor: Color(0xFF2F4F2F),
                        ),
                        const SizedBox(height: 10),
                        ...event.mainSignalIds.indexed.map((entry) {
                          final (i, id) = entry;
                          final signal = allSignals
                              .where((s) => s.id == id)
                              .firstOrNull;
                          if (signal == null) return const SizedBox.shrink();
                          return SignalEventTile(
                            signal: signal,
                            number: i + 1,
                            accentColor: const Color(0xFF2F4F2F),
                          );
                        }),
                      ],

                      // Accompanying signals
                      if (event.accompanyingSignalIds.isNotEmpty) ...[
                        if (event.mainSignalIds.isNotEmpty)
                          const SizedBox(height: 16),
                        const SignalSectionHeader(
                          title: 'Сопутні сигнали',
                          subtitle: 'Рекомендовані залежно від ситуації',
                          accentColor: Color(0xFFD4A017),
                        ),
                        const SizedBox(height: 10),
                        ...event.accompanyingSignalIds.indexed.map((entry) {
                          final (i, id) = entry;
                          final signal = allSignals
                              .where((s) => s.id == id)
                              .firstOrNull;
                          if (signal == null) return const SizedBox.shrink();
                          return SignalEventTile(
                            signal: signal,
                            number: i + 1,
                            accentColor: const Color(0xFFD4A017),
                          );
                        }),
                      ],
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),

            // Share button
            if (onShare != null) ...[
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onShare!();
                },
                icon: Icon(
                  Icons.share,
                  color: HuntingTheme.primaryColor,
                ),
                label: Text(
                  'Поділитися кодом',
                  style: TextStyle(color: HuntingTheme.primaryColor),
                ),
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: HuntingTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Delete button
            if (canDelete)
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Видалити подію?'),
                      content: Text('Видалити "${event.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(ctx, false),
                          child: const Text('Ні'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Видалити',
                            style: TextStyle(color: Colors.white),
                          ),
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
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
