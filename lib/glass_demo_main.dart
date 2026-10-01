import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_palette.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/theme_service.dart';
import 'features/glass_demo/glass_demo_screen.dart';

/// Standalone preview of the glass themes — no Supabase / .env needed.
///   flutter run -t lib/glass_demo_main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [themeProvider.overrideWith(_GlassPreviewTheme.new)],
      child: const GlassDemoApp(),
    ),
  );
}

/// Starts on Liquid Glass instead of the saved / default theme.
class _GlassPreviewTheme extends ThemeNotifier {
  @override
  ThemeState build() {
    ThemeService.instance.bind(AppThemeId.softCream);
    return const ThemeState(AppThemeId.softCream);
  }
}

class GlassDemoApp extends ConsumerWidget {
  const GlassDemoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    ThemeService.instance.bind(theme.id);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Glass Preview',
      theme: buildAppTheme(theme.palette),
      home: const GlassDemoScreen(),
    );
  }
}
