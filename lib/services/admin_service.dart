import 'package:flutter/material.dart';
import 'package:hunting_signals/screens/admin_panel_screen.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import '../models/hunting_models.dart';

class AdminService {
  static const String adminPassword = '1488';
  static bool _isAdminAuthenticated = false;

  static bool get isAdminAuthenticated => _isAdminAuthenticated;

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

  static void showAdminLoginDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text;
                if (await authenticate(password)) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AdminPanelScreen(),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
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