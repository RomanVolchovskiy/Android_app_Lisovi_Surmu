import 'package:flutter/material.dart';
import 'package:hunting_signals/screens/admin_panel_screen.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/access_service.dart';
import '../models/hunting_models.dart';

class AdminService {
  /// Чи може поточний користувач відкрити адмін-панель — див.
  /// [AccessService.isAdminUser]. Пароля більше немає: доступ визначає акаунт
  /// Firebase Auth, і ті самі правила Firestore/Storage перевіряють запис.
  static bool get isAdmin => AccessService.isAdminUser;

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

  /// Відкриває адмін-панель, якщо поточний користувач — адміністратор.
  static Future<void> openAdminPanel(BuildContext context) async {
    // Список адміністраторів міг змінитися — беремо свіжий із сервера.
    await AccessService.loadConfig(fromServer: true);
    if (!context.mounted) return;
    if (!AccessService.isAdminUser) {
      showErrorMessage(context, 'Адмін-панель доступна лише адміністраторам');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
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