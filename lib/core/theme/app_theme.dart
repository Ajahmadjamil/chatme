import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme_palette.dart';

SystemUiOverlayStyle systemOverlayForPalette(AppThemePalette palette) {
  final isDark = palette.isDark;
  final glass = palette.glass;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    // Glass: match the bottom of the atmosphere gradient so the system bar
    // reads as a continuation of the backdrop, not a separate strip.
    systemNavigationBarColor: glass?.gradient.last ?? palette.background,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );
}

ThemeData buildAppTheme(AppThemePalette palette) {
  final glass = palette.glass;

  final colorScheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.textMain,
    surface: palette.surface,
    onSurface: palette.textMain,
    onSurfaceVariant: palette.textGrey,
    outlineVariant: palette.divider,
    error: AppThemePalettes.errorRed,
    onError: Colors.white,
  );

  final overlay = systemOverlayForPalette(palette);

  // Glass modals get the dense sheet tint + a rim; solid themes keep surface.
  final modalColor = glass?.sheetFill ?? palette.surface;
  final modalSide = glass == null
      ? BorderSide.none
      : BorderSide(color: glass.cardBorder, width: 1);

  final base = ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    scaffoldBackgroundColor: glass?.base ?? palette.background,
    canvasColor: glass?.base ?? palette.background,
    colorScheme: colorScheme,
    dividerColor: palette.divider,
    extensions: [if (glass != null) glass],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.isGlass ? Colors.transparent : palette.background,
      foregroundColor: palette.textMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: overlay,
      iconTheme: IconThemeData(color: palette.textMain),
    ),
    iconTheme: IconThemeData(
      color: glass?.icon ?? palette.onBackground.withValues(alpha: 0.85),
    ),
    cardTheme: CardThemeData(
      color: glass?.cardFill ?? palette.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: glass == null
            ? BorderSide.none
            : BorderSide(color: glass.cardBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: modalColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: modalSide,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.primary,
      foregroundColor: palette.onPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledForegroundColor: palette.textDisabled,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.primary),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.primary),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: glass != null ? modalColor : palette.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: modalSide,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: modalColor,
      textStyle: TextStyle(color: palette.textMain),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: modalSide,
      ),
    ),
    snackBarTheme: glass == null
        ? null
        : SnackBarThemeData(
            backgroundColor: glass.textPrimary,
            contentTextStyle: TextStyle(color: glass.base),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
  );

  if (glass == null) return base;

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: glass.textPrimary,
      displayColor: glass.textPrimary,
    ),
  );
}
