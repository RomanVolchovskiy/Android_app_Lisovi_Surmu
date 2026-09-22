import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/access_models.dart';
import '../screens/access_expired_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/verify_email_screen.dart';
import '../services/access_service.dart';
import '../theme/hunting_theme.dart';

/// Пускає в додаток лише користувача з правом доступу.
///
/// Послідовність: не увійшов → [AuthScreen]; пошта не підтверджена →
/// [VerifyEmailScreen]; далі [AccessService.resolve]: доступ є → [child],
/// немає → [AccessExpiredScreen] із введенням коду.
class AccessGate extends StatefulWidget {
  final Widget child;

  const AccessGate({super.key, required this.child});

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  String? _resolvingFor;
  String? _error;

  void _ensureResolved(User user) {
    if (_resolvingFor == user.uid || AccessService.status.value != null) return;
    _resolvingFor = user.uid;
    _error = null;
    // Не з build(): resolve() оновлює ValueNotifier, а це перебудова.
    Future.microtask(() => AccessService.resolve().catchError((e) {
          if (mounted) setState(() => _error = e is AccessException ? e.message : 'Помилка перевірки доступу: $e');
          return const AccessStatus(AccessKind.expired);
        }));
  }

  void _retry() {
    _resolvingFor = null;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AccessService.authChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Splash();
        final user = snap.data;
        if (user == null) {
          _resolvingFor = null;
          return const AuthScreen();
        }
        if (!user.emailVerified) {
          return VerifyEmailScreen(
            key: ValueKey('verify-${user.uid}'),
            email: user.email ?? '',
            onVerified: () {
              _resolvingFor = null;
              AccessService.status.value = null;
              setState(() {});
            },
          );
        }
        return ValueListenableBuilder<AccessStatus?>(
          valueListenable: AccessService.status,
          builder: (context, status, _) {
            if (status == null) {
              if (_error != null) return _Splash(error: _error, onRetry: _retry);
              _ensureResolved(user);
              return const _Splash(message: 'Перевірка доступу…');
            }
            if (status.allowed) return widget.child;
            return AccessExpiredScreen(status: status);
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  final String? message;
  final String? error;
  final VoidCallback? onRetry;

  const _Splash({this.message, this.error, this.onRetry});

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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/icon1.png', height: 110),
              const SizedBox(height: 20),
              if (error == null) ...[
                const CircularProgressIndicator(color: HuntingTheme.accentColor),
                if (message != null) ...[
                  const SizedBox(height: 14),
                  Text(message!, style: const TextStyle(color: Colors.white70)),
                ],
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Спробувати ще раз'),
                ),
                TextButton(
                  onPressed: () => AccessService.signOut(),
                  child: const Text('Вийти', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
