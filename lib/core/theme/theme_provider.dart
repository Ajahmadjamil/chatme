import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_presets.dart';

// One selectable color theme (name + the color it is built from)
class AppThemeOption {
  final String name;
  final Color color;
  const AppThemeOption(this.name, this.color);
}

// The 5 themes the user can pick from
const List<AppThemeOption> appThemes = [
  AppThemeOption('WhatsApp Green', Color(0xFF25D366)),
  AppThemeOption('Ocean Blue', Color(0xFF3B82F6)),
  AppThemeOption('Royal Purple', Color(0xFF8B5CF6)),
  AppThemeOption('Sunset Orange', Color(0xFFF97316)),
  AppThemeOption('Rose Pink', Color(0xFFEC4899)),
];

class ThemeState {
  final int themeIndex; // which color from appThemes
  final bool isDark;
  final int presetIndex;

  const ThemeState({this.themeIndex = 0, this.isDark = false, this.presetIndex = 0, });

  Color get seedColor => appThemes[themeIndex].color;
  // NEW: the currently selected full theme
  AppThemePreset get preset => appPresets[presetIndex];
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const _colorKey = 'theme_color_index';
  static const _darkKey = 'theme_is_dark';
  static const _presetKey = 'theme_preset_index';

  @override
  ThemeState build() {
    _loadSaved();
    return const ThemeState();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_colorKey) ?? 0;
    final isDark = prefs.getBool(_darkKey) ?? false;
    var presetIndex = prefs.getInt(_presetKey) ?? 0; // NEW
    if (presetIndex >= appPresets.length) presetIndex = 0; // NEW: safety check
    state = ThemeState(
      themeIndex: index,
      isDark: isDark,
      presetIndex: presetIndex, // NEW
    );
  }

  Future<void> setColor(int index) async {
    state = ThemeState(
      themeIndex: index,
      isDark: state.isDark,
      presetIndex: state.presetIndex, // NEW
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, index);
  }

  Future<void> setDark(bool value) async {
    state = ThemeState(
      themeIndex: state.themeIndex,
      isDark: value,
      presetIndex: state.presetIndex, // NEW
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkKey, value);
  }

// called when the user taps a theme on the Theme page
  Future<void> setPreset(int index) async {
    state = ThemeState(
      themeIndex: state.themeIndex,
      isDark: state.isDark,
      presetIndex: index,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_presetKey, index);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);