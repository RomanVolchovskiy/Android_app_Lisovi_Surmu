import 'package:flutter/material.dart';

class HuntingTheme {
  static const Color primaryColor = Color(0xFF2F4F2F);
  static const Color primaryDark = Color(0xFF1C3A1C);
  static const Color primaryLight = Color(0xFF228B22);
  static const Color accentColor = Color(0xFFFFD700);
  static const Color backgroundColor = Color(0xFFFAF0E6);

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// Тема екранів дихального тренажера. Темний варіант діє лише всередині
  /// тренажера (за системним налаштуванням) — решта застосунку світла.
  static ThemeData breathGym(Brightness brightness) {
    if (brightness == Brightness.light) {
      return theme.copyWith(extensions: const [BreathGymPalette.light]);
    }
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      secondary: accentColor,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      extensions: const [BreathGymPalette.dark],
    );
  }
}

/// Кольори фаз дихального тренажера. [on*] — колір тексту поверх фази
/// (контраст ≥ 4.5:1 в обох варіантах).
@immutable
class BreathGymPalette extends ThemeExtension<BreathGymPalette> {
  final Color inhale, exhale, hold, action, rest;
  final Color onPhase;

  const BreathGymPalette({
    required this.inhale,
    required this.exhale,
    required this.hold,
    required this.action,
    required this.rest,
    required this.onPhase,
  });

  static const light = BreathGymPalette(
    inhale: Color(0xFF1565C0),
    exhale: Color(0xFF2E6B30),
    hold: Color(0xFF6D4C41),
    action: Color(0xFFB3261E),
    rest: Color(0xFF5F6368),
    onPhase: Colors.white,
  );

  static const dark = BreathGymPalette(
    inhale: Color(0xFF90CAF9),
    exhale: Color(0xFFA5D6A7),
    hold: Color(0xFFBCAAA4),
    action: Color(0xFFFFB4AB),
    rest: Color(0xFFC4C7C5),
    onPhase: Color(0xFF111111),
  );

  static BreathGymPalette of(BuildContext context) =>
      Theme.of(context).extension<BreathGymPalette>() ?? light;

  @override
  BreathGymPalette copyWith({Color? inhale, Color? exhale, Color? hold, Color? action, Color? rest, Color? onPhase}) =>
      BreathGymPalette(
        inhale: inhale ?? this.inhale,
        exhale: exhale ?? this.exhale,
        hold: hold ?? this.hold,
        action: action ?? this.action,
        rest: rest ?? this.rest,
        onPhase: onPhase ?? this.onPhase,
      );

  @override
  BreathGymPalette lerp(BreathGymPalette? other, double t) {
    if (other == null) return this;
    return BreathGymPalette(
      inhale: Color.lerp(inhale, other.inhale, t)!,
      exhale: Color.lerp(exhale, other.exhale, t)!,
      hold: Color.lerp(hold, other.hold, t)!,
      action: Color.lerp(action, other.action, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
      onPhase: Color.lerp(onPhase, other.onPhase, t)!,
    );
  }
}