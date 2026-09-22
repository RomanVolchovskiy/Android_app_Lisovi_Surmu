import 'package:flutter/material.dart';

import '../models/access_models.dart';
import '../services/access_service.dart';
import '../theme/hunting_theme.dart';
import '../widgets/access_code_dialog.dart';

/// Пробний період (або код) завершився — пропонуємо ввести код доступу.
class AccessExpiredScreen extends StatefulWidget {
  final AccessStatus status;

  const AccessExpiredScreen({super.key, required this.status});

  @override
  State<AccessExpiredScreen> createState() => _AccessExpiredScreenState();
}

class _AccessExpiredScreenState extends State<AccessExpiredScreen> {
  bool _busy = false;

  Future<void> _recheck() async {
    setState(() => _busy = true);
    try {
      await AccessService.resolve();
    } on AccessException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AccessService.currentUser?.email ?? '';
    final cfg = AccessService.config;
    final until = widget.status.until;
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
                        Icon(Icons.hourglass_bottom, size: 64, color: Colors.orange[800]),
                        const SizedBox(height: 16),
                        const Text(
                          'Пробний період завершився',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: HuntingTheme.primaryDark),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Безкоштовні ${cfg.trialDays} днів для $email'
                          '${until != null ? ' закінчилися ${_fmt(until)}' : ' вичерпано'}.\n\n'
                          'Щоб продовжити користуватися додатком, введіть код доступу від адміністратора.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[800], height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _busy ? null : () => showAccessCodeDialog(context),
                          icon: const Icon(Icons.vpn_key_outlined),
                          label: const Text('Ввести код доступу'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _recheck,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Перевірити ще раз'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => AccessService.signOut(),
                          child: const Text('Вийти з акаунта'),
                        ),
                        if (widget.status.fromCache) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Немає з’єднання — статус узято з кешу.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
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

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
