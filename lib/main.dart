import 'package:flutter/material.dart';
import 'package:hunting_signals/services/storage_manager.dart';
import 'screens/main_navigation.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/add_signal_screen.dart';
import 'screens/add_education_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/education_screen.dart';
import 'screens/settings_storage_screen.dart';
import 'theme/hunting_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage (choose your preferred storage type)
  await _initializeStorage();

  runApp(const HuntingSignalsApp());
}

/// Initialize storage - you can choose between different storage options
Future<void> _initializeStorage() async {
  await StorageManager.initialize(storageType: StorageType.local);
}

/// Main application class
class HuntingSignalsApp extends StatelessWidget {
  const HuntingSignalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мисливські Сигнали',
      debugShowCheckedModeBanner: false,
      theme: HuntingTheme.theme,
      home: const MainNavigation(),
      routes: {
        '/home': (context) => const MainNavigation(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-panel': (context) => const AdminPanelScreen(),
        '/add-signal': (context) => const AddSignalScreen(),
        '/add-education': (context) => const AddEducationScreen(),
        '/categories': (context) => const CategoriesScreen(),
        '/education': (context) => const EducationScreen(),
        '/settings': (context) => const SettingsStorageScreen(),
      },
    );
  }
}
