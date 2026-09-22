import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/screens/categories_screen.dart';
import 'package:hunting_signals/screens/events_screen.dart';
import 'package:hunting_signals/screens/education_screen.dart';
import 'package:hunting_signals/screens/favorites_screen.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/models/access_models.dart';
import 'package:hunting_signals/screens/account_screen.dart';
import 'package:hunting_signals/services/access_service.dart';
import 'package:hunting_signals/services/admin_service.dart';
import 'package:hunting_signals/utils/platform_utils.dart';

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

  // Екрани для iOS-вкладок — у порядку CupertinoTabBar нижче
  // (Сигнали, Події, Навчання, Обране).
  List<Widget> get _screens => [
        CategoriesScreen(key: ValueKey(_categoriesRefreshToken)),
        const EventsScreen(),
        const EducationScreen(),
        const FavoritesScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    if (isIOS) {
      return _buildIOSLayout();
    }
    return _buildAndroidLayout();
  }

  /// Смужка «пробний період: N днів» / «код діє до …» — лише коли доступ
  /// обмежений у часі, щоб користувач не втратив його несподівано.
  Widget _accessBanner(BuildContext context) {
    return ValueListenableBuilder<AccessStatus?>(
      valueListenable: AccessService.status,
      builder: (context, status, _) {
        if (status == null || status.until == null || !status.allowed) return const SizedBox.shrink();
        final trial = status.kind == AccessKind.trial;
        if (!trial && status.daysLeft > 7) return const SizedBox.shrink();
        final text = trial
            ? 'Пробний період: залишилось ${status.daysLeft} дн.'
            : 'Доступ за кодом закінчується через ${status.daysLeft} дн.';
        final color = status.daysLeft <= 3 ? Colors.red[700]! : Colors.orange[800]!;
        return Material(
          color: color.withValues(alpha: 0.12),
          child: InkWell(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600))),
                  Text('Ввести код', style: TextStyle(fontSize: 12.5, color: color, decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIOSLayout() {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: HuntingTheme.primaryColor,
        inactiveColor: CupertinoColors.inactiveGray,
        backgroundColor: CupertinoColors.systemBackground,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.music_note_2),
            activeIcon: Icon(CupertinoIcons.music_note_2),
            label: 'Сигнали',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            activeIcon: Icon(CupertinoIcons.calendar_today),
            label: 'Події',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: 'Навчання',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.heart),
            activeIcon: Icon(CupertinoIcons.heart_fill),
            label: 'Обране',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            return CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                middle: Text(
                  _titles[index],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: HuntingTheme.primaryColor,
                brightness: Brightness.dark,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context, rootNavigator: true).push(
                        CupertinoPageRoute(builder: (_) => const AccountScreen()),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_crop_circle,
                        color: CupertinoColors.white,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => AdminService.showAdminLoginDialog(context),
                      child: const Icon(
                        CupertinoIcons.person_badge_plus,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              ),
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
                  child: Column(
                    children: [
                      _accessBanner(context),
                      Expanded(child: _screens[index]),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAndroidLayout() {
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
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
            tooltip: 'Мій акаунт',
          ),
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
          _accessBanner(context),
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
