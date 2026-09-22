import 'dart:async';

import 'package:flutter/material.dart';

import '../models/access_models.dart';
import '../services/access_service.dart';
import '../theme/hunting_theme.dart';

/// Очікування підтвердження пошти після реєстрації.
///
/// Кожні кілька секунд перечитує користувача; щойно пошта підтверджена —
/// викликає [onVerified] (AccessGate перевіряє доступ і пускає в додаток).
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;

  const VerifyEmailScreen({super.key, required this.email, required this.onVerified});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _poll;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_busy) return;
    if (!silent) setState(() => _busy = true);
    final ok = await AccessService.reloadVerified();
    if (!mounted) return;
    if (ok) {
      _poll?.cancel();
      widget.onVerified();
      return;
    }
    if (!silent) {
      setState(() {
        _busy = false;
        _message = 'Пошта ще не підтверджена. Відкрийте лист і натисніть посилання';
        _messageIsError = true;
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await AccessService.sendVerification();
      setState(() {
        _message = 'Лист надіслано ще раз на ${widget.email}';
        _messageIsError = false;
      });
    } on AccessException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HuntingTheme.primaryDark, HuntingTheme.primaryColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.mark_email_unread_outlined, size: 64, color: HuntingTheme.primaryColor),
                        const SizedBox(height: 16),
                        const Text(
                          'Підтвердіть пошту',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: HuntingTheme.primaryDark),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ми надіслали лист на\n${widget.email}\n\nВідкрийте його й натисніть посилання. '
                          'Після цього додаток відкриється автоматично.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[800], height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Не бачите листа? Перевірте теку «Спам».',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _messageIsError ? Colors.red[700] : Colors.green[700], fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _busy ? null : () => _check(),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Я підтвердив(ла) пошту'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _resend,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Надіслати лист ще раз'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => AccessService.signOut(),
                          child: const Text('Увійти з іншою поштою'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
