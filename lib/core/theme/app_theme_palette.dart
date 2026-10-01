import 'package:flutter/material.dart';

import 'glass_theme.dart';

/// Identifiers for each cohesive app color preset.
enum AppThemeId {
  softCream, // Liquid Glass (light)
  amberGlow,
  messagesLight,
  nordicSlate, // Liquid Glass (dark)
  androidDark,
}

extension AppThemeIdLabel on AppThemeId {
  String get displayName => switch (this) {
        AppThemeId.softCream => 'Liquid Glass',
        AppThemeId.amberGlow => 'Amber Glow',
        AppThemeId.messagesLight => 'Messages Light',
        AppThemeId.nordicSlate => 'Glass Dark',
        AppThemeId.androidDark => 'Android Dark',
      };

  static AppThemeId fromStorage(String? value) {
    const legacy = <String, AppThemeId>{
      '0': AppThemeId.messagesLight,
      '1': AppThemeId.androidDark,
      '2': AppThemeId.softCream,
      '3': AppThemeId.messagesLight,
      'Light': AppThemeId.messagesLight,
      'Dark': AppThemeId.androidDark,
      'Purple': AppThemeId.softCream,
      'Green': AppThemeId.messagesLight,
      'Liquid Glass': AppThemeId.softCream,
      'Glass Dark': AppThemeId.nordicSlate,
    };
    if (value != null && legacy.containsKey(value)) return legacy[value]!;
    return AppThemeId.values.firstWhere(
      (id) => id.name == value,
      orElse: () => AppThemeId.messagesLight,
    );
  }
}

/// Semantic color tokens for a single cohesive theme.
/// Hex values live only in [AppThemePalettes] — never in feature widgets.
class AppThemePalette {
  final String name;
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color onBackground;
  final Color onPrimary;
  final Color previewPrimary;
  final Color previewSecondary;

  /// Translucent material tokens; non-null only for the two glass presets.
  final GlassTheme? glass;

  const AppThemePalette({
    required this.name,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.onBackground,
    required this.onPrimary,
    required this.previewPrimary,
    required this.previewSecondary,
    this.glass,
  });

  bool get isDark => brightness == Brightness.dark;
  bool get isGlass => glass != null;

  // ---- Derived tokens ----
  // Glass themes use solid text tiers: alpha-faded text over a translucent,
  // moving backdrop is what made contrast fail before.
  Color get textMain => glass?.textPrimary ?? onBackground;
  Color get textGrey =>
      glass?.textSecondary ??
      onBackground.withValues(alpha: isDark ? 0.62 : 0.55);
  Color get textDisabled =>
      glass?.textDisabled ?? onBackground.withValues(alpha: 0.38);
  Color get icon =>
      glass?.icon ?? onBackground.withValues(alpha: isDark ? 0.55 : 0.45);
  Color get divider =>
      glass?.divider ?? onBackground.withValues(alpha: isDark ? 0.14 : 0.10);
  Color get borderSubtle => divider;
  Color get shadow => Colors.black.withValues(alpha: isDark ? 0.40 : 0.06);
  Color get buttonShadow => primary.withValues(alpha: 0.28);

  Color get accent => primary;

  /// Chat / chrome app bar.
  /// NOTE: never use this as an icon/accent color — only for bar fills.
  Color get header {
    if (isGlass) return glassChrome;
    return isDark
        ? surface
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.16), primary);
  }

  Color get headerForeground =>
      isGlass || isDark ? onBackground : onPrimary;

  Color get chatBackground {
    if (isGlass) return background;
    return isDark
        ? background
        : Color.alphaBlend(primary.withValues(alpha: 0.04), background);
  }

  Color get inputField => isGlass ? glassFill : surface;

  Color get myBubble => isDark
      ? Color.alphaBlend(primary.withValues(alpha: 0.28), surface)
      : Color.alphaBlend(primary.withValues(alpha: 0.16), Colors.white);

  Color get myBubbleText => textMain;
  Color get otherBubble => isGlass ? glassFill : surface;
  Color get otherBubbleText => textMain;

  Color get onSurfaceVariant => textGrey;
  Color get iconMuted => icon;
  Color get error => AppThemePalettes.errorRed;
  Color get success => AppThemePalettes.successGreen;

  Color get shimmerBase => isDark
      ? Color.alphaBlend(onBackground.withValues(alpha: 0.08), surface)
      : Color.alphaBlend(onBackground.withValues(alpha: 0.06), surface);

  Color get shimmerHighlight => isDark
      ? Color.alphaBlend(onBackground.withValues(alpha: 0.14), surface)
      : Color.alphaBlend(Colors.white.withValues(alpha: 0.75), surface);

  // ---- Liquid glass shortcuts (full token set lives on [GlassTheme]) ----
  GlassTheme get _g => glass ?? GlassTheme.liquid;

  Color get glassFill => _g.cardFill;
  Color get glassChrome => _g.chromeFill;
  Color get glassBorder => _g.cardBorder;
  Color get glassHighlight => _g.selectionFill;
  double get glassBlur => isGlass ? _g.cardBlur : 0;
  List<Color> get atmosphere => _g.gradient;
}

