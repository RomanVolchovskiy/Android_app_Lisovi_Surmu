import 'package:flutter/material.dart';
import 'package:hunting_signals/screens/admin_panel_screen.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hunting_models.dart';

class AdminService {
  static const String adminPassword = '1488';
  static const String _prefKey = 'admin_password_required';
  static bool _isAdminAuthenticated = false;
  static bool _passwordRequired = true;

  static bool get isAdminAuthenticated => _isAdminAuthenticated;
  static bool get passwordRequired => _passwordRequired;

  /// Завантажує налаштування пароля зі сховища
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _passwordRequired = prefs.getBool(_prefKey) ?? true;
  }

  /// Вмикає або вимикає захист паролем
  static Future<void> setPasswordRequired(bool value) async {
    _passwordRequired = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  static Future<bool> authenticate(String password) async {
    _isAdminAuthenticated = password == adminPassword;
    return _isAdminAuthenticated;
  }

  static void logout() {
    _isAdminAuthenticated = false;
  }

  /// Add new hunting signal to local storage
  static Future<bool> addHuntingSignal(HuntingSignal signal) async {
    try {
      HuntingDataService.addSignal(signal);
      return true;
    } catch (e) {
      debugPrint('Error adding hunting signal: $e');
      return false;
    }
  }

  /// Add new educational material to local storage
  static Future<bool> addEducationalMaterial(EducationMaterial material) async {
    try {
      HuntingDataService.addEducationMaterial(material);
      return true;
    } catch (e) {
      debugPrint('Error adding educational material: $e');
      return false;
    }
  }

  static Future<void> showAdminLoginDialog(BuildContext context) async {
    await loadSettings();

    // Якщо пароль вимкнено — одразу відкриваємо панель
    if (!_passwordRequired) {
      _isAdminAuthenticated = true;
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
        );
      }
      return;
    }

    final TextEditingController passwordController = TextEditingController();

    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Вхід адміністратора'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Введіть пароль адміністратора:'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text;
                if (await authenticate(password)) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } else {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Неправильний пароль!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Увійти'),
            ),
          ],
        );
      },
    );

    if (authenticated == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      );
    }
  }

  /// Show success message
  static void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Show error message
  static void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}