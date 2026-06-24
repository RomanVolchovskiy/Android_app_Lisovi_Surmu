import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
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
  await Firebase.initializeApp();
  await StorageManager.initialize(storageType: StorageType.firebase);
  await HuntingDataService.loadPersistedData();
  runApp(const HuntingSignalsApp());
}

class HuntingSignalsApp extends StatelessWidget {
  const HuntingSignalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoApp();
    }
    return _buildMaterialApp();
  }

  Widget _buildCupertinoApp() {
    return MaterialApp(
      title: 'Лісові Сурми',
      debugShowCheckedModeBanner: false,
      theme: HuntingTheme.theme.copyWith(
        // Адаптація Material теми для iOS — округліші кути, iOS-стиль кнопок
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        cupertinoOverrideTheme: const CupertinoThemeData(
          primaryColor: HuntingTheme.primaryColor,
          barBackgroundColor: HuntingTheme.primaryColor,
          textTheme: CupertinoTextThemeData(
            primaryColor: HuntingTheme.primaryColor,
          ),
        ),
      ),
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

  Widget _buildMaterialApp() {
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