/// All preset palettes — hex lives here only.
abstract final class AppThemePalettes {
  /// Light liquid-glass: warm ivory / champagne, muted gold accent.
  static const softCream = AppThemePalette(
    name: 'Liquid Glass',
    brightness: Brightness.light,
    background: Color(0xfff6f3ee),
    surface: Color(0xfffffcf8),
    primary: Color(0xff9a7b4f),
    secondary: Color(0xffebe3d6),
    onBackground: Color(0xff2c2824),
    onPrimary: Color(0xffffffff),
    previewPrimary: Color(0xff9a7b4f),
    previewSecondary: Color(0xffebe3d6),
    glass: GlassTheme.liquid,
  );

  static const amberGlow = AppThemePalette(
    name: 'Amber Glow',
    brightness: Brightness.light,
    background: Color(0xfffffbf6),
    surface: Color(0xffffffff),
    primary: Color(0xffd84315),
    secondary: Color(0xfffff0e0),
    onBackground: Color(0xff3e2723),
    onPrimary: Color(0xffffffff),
    previewPrimary: Color(0xffd84315),
    previewSecondary: Color(0xfffff0e0),
  );

  static const messagesLight = AppThemePalette(
    name: 'Messages Light',
    brightness: Brightness.light,
    background: Color(0xffffffff),
    surface: Color(0xfff0f2f5),
    primary: Color(0xff1fa855),
    secondary: Color(0xffe8f5e9),
    onBackground: Color(0xff111b21),
    onPrimary: Color(0xffffffff),
    previewPrimary: Color(0xff1fa855),
    previewSecondary: Color(0xffc8e6c9),
  );

  /// Dark liquid-glass: warm espresso / graphite, champagne accent.
  static const nordicSlate = AppThemePalette(
    name: 'Glass Dark',
    brightness: Brightness.dark,
    background: Color(0xff12100e),
    surface: Color(0xff1c1916),
    primary: Color(0xffcdb892),
    secondary: Color(0xff2a2622),
    onBackground: Color(0xfff3efe8),
    onPrimary: Color(0xff1c1916),
    previewPrimary: Color(0xffcdb892),
    previewSecondary: Color(0xff2a2622),
    glass: GlassTheme.dark,
  );

  static const androidDark = AppThemePalette(
    name: 'Android Dark',
    brightness: Brightness.dark,
    background: Color(0xff0f0f0f),
    surface: Color(0xff1c1c1c),
    primary: Color(0xff7dcea0),
    secondary: Color(0xff252525),
    onBackground: Color(0xffe6e6e6),
    onPrimary: Color(0xff0f0f0f),
    previewPrimary: Color(0xff7dcea0),
    previewSecondary: Color(0xff252525),
  );

  static AppThemePalette forId(AppThemeId id) => switch (id) {
        AppThemeId.softCream => softCream,
        AppThemeId.amberGlow => amberGlow,
        AppThemeId.messagesLight => messagesLight,
        AppThemeId.nordicSlate => nordicSlate,
        AppThemeId.androidDark => androidDark,
      };

  static const errorRed = Color(0xffc62828);
  static const successGreen = Color(0xff2e7d32);
  static const readReceipt = Color(0xff53bdeb);

  static const avatarSwatches = <Color>[
    Color(0xff5c6bc0),
    Color(0xffef6c00),
    Color(0xff00897b),
    Color(0xff8e24aa),
    Color(0xff546e7a),
    Color(0xffd81b60),
  ];
}
