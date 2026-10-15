import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme_presets.dart';
import '../../../../core/utils/app_dialogs.dart';
import '../../controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {

    final confirmed = await AppDialogs.confirmLogout(context);
    if (!confirmed) return;

    ref.read(authControllerProvider.notifier).signOut();


    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
                onTap: () => notifier.setPreset(index),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: option.background,
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

          const SizedBox(height: 40),

          // ---- Account section ----
          Text(
            'Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: preset.textMain,
            ),
          ),
          const SizedBox(height: 12),

          // ---- Logout button ----
          Material(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _logout(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    // Red circle icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 14),

                    // Title + small text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sign out of your account',
                            style: TextStyle(color: preset.textGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    Icon(
                      Icons.chevron_right,
                      color: Colors.red.withOpacity(0.6),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
