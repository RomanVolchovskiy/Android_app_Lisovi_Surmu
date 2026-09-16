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
  int _categoriesRefreshToken = 0;

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0: return CategoriesScreen(key: ValueKey(_categoriesRefreshToken));
      case 1: return const EducationScreen();
      case 2: return const EventsScreen();
      case 3: return const FavoritesScreen();
      default: return CategoriesScreen(key: ValueKey(_categoriesRefreshToken));
    }
  }

  final List<String> _titles = [
    'Мисливські Сигнали',
    'Навчальні Матеріали',
    'Мисливські події',
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
            onPressed: () async {
              await AdminService.showAdminLoginDialog(context);
              if (mounted) setState(() => _categoriesRefreshToken++);
            },
            tooltip: 'Адміністратор',
          ),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) => Column(
        children: [
          // ── Банер ──────────────────────────────────────────────────────
          if (orientation == Orientation.portrait)
            Stack(
              children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 0.8,
                    child: Image.asset(
                      'assets/images/Лісові сурми на заході сонця.png',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.15)),
                ),
                Positioned(
                  left: 10,
                  top: 8,
                  child: Image.asset(
                    'assets/icons/icon1.png',
                    height: 72,
                    width: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/Лісові сурми на заході сонця.png',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.15)),
                  Positioned(
                    left: 10,
                    top: 8,
                    child: Image.asset(
                      'assets/icons/icon1.png',
                      height: 130,
                      width: 130,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          // ── Вміст екрану ───────────────────────────────────────────────
          Expanded(
            child: Container(
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
                top: false,
                child: _buildScreen(),
              ),
            ),
          ),
        ],
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
              icon: Icon(Icons.school, size: 24),
              label: 'Навчання',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event, size: 24),
              label: 'Події',
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