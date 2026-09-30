import 'package:flutter/material.dart';
import 'app_colors.dart'; // adjust the path to where your AppColors file is

// One complete theme: every color the app needs in one place.
class AppThemePreset {
  final String name;
  final Brightness brightness;
  final Color background; // screen background
  final Color surface; // app bar, cards, input bar
  final Color primary; // buttons, links, accents
  final Color onPrimary; // text/icons on top of primary
  final Color textMain; // headings and normal text
  final Color textGrey; // subtitle text
  final Color icon; // icons and hint text
  final Color divider;
  final Color myBubble; // chat bubble of the current user
  final Color myBubbleText;
  final Color otherBubble; // chat bubble of the other person
  final Color otherBubbleText;
  final Color header; // top bar of chat screen (old kHeaderColor)
  final Color accent; // send button, + button (old kAccentColor)
  final Color chatBackground; // chat screen background
  final Color inputField; // fill of the typing box
  const AppThemePreset({
    required this.name,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.textMain,
    required this.textGrey,
    required this.icon,
    required this.divider,
    required this.myBubble,
    required this.myBubbleText,
    required this.otherBubble,
    required this.otherBubbleText,
    required this.header,
    required this.accent,
    required this.chatBackground,
    required this.inputField,
  });

  // Builds a normal Flutter ThemeData from this preset.
  ThemeData toThemeData() {
    final base = ThemeData(brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      iconTheme: IconThemeData(color: icon),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: textMain,

      ),
      // Makes all default text follow the theme's text color.
      textTheme: base.textTheme.apply(
        bodyColor: textMain,
        displayColor: textMain,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textMain,
        iconTheme: IconThemeData(color: icon),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
    );
  }
}

// The 4 complete themes shown on the Theme page.
final List<AppThemePreset> appPresets = [
  // 1. Light: uses your existing AppColors so the current look stays the same
  AppThemePreset(
    name: 'Light',
    brightness: Brightness.light,
    background: AppColors.background,
    surface: Colors.white,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    textMain: AppColors.textDark,
    textGrey: AppColors.textGrey,
    icon: AppColors.icon,
    divider: AppColors.divider,
    myBubble: const Color(0xFFDCF8C6), // same light green bubble as before
    myBubbleText: AppColors.textDark,
    otherBubble: Colors.white,
    otherBubbleText: AppColors.textDark,
    header: const Color(0xFF075E54),
    accent: const Color(0xFF25D366),
    chatBackground: const Color(0xFFF0F2F5),
    inputField: const Color(0xFFF0F2F5),
  ),
  // 2. Dark
  AppThemePreset(
    name: 'Dark',
    brightness: Brightness.dark,
    background: const Color(0xFF121212),
    surface: const Color(0xFF1E1E1E),
    primary: const Color(0xFF3CB67C),
    onPrimary: Colors.white,
    textMain: const Color(0xFFF3F4F6),
    textGrey: const Color(0xFF9CA3AF),
    icon: const Color(0xFF9CA3AF),
    divider: const Color(0xFF2C2C2C),
    myBubble: const Color(0xFF2E7D5B),
    myBubbleText: Colors.white,
    otherBubble: const Color(0xFF262626),
    otherBubbleText: const Color(0xFFF3F4F6),
    header: const Color(0xFF0B6B5D),
    accent: const Color(0xFF25D366),
    chatBackground: const Color(0xFF0B141A),
    inputField: const Color(0xFF2A2A2A),
  ),
  // 3. Purple
  AppThemePreset(
    name: 'Purple',
    brightness: Brightness.light,
    background: const Color(0xFFF5F3FF),
    surface: Colors.white,
    primary: const Color(0xFF8B5CF6),
    onPrimary: Colors.white,
    textMain: const Color(0xFF1E1B4B),
    textGrey: const Color(0xFF6B7280),
    icon: const Color(0xFF7C6FA8),
    divider: const Color(0xFFDDD6FE),
    myBubble: const Color(0xFF8B5CF6),
    myBubbleText: Colors.white,
    otherBubble: const Color(0xFFEDE9FE),
    otherBubbleText: const Color(0xFF1E1B4B),
    header: const Color(0xFF6D28D9),
    accent: const Color(0xFF8B5CF6),
    chatBackground: const Color(0xFFF5F3FF),
    inputField: const Color(0xFFF5F3FF),
  ),
  // 4. Green
  AppThemePreset(
    name: 'Green',
    brightness: Brightness.light,
    background: const Color(0xFFF0FDF4),
    surface: Colors.white,
    primary: const Color(0xFF16A34A),
    onPrimary: Colors.white,
    textMain: const Color(0xFF052E16),
    textGrey: const Color(0xFF4B5563),
    icon: const Color(0xFF4D7C5F),
    divider: const Color(0xFFBBF7D0),
    myBubble: const Color(0xFF16A34A),
    myBubbleText: Colors.white,
    otherBubble: const Color(0xFFDCFCE7),
    otherBubbleText: const Color(0xFF052E16),
    header: const Color(0xFF166534),
    accent: const Color(0xFF22C55E),
    chatBackground: const Color(0xFFF0FDF4),
    inputField: const Color(0xFFF0FDF4),
  ),
];