import 'package:flutter/material.dart';

import '../models/access_models.dart';
import '../services/access_service.dart';
import '../theme/hunting_theme.dart';
import '../widgets/access_code_dialog.dart';

/// Акаунт користувача: пошта, стан доступу, введення коду, вихід.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await AccessService.resolve();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Статус оновлено'), backgroundColor: Colors.green),
        );
      }
    } on AccessException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Вийти з акаунта?'),
        content: const Text('Для входу знову знадобляться пошта й пароль.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Вийти'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AccessService.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = AccessService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Мій акаунт')),
      body: ValueListenableBuilder<AccessStatus?>(
        valueListenable: AccessService.status,
        builder: (context, status, _) {
          final info = _describe(status);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: HuntingTheme.primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(user?.email ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(user?.emailVerified == true ? 'Пошту підтверджено' : 'Пошту не підтверджено'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: info.color.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(info.icon, size: 40, color: info.color),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: info.color)),
                            const SizedBox(height: 4),
                            Text(info.subtitle, style: TextStyle(color: Colors.grey[800], height: 1.3)),
                            if (status?.fromCache == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Без мережі — дані з кешу', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (status?.kind != AccessKind.corporate)
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => showAccessCodeDialog(context),
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Ввести код доступу'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text('Оновити статус'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy || user?.email == null
                    ? null
                    : () async {
                        try {
                          await AccessService.resetPassword(user!.email!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Лист для зміни пароля надіслано на ${user.email}'), backgroundColor: Colors.green),
                            );
                          }
                        } on AccessException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
                          }
                        }
                      },
                icon: const Icon(Icons.password),
                label: const Text('Змінити пароль'),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Вийти з акаунта', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  _StatusInfo _describe(AccessStatus? s) {
    if (s == null) {
      return const _StatusInfo(Icons.hourglass_empty, Colors.grey, 'Перевірка…', 'Стан доступу ще не визначено');
    }
    switch (s.kind) {
      case AccessKind.corporate:
        return const _StatusInfo(Icons.verified, HuntingTheme.primaryLight, 'Корпоративний доступ',
            'Пошта коледжу — додаток безкоштовний без обмежень');
      case AccessKind.code:
        return _StatusInfo(Icons.vpn_key, Colors.indigo, 'Доступ за кодом',
            s.until == null ? 'Без обмеження терміну' : 'Діє до ${_fmt(s.until!)} (${s.daysLeft} дн.)');
      case AccessKind.trial:
        return _StatusInfo(Icons.timer_outlined, Colors.orange[800]!, 'Пробний період',
            'Залишилось ${s.daysLeft} дн. — до ${_fmt(s.until!)}. Далі потрібен код доступу');
      case AccessKind.expired:
        return _StatusInfo(Icons.block, Colors.red[700]!, 'Доступ завершено',
            'Введіть код доступу від адміністратора');
    }
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _StatusInfo(this.icon, this.color, this.title, this.subtitle);
}
