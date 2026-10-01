import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Material layer a glass widget sits on. Each tier has its own fill density.
enum GlassTier {
  /// Content cards, list rows, inputs.
  card,

  /// App bars, tab bars, floating controls — thinner fill, stronger blur.
  chrome,

  /// Bottom sheets, dialogs, menus — densest fill so modal text stays crisp.
  sheet,
}

/// Every token a translucent theme needs. Registered as a [ThemeExtension] so
/// glass widgets resolve from context and theme switches animate smoothly.
///
/// Hex lives here (and in [AppThemePalettes]) only — never in feature widgets.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  // ---- Atmosphere (the "liquid" backdrop) ----
  final Color base;
  final List<Color> gradient;
  final List<double> gradientStops;

  /// Three soft radial light pools: top-right, mid-left, bottom-right.
  final List<Color> orbs;

  // ---- Surfaces ----
  final Color chromeFill;

  /// Denser chrome tint at the very top so status-bar icons and titles stay
  /// legible when bright content scrolls underneath.
  final Color chromeFillTop;
  final Color chromeBorder;
  final Color cardFill;
  final Color cardBorder;
  final Color sheetFill;

  /// Specular sheen along the top edge of every glass panel.
  final Color sheen;

  /// Rim light: bright at the top-left of an edge, fading to [rimShade].
  final Color rimLight;
  final Color rimShade;

  // ---- Depth ----
  final Color shadowKey;
  final Color shadowAmbient;

  // ---- Optics ----
  final double chromeBlur;
  final double cardBlur;

  /// Backdrop saturation boost (Apple "vibrancy"). 1.0 disables it.
  final double saturation;

  // ---- Content ----
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color icon;
  final Color divider;

  // ---- Selection (liquid pill) ----
  final Color selectionFill;
  final Color selectionBorder;
  final Color selectionGlow;
  final Color selectedForeground;
  final Color unselectedForeground;

  const GlassTheme({
    required this.base,
    required this.gradient,
    required this.gradientStops,
    required this.orbs,
    required this.chromeFill,
    required this.chromeFillTop,
    required this.chromeBorder,
    required this.cardFill,
    required this.cardBorder,
    required this.sheetFill,
    required this.sheen,
    required this.rimLight,
    required this.rimShade,
    required this.shadowKey,
    required this.shadowAmbient,
    required this.chromeBlur,
    required this.cardBlur,
    required this.saturation,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.icon,
    required this.divider,
    required this.selectionFill,
    required this.selectionBorder,
    required this.selectionGlow,
    required this.selectedForeground,
    required this.unselectedForeground,
  });

  /// "Liquid Glass" — warm ivory / champagne wash, frosted cream panes.
  /// No blue, violet, or cyan — quiet stone + soft gold accents.
  static const liquid = GlassTheme(
    base: Color(0xFFF6F3EE),
    gradient: [Color(0xFFF7F4EF), Color(0xFFF3EDE4), Color(0xFFEFE8DE)],
    gradientStops: [0.0, 0.55, 1.0],
    orbs: [
      Color(0x66E8D9C4), // champagne  #E8D9C4 @ 40%
      Color(0x59D4C4A8), // soft sand  #D4C4A8 @ 35%
      Color(0x4DCBB8A0), // warm taupe #CBB8A0 @ 30%
    ],
    chromeFill: Color(0x66FFFFFF), //    white @ 40%
    chromeFillTop: Color(0x8CFFFFFF), // white @ 55%
    chromeBorder: Color(0x73FFFFFF), //  white @ 45%
    cardFill: Color(0xA3FFFFFF), //      white @ 64%
    cardBorder: Color(0x8CFFFFFF), //    white @ 55%
    sheetFill: Color(0xD9FFFCF8), //     warm white @ 85%
    sheen: Color(0x73FFFFFF), //         white @ 45%
    rimLight: Color(0xE6FFFFFF), //      white @ 90%
    rimShade: Color(0x40FFFFFF), //      white @ 25%
    shadowKey: Color(0x1A2C2824), //     warm charcoal @ 10%
    shadowAmbient: Color(0x0D2C2824), // warm charcoal @ 5%
    chromeBlur: 20,
    cardBlur: 16,
    saturation: 1.15,
    textPrimary: Color(0xFF2C2824), //   warm charcoal
    textSecondary: Color(0xFF6B6358), // warm stone
    textDisabled: Color(0xFFA39A8E), //  muted stone
    icon: Color(0xFF4A453E), //          deep stone
    divider: Color(0x142C2824), //       warm charcoal @ 8%
    selectionFill: Color(0xB8FFFFFF), // white @ 72%
    selectionBorder: Color(0xE6FFFFFF), // white @ 90%
    selectionGlow: Color(0x339A7B4F), //  champagne gold @ 20%
    selectedForeground: Color(0xFF9A7B4F), // champagne gold
    unselectedForeground: Color(0xFF6B6358), // warm stone
  );

  /// "Glass Dark" — warm espresso / graphite, smoked amber panes.
  /// No navy, violet, or cyan — quiet charcoal + champagne accents.
  static const dark = GlassTheme(
    base: Color(0xFF12100E),
    gradient: [Color(0xFF161310), Color(0xFF1A1714), Color(0xFF0E0C0A)],
    gradientStops: [0.0, 0.5, 1.0],
    orbs: [
      Color(0x33CDB892), // champagne  #CDB892 @ 20%
      Color(0x2EA68B5B), // muted gold #A68B5B @ 18%
      Color(0x26B8956C), // bronze     #B8956C @ 15%
    ],
    chromeFill: Color(0xA31C1916), //    warm graphite @ 64%
    chromeFillTop: Color(0xC21C1916), // warm graphite @ 76%
    chromeBorder: Color(0x33FFFFFF), //  white @ 20%
    cardFill: Color(0x14FFFFFF), //      white @ 8%
    cardBorder: Color(0x28FFFFFF), //    white @ 16%
    sheetFill: Color(0xE61C1916), //     warm graphite @ 90%
    sheen: Color(0x1AFFFFFF), //         white @ 10%
    rimLight: Color(0x40FFFFFF), //      white @ 25%
    rimShade: Color(0x0FFFFFFF), //      white @ 6%
    shadowKey: Color(0x73000000), //     black @ 45%
    shadowAmbient: Color(0x40000000), // black @ 25%
    chromeBlur: 20,
    cardBlur: 16,
    saturation: 1.1,
    textPrimary: Color(0xFFF3EFE8), //   warm ivory
    textSecondary: Color(0xFFC4B8A8), // warm sand
    textDisabled: Color(0xFF7A7268), //  muted stone
    icon: Color(0xFFE8DFD2), //          soft ivory
    divider: Color(0x1AFFFFFF), //       white @ 10%
    selectionFill: Color(0x28FFFFFF), // white @ 16%
    selectionBorder: Color(0x40FFFFFF), // white @ 25%
    selectionGlow: Color(0x4DCDB892), //  champagne @ 30%
    selectedForeground: Color(0xFFCDB892), // champagne
    unselectedForeground: Color(0xFFC4B8A8), // warm sand
  );

  static GlassTheme? maybeOf(BuildContext context) =>
      Theme.of(context).extension<GlassTheme>();

  Color fillFor(GlassTier tier) => switch (tier) {
        GlassTier.card => cardFill,
        GlassTier.chrome => chromeFill,
        GlassTier.sheet => sheetFill,
      };

  double blurFor(GlassTier tier) =>
      tier == GlassTier.card ? cardBlur : chromeBlur;

  /// Two-layer depth: a wide soft key shadow plus a tight contact shadow.
  List<BoxShadow> get shadows => [
        BoxShadow(
          color: shadowKey,
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: shadowAmbient,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  @override
  GlassTheme copyWith({Color? textPrimary, Color? selectedForeground}) {
    return GlassTheme(
      base: base,
      gradient: gradient,
      gradientStops: gradientStops,
      orbs: orbs,
      chromeFill: chromeFill,
      chromeFillTop: chromeFillTop,
      chromeBorder: chromeBorder,
      cardFill: cardFill,
      cardBorder: cardBorder,
      sheetFill: sheetFill,
      sheen: sheen,
      rimLight: rimLight,
      rimShade: rimShade,
      shadowKey: shadowKey,
      shadowAmbient: shadowAmbient,
      chromeBlur: chromeBlur,
      cardBlur: cardBlur,
      saturation: saturation,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary,
      textDisabled: textDisabled,
      icon: icon,
      divider: divider,
      selectionFill: selectionFill,
      selectionBorder: selectionBorder,
      selectionGlow: selectionGlow,
      selectedForeground: selectedForeground ?? this.selectedForeground,
      unselectedForeground: unselectedForeground,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> cs(List<Color> a, List<Color> b) =>
        [for (var i = 0; i < a.length; i++) c(a[i], b[i])];
    double d(double a, double b) => lerpDouble(a, b, t)!;

    return GlassTheme(
      base: c(base, other.base),
      gradient: cs(gradient, other.gradient),
      gradientStops: [
        for (var i = 0; i < gradientStops.length; i++)
          d(gradientStops[i], other.gradientStops[i]),
      ],
      orbs: cs(orbs, other.orbs),
      chromeFill: c(chromeFill, other.chromeFill),
      chromeFillTop: c(chromeFillTop, other.chromeFillTop),
      chromeBorder: c(chromeBorder, other.chromeBorder),
      cardFill: c(cardFill, other.cardFill),
      cardBorder: c(cardBorder, other.cardBorder),
      sheetFill: c(sheetFill, other.sheetFill),
      sheen: c(sheen, other.sheen),
      rimLight: c(rimLight, other.rimLight),
      rimShade: c(rimShade, other.rimShade),
      shadowKey: c(shadowKey, other.shadowKey),
      shadowAmbient: c(shadowAmbient, other.shadowAmbient),
      chromeBlur: d(chromeBlur, other.chromeBlur),
      cardBlur: d(cardBlur, other.cardBlur),
      saturation: d(saturation, other.saturation),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      icon: c(icon, other.icon),
      divider: c(divider, other.divider),
      selectionFill: c(selectionFill, other.selectionFill),
      selectionBorder: c(selectionBorder, other.selectionBorder),
      selectionGlow: c(selectionGlow, other.selectionGlow),
      selectedForeground: c(selectedForeground, other.selectedForeground),
      unselectedForeground:
          c(unselectedForeground, other.unselectedForeground),
    );
  }
}
