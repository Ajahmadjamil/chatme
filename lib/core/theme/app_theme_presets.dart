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
  // 1. Light: your original look (uses your existing AppColors)
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
    myBubble: const Color(0xFFDCF8C6),
    myBubbleText: AppColors.textDark,
    otherBubble: Colors.white,
    otherBubbleText: AppColors.textDark,
    header: const Color(0xFF075E54),
    accent: const Color(0xFF25D366),
    chatBackground: const Color(0xFFF0F2F5),
    inputField: const Color(0xFFF0F2F5),
  ),

  // 2. Midnight (Dark): deep blue-grey with a fresh teal accent
  AppThemePreset(
    name: 'Midnight',
    brightness: Brightness.dark,
    background: const Color(0xFF111B21),
    surface: const Color(0xFF1F2C34),
    primary: const Color(0xFF00A884),
    onPrimary: Colors.white,
    textMain: const Color(0xFFE9EDEF),
    textGrey: const Color(0xFF8696A0),
    icon: const Color(0xFF8696A0),
    divider: const Color(0xFF2A3942),
    myBubble: const Color(0xFF005C4B),
    myBubbleText: const Color(0xFFE9EDEF),
    otherBubble: const Color(0xFF202C33),
    otherBubbleText: const Color(0xFFE9EDEF),
    header: const Color(0xFF0E4A3F),
    accent: const Color(0xFF00A884),
    chatBackground: const Color(0xFF0B141A),
    inputField: const Color(0xFF2A3942),
  ),

  // 3. Royal Purple: soft lavender screens, rich violet buttons
  AppThemePreset(
    name: 'Royal Purple',
    brightness: Brightness.light,
    background: const Color(0xFFF6F3FF),
    surface: Colors.white,
    primary: const Color(0xFF7C3AED),
    onPrimary: Colors.white,
    textMain: const Color(0xFF1E1B4B),
    textGrey: const Color(0xFF6B6490),
    icon: const Color(0xFF8B82B8),
    divider: const Color(0xFFE4DDFB),
    myBubble: const Color(0xFF7C3AED),
    myBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: const Color(0xFF1E1B4B),
    header: const Color(0xFF5B21B6),
    accent: const Color(0xFF8B5CF6),
    chatBackground: const Color(0xFFEFE9FF),
    inputField: const Color(0xFFF1ECFF),
  ),

  // 4. Forest Green: fresh mint screens, deep emerald buttons
  AppThemePreset(
    name: 'Forest Green',
    brightness: Brightness.light,
    background: const Color(0xFFF1F8F4),
    surface: Colors.white,
    primary: const Color(0xFF047857),
    onPrimary: Colors.white,
    textMain: const Color(0xFF0F2A20),
    textGrey: const Color(0xFF4B6358),
    icon: const Color(0xFF6B8A7A),
    divider: const Color(0xFFD3E8DD),
    myBubble: const Color(0xFF047857),
    myBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: const Color(0xFF0F2A20),

    header: const Color(0xFF065F46),
    accent: const Color(0xFF10B981),
    chatBackground: const Color(0xFFE3F1E9),
    inputField: const Color(0xFFE8F3ED),
  ),
];