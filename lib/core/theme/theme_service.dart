import 'app_theme_palette.dart';

/// Holds the active palette so [AppColors] can resolve without BuildContext.
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  AppThemePalette _palette = AppThemePalettes.messagesLight;

  AppThemePalette get palette => _palette;
  AppThemeId themeId = AppThemeId.messagesLight;
  bool get isDarkMode => _palette.isDark;

  void bind(AppThemeId id) {
    themeId = id;
    _palette = AppThemePalettes.forId(id);
  }
}
