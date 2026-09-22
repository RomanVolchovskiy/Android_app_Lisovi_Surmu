import 'package:flutter/material.dart';

import '../models/access_models.dart';
import '../services/access_service.dart';
import '../theme/hunting_theme.dart';

/// Вхід / реєстрація за поштою і паролем.
///
/// Після реєстрації Firebase надсилає лист для підтвердження пошти —
/// далі користувача веде [VerifyEmailScreen] через AccessGate.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Домени й тривалість пробного періоду в підказці внизу — з Firestore.
    AccessService.loadConfig().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await AccessService.register(_email.text, _password.text);
      } else {
        await AccessService.signIn(_email.text, _password.text);
      }
      // Далі AccessGate сам перемкне екран за станом користувача.
    } on AccessException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Помилка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Введіть пошту, щоб скинути пароль');
      return;
    }
    setState(() => _busy = true);
    try {
      await AccessService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Лист для зміни пароля надіслано на $email'), backgroundColor: Colors.green),
        );
      }
    } on AccessException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = AccessService.config;
    final domains = cfg.corporateDomains.map((d) => '@$d').join(', ');
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icons/icon1.png', height: 96),
                    const SizedBox(height: 12),
                    const Text(
                      'Лісові Сурми',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Мисливські сигнали',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _register ? 'Реєстрація' : 'Вхід',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: HuntingTheme.primaryDark),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Електронна пошта',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'Введіть пошту';
                                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Некоректна адреса';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _busy ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Пароль',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) {
                                  if ((v ?? '').isEmpty) return 'Введіть пароль';
                                  if (_register && v!.length < 6) return 'Мінімум 6 символів';
                                  return null;
                                },
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
                              ],
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _busy ? null : _submit,
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                child: _busy
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(_register ? 'Зареєструватися' : 'Увійти', style: const TextStyle(fontSize: 16)),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                          _register = !_register;
                                          _error = null;
                                        }),
                                child: Text(_register ? 'Уже є акаунт? Увійти' : 'Немає акаунта? Зареєструватися'),
                              ),
                              if (!_register)
                                TextButton(
                                  onPressed: _busy ? null : _forgotPassword,
                                  child: const Text('Забули пароль?'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _hint(Icons.school, 'Корпоративна пошта коледжу ($domains) — безкоштовно й без обмежень.'),
                          const SizedBox(height: 6),
                          _hint(Icons.timer_outlined, 'Інші користувачі — безкоштовно ${cfg.trialDays} днів після реєстрації.'),
                          const SizedBox(height: 6),
                          _hint(Icons.vpn_key_outlined, 'Код доступу від адміністратора відкриває додаток після пробного періоду.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: HuntingTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3))),
        ],
      );
}
