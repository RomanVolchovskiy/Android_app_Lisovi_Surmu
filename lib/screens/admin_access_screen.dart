import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/access_models.dart';
import '../services/access_service.dart';
import '../theme/hunting_theme.dart';

/// Адмін: коди доступу та налаштування (корпоративні домени, пробний період).
class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({super.key});

  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  AccessConfig _cfg = AccessService.config;
  final _trialDays = TextEditingController();
  final _newDomain = TextEditingController();
  final _newAdmin = TextEditingController();
  bool _savingCfg = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _trialDays.text = '${_cfg.trialDays}';
    AccessService.loadConfig(fromServer: true).then((c) {
      if (!mounted) return;
      setState(() {
        _cfg = c;
        _trialDays.text = '${c.trialDays}';
      });
    });
  }

  @override
  void dispose() {
    _trialDays.dispose();
    _newDomain.dispose();
    _newAdmin.dispose();
    super.dispose();
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  // ── Налаштування ───────────────────────────────────────────────────────────

  Future<void> _saveConfig() async {
    final days = int.tryParse(_trialDays.text.trim());
    if (days == null || days < 1) {
      _snack('Пробний період — ціле число днів (мінімум 1)', error: true);
      return;
    }
    // Той, хто зберігає, завжди лишається адміністратором — інакше можна
    // випадково втратити право редагувати налаштування.
    final me = AccessService.currentUser?.email?.trim().toLowerCase();
    final admins = {..._cfg.adminEmails, if (me != null && me.isNotEmpty) me}.toList();
    setState(() => _savingCfg = true);
    try {
      final cfg = _cfg.copyWith(trialDays: days, adminEmails: admins);
      await AccessService.saveConfig(cfg);
      setState(() => _cfg = cfg);
      _snack('Налаштування збережено');
    } catch (e) {
      _snack('Не вдалося зберегти: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingCfg = false);
    }
  }

  void _addDomain() {
    var d = _newDomain.text.trim().toLowerCase();
    if (d.startsWith('@')) d = d.substring(1);
    if (d.isEmpty || !d.contains('.')) {
      _snack('Введіть домен, напр. forestcollege.ukr.education', error: true);
      return;
    }
    if (_cfg.corporateDomains.contains(d)) return;
    setState(() {
      _cfg = _cfg.copyWith(corporateDomains: [..._cfg.corporateDomains, d]);
      _newDomain.clear();
    });
  }

  void _addAdmin() {
    final e = _newAdmin.text.trim().toLowerCase();
    if (e.isEmpty || !e.contains('@')) {
      _snack('Введіть пошту адміністратора', error: true);
      return;
    }
    if (_cfg.adminEmails.contains(e)) return;
    setState(() {
      _cfg = _cfg.copyWith(adminEmails: [..._cfg.adminEmails, e]);
      _newAdmin.clear();
    });
  }

  // ── Коди ───────────────────────────────────────────────────────────────────

  Future<void> _createCode() async {
    final created = await showDialog<AccessCode>(context: context, builder: (_) => const _CreateCodeDialog());
    if (created == null) return;
    try {
      await AccessService.createCode(created);
      _snack('Код ${created.code} створено');
    } on AccessException catch (e) {
      _snack(e.message, error: true);
    } catch (e) {
      _snack('Не вдалося створити код: $e', error: true);
    }
  }

  Future<void> _deleteCode(AccessCode c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Видалити код?'),
        content: Text('Код ${c.code} буде видалено. Ті, хто вже активував його, доступ не втратять.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AccessService.deleteCode(c.code);
      _snack('Код видалено');
    } catch (e) {
      _snack('Помилка: $e', error: true);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Скопійовано: $text');
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Коди доступу'),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showSettings ? Icons.settings : Icons.settings_outlined),
            tooltip: 'Налаштування доступу',
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCode,
        backgroundColor: HuntingTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Створити код'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.brown[100]!, Colors.brown[50]!],
          ),
        ),
        child: StreamBuilder<List<AccessCode>>(
          stream: AccessService.codesStream(),
          builder: (context, snap) {
            final codes = snap.data ?? const <AccessCode>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_showSettings) _settingsCard(),
                _summaryCard(codes),
                const SizedBox(height: 8),
                if (snap.hasError)
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Не вдалося завантажити коди: ${snap.error}', style: TextStyle(color: Colors.red[800])),
                    ),
                  )
                else if (!snap.hasData)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (codes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.vpn_key_off_outlined, size: 48, color: Colors.brown[300]),
                        const SizedBox(height: 8),
                        Text('Кодів ще немає', style: TextStyle(color: Colors.brown[400])),
                      ],
                    ),
                  )
                else
                  ...codes.map(_codeTile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(List<AccessCode> codes) {
    final active = codes.where((c) => c.usable).length;
    final used = codes.fold<int>(0, (s, c) => s + c.usedCount);
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[800]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Корпоративні домени: ${_cfg.corporateDomains.map((d) => '@$d').join(', ')} — безкоштовно.\n'
                'Пробний період: ${_cfg.trialDays} дн. Кодів: ${codes.length}, робочих: $active, активацій: $used.',
                style: TextStyle(fontSize: 12.5, color: Colors.orange[900], height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Налаштування доступу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
            const SizedBox(height: 12),
            const Text('Корпоративні домени (безкоштовно)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _cfg.corporateDomains
                  .map((d) => InputChip(
                        label: Text('@$d'),
                        onDeleted: _cfg.corporateDomains.length > 1
                            ? () => setState(() => _cfg = _cfg.copyWith(corporateDomains: _cfg.corporateDomains.where((x) => x != d).toList()))
                            : null,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newDomain,
                    decoration: const InputDecoration(hintText: 'новий домен, напр. college.edu.ua', isDense: true, border: OutlineInputBorder()),
                    onSubmitted: (_) => _addDomain(),
                  ),
                ),
                IconButton(onPressed: _addDomain, icon: const Icon(Icons.add_circle, color: HuntingTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Пробний період, днів', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _trialDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Адміністратори (можуть створювати коди)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _cfg.adminEmails
                  .map((e) => InputChip(
                        label: Text(e),
                        onDeleted: e == AccessService.currentUser?.email?.toLowerCase()
                            ? null
                            : () => setState(() => _cfg = _cfg.copyWith(adminEmails: _cfg.adminEmails.where((x) => x != e).toList())),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newAdmin,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'пошта адміністратора', isDense: true, border: OutlineInputBorder()),
                    onSubmitted: (_) => _addAdmin(),
                  ),
                ),
                IconButton(onPressed: _addAdmin, icon: const Icon(Icons.add_circle, color: HuntingTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _savingCfg ? null : _saveConfig,
                icon: _savingCfg
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('Зберегти налаштування'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _codeTile(AccessCode c) {
    final status = !c.active
        ? ('Деактивовано', Colors.grey)
        : c.expired
            ? ('Термін минув', Colors.red)
            : c.exhausted
                ? ('Використано', Colors.orange)
                : ('Діє', HuntingTheme.primaryLight);
    final uses = c.maxUses == 0 ? '${c.usedCount}/∞' : '${c.usedCount}/${c.maxUses}';
    final duration = c.durationDays == null ? 'назавжди' : 'на ${c.durationDays} дн.';
    final parts = <String>[
      if (c.note.isNotEmpty) c.note,
      'Активацій: $uses',
      'Доступ $duration',
      if (c.expiresAt != null) 'Дійсний до ${_fmt(c.expiresAt!)}',
      if (c.usedByEmails.isNotEmpty) 'Використали: ${c.usedByEmails.join(', ')}',
    ];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status.$2.withValues(alpha: 0.15),
          child: Icon(Icons.vpn_key, color: status.$2),
        ),
        title: Row(
          children: [
            Text(c.code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: status.$2.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(status.$1, style: TextStyle(fontSize: 11, color: status.$2, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        subtitle: Text(parts.join(' · '), style: const TextStyle(fontSize: 12, height: 1.3)),
        isThreeLine: parts.length > 2,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.copy, size: 20), tooltip: 'Копіювати', onPressed: () => _copy(c.code)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'toggle') {
                  try {
                    await AccessService.setCodeActive(c.code, !c.active);
                  } catch (e) {
                    _snack('Помилка: $e', error: true);
                  }
                } else if (v == 'delete') {
                  _deleteCode(c);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle', child: Text(c.active ? 'Деактивувати' : 'Активувати')),
                const PopupMenuItem(value: 'delete', child: Text('Видалити', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Діалог створення коду.
class _CreateCodeDialog extends StatefulWidget {
  const _CreateCodeDialog();

  @override
  State<_CreateCodeDialog> createState() => _CreateCodeDialogState();
}

class _CreateCodeDialogState extends State<_CreateCodeDialog> {
  final _code = TextEditingController(text: AccessService.generateCode());
  final _note = TextEditingController();
  final _maxUses = TextEditingController(text: '1');
  final _duration = TextEditingController();
  DateTime? _expiresAt;
  bool _forever = true;
  bool _unlimitedUses = false;

  @override
  void dispose() {
    _code.dispose();
    _note.dispose();
    _maxUses.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'До якої дати код можна активувати',
    );
    if (picked != null) setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
  }

  void _submit() {
    final code = AccessService.normalizeCode(_code.text);
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код — мінімум 4 символи'), backgroundColor: Colors.red));
      return;
    }
    final maxUses = _unlimitedUses ? 0 : (int.tryParse(_maxUses.text.trim()) ?? 0);
    if (!_unlimitedUses && maxUses < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Кількість активацій — ціле число ≥ 1'), backgroundColor: Colors.red));
      return;
    }
    int? duration;
    if (!_forever) {
      duration = int.tryParse(_duration.text.trim());
      if (duration == null || duration < 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тривалість доступу — ціле число днів ≥ 1'), backgroundColor: Colors.red));
        return;
      }
    }
    Navigator.pop(
      context,
      AccessCode(
        code: code,
        note: _note.text.trim(),
        maxUses: maxUses,
        durationDays: duration,
        expiresAt: _expiresAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новий код доступу'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Код',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.casino_outlined),
                  tooltip: 'Згенерувати',
                  onPressed: () => setState(() => _code.text = AccessService.generateCode()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Примітка (кому / для чого)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _maxUses,
                    enabled: !_unlimitedUses,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Кількість активацій', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Без ліміту'),
                  selected: _unlimitedUses,
                  onSelected: (v) => setState(() => _unlimitedUses = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _duration,
                    enabled: !_forever,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Доступ на … днів', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Назавжди'),
                  selected: _forever,
                  onSelected: (v) => setState(() => _forever = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _expiresAt == null ? 'Код можна активувати без обмеження в часі' : 'Активація можлива до ${_AdminAccessScreenState._fmt(_expiresAt!)}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_expiresAt == null ? 'Термін' : 'Змінити'),
                ),
                if (_expiresAt != null)
                  IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _expiresAt = null)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
        ElevatedButton(onPressed: _submit, child: const Text('Створити')),
      ],
    );
  }
}
