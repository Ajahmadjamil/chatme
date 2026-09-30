import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme_presets.dart';
import '../../../../core/utils/app_haptics.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final preset = themeState.preset;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose Theme',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: preset.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a theme and the whole app will change',
            style: TextStyle(color: preset.textGrey, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(appPresets.length, (index) {
              final option = appPresets[index];
              final isSelected = themeState.presetIndex == index;

              return GestureDetector(
                onTap: () {
                  AppHaptics.select();
                  notifier.setPreset(index);
                },
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: option.background, // preview of the theme background
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? option.primary : option.divider,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: option.primary,
                          child: isSelected
                              ? Icon(Icons.check, size: 16, color: option.onPrimary)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.name,
                      style: TextStyle(fontSize: 11, color: preset.textMain),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}