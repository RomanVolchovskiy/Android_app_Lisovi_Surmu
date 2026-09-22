import 'package:flutter/material.dart';

import '../models/access_models.dart';
import '../services/access_service.dart';

/// Діалог введення коду доступу. Повертає `true`, якщо код активовано.
Future<bool> showAccessCodeDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const _AccessCodeDialog(),
  );
  return result ?? false;
}

class _AccessCodeDialog extends StatefulWidget {
  const _AccessCodeDialog();

  @override
  State<_AccessCodeDialog> createState() => _AccessCodeDialogState();
}

class _AccessCodeDialogState extends State<_AccessCodeDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = AccessService.normalizeCode(_controller.text);
    if (code.isEmpty) {
      setState(() => _error = 'Введіть код');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await AccessService.redeemCode(code);
      if (!mounted) return;
      if (!status.allowed) {
        setState(() => _error = 'Код прийнято, але доступ уже завершився');
        return;
      }
      Navigator.pop(context, true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(status.until == null
              ? 'Код активовано — доступ без обмежень'
              : 'Код активовано — доступ на ${status.daysLeft} дн.'),
          backgroundColor: Colors.green,
        ),
      );
    } on AccessException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Помилка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key_outlined),
          SizedBox(width: 8),
          Text('Код доступу'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Введіть код, який вам надав адміністратор.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _busy ? null : _activate(),
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'ABCD2345',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Скасувати')),
        ElevatedButton(
          onPressed: _busy ? null : _activate,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Активувати'),
        ),
      ],
    );
  }
}
