import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_palette.dart';
import 'theme_service.dart';

const _storageKey = 'app_theme_id';
const _legacyPresetKey = 'theme_preset_index';

class ThemeState {
  final AppThemeId id;
  const ThemeState(this.id);

  AppThemePalette get palette => AppThemePalettes.forId(id);
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    // Sync default immediately so AppColors works before async load finishes.
    ThemeService.instance.bind(AppThemeId.messagesLight);
    _loadSaved();
    return const ThemeState(AppThemeId.messagesLight);
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == null) {
      // Migrate old index-based preset if present.
      final legacyIndex = prefs.getInt(_legacyPresetKey);
      if (legacyIndex != null) {
        await select(AppThemeIdLabel.fromStorage('$legacyIndex'));
        return;
      }
    }
    final id = AppThemeIdLabel.fromStorage(stored);
    ThemeService.instance.bind(id);
    state = ThemeState(id);
  }

  Future<void> select(AppThemeId id) async {
    if (id == state.id) return;
    ThemeService.instance.bind(id);
    state = ThemeState(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, id.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
