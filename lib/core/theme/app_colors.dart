import 'package:flutter/material.dart';

import 'app_theme_palette.dart';
import 'theme_service.dart';

/// App-wide color facade. Feature code must use these getters — never raw hex.
class AppColors {
  AppColors._();

  static AppThemePalette get _p => ThemeService.instance.palette;

  // Core
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get primary => _p.primary;
  static Color get secondary => _p.secondary;
  static Color get onPrimary => _p.onPrimary;
  static Color get onBackground => _p.onBackground;

  // Text / icons
  static Color get textMain => _p.textMain;
  static Color get textDark => _p.textMain;
  static Color get textGrey => _p.textGrey;
  static Color get textDisabled => _p.textDisabled;
  static Color get icon => _p.icon;
  static Color get divider => _p.divider;
  static Color get error => _p.error;
  static Color get success => _p.success;

  // Chat / chrome
  static Color get header => _p.header;
  static Color get headerForeground => _p.headerForeground;
  static Color get accent => _p.accent;
  static Color get chatBackground => _p.chatBackground;
  static Color get inputField => _p.inputField;
  static Color get myBubble => _p.myBubble;
  static Color get myBubbleText => _p.myBubbleText;
  static Color get otherBubble => _p.otherBubble;
  static Color get otherBubbleText => _p.otherBubbleText;
  static Color get readReceipt => AppThemePalettes.readReceipt;
  static Color get unreadReceipt => textGrey;

  // Effects / skeleton
  static Color get shadow => _p.shadow;
  static Color get buttonShadow => _p.buttonShadow;
  static Color get borderSubtle => _p.borderSubtle;
  static Color get shimmerBase => _p.shimmerBase;
  static Color get shimmerHighlight => _p.shimmerHighlight;

  // Liquid glass
  static bool get isGlass => _p.isGlass;
  static bool get isDark => _p.isDark;
  static Color get glassFill => _p.glassFill;
  static Color get glassChrome => _p.glassChrome;
  static Color get glassBorder => _p.glassBorder;
  static Color get glassHighlight => _p.glassHighlight;
  static double get glassBlur => _p.glassBlur;
  static List<Color> get atmosphere => _p.atmosphere;

  static Color avatarFor(String name) {
    final colors = AppThemePalettes.avatarSwatches;
    if (name.isEmpty) return colors.first;
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
