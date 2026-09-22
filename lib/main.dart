import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:hunting_signals/services/access_service.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/media_cache_service.dart';
import 'package:hunting_signals/services/storage_manager.dart';
import 'package:hunting_signals/utils/platform_utils.dart';
import 'screens/main_navigation.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/add_signal_screen.dart';
import 'screens/add_education_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/education_screen.dart';
import 'screens/settings_storage_screen.dart';
import 'theme/hunting_theme.dart';
import 'widgets/access_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await StorageManager.initialize(storageType: StorageType.firebase);
    // Домени й тривалість пробного періоду для екрана входу (не блокує).
    AccessService.loadConfig();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    await StorageManager.initialize(storageType: StorageType.local);
  }

  await HuntingDataService.loadPersistedData();
  // Попереднє завантаження медіафайлів у фоні (не блокує запуск)
  Future(() async {
    final signals = await HuntingDataService.getAllSignals();
    await MediaCacheService.preloadSignals(signals);
  });
  runApp(const HuntingSignalsApp());
}

class HuntingSignalsApp extends StatelessWidget {
  const HuntingSignalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (isIOS) {
      return _buildCupertinoApp();
    }
    return _buildMaterialApp();
  }

  Widget _buildCupertinoApp() {
    return MaterialApp(
      title: 'Лісові Сурми',
      debugShowCheckedModeBanner: false,
      theme: HuntingTheme.theme.copyWith(
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
      home: const AccessGate(child: MainNavigation()),
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
      home: const AccessGate(child: MainNavigation()),
      routes: {
        '/home': (context) => const MainNavigation(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-panel': (context) => const AdminPanelScreen(),
        '/add-signal': (context) => const AddSignalScreen(),
        '/categories': (context) => const CategoriesScreen(),
        '/education': (context) => const EducationScreen(),
        '/settings': (context) => const SettingsStorageScreen(),
      },
    );
  }
}
