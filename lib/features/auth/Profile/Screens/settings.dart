import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_picker_sheet.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/app_haptics.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider); // rebuild when theme changes
    final name = ref.watch(themeProvider).palette.name;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Appearance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a theme for the whole app',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(Icons.palette_outlined, color: AppColors.primary),
              title: Text(
                'App theme',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
              subtitle: Text(
                name,
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              trailing: Icon(Icons.chevron_right, color: AppColors.icon),
              onTap: () {
                AppHaptics.tap();
                ThemePickerSheet.show(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
