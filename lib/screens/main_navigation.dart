import 'package:flutter/material.dart';
import 'package:hunting_signals/screens/categories_screen.dart';
import 'package:hunting_signals/screens/events_screen.dart';
import 'package:hunting_signals/screens/education_screen.dart';
import 'package:hunting_signals/screens/favorites_screen.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/services/admin_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CategoriesScreen(),
    EventsScreen(),
    EducationScreen(),
    FavoritesScreen(),
  ];

  final List<String> _titles = [
    'Мисливські Сигнали',
    'Мисливські Події',
    'Навчальні Матеріали',
    'Обрані Сигнали',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        shadowColor: HuntingTheme.primaryDark.withValues(alpha: 0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              AdminService.showAdminLoginDialog(context);
            },
            tooltip: 'Адміністратор',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              HuntingTheme.backgroundColor,
              HuntingTheme.primaryLight.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: HuntingTheme.primaryDark,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.surround_sound, size: 24),
              label: 'Сигнали',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event, size: 24),
              label: 'Події',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school, size: 24),
              label: 'Навчання',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite, size: 24),
              label: 'Обране',
            ),
          ],
        ),
      ),
    );
  }
}