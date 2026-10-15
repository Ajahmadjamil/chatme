import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';

// Top part of every auth screen: (optional) back button, title, subtitle.
class AuthHeader extends ConsumerWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBackButton = true,
  });

  final String title;
  final String subtitle;
  final bool showBackButton; // false = no back icon

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Colors of the currently selected theme
    final p = ref.watch(themeProvider).preset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBackButton) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: p.textMain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ] else
          const SizedBox(height: 24), // small top space (change this number if you want)
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: p.textMain,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: p.textGrey),
        ),
        const SizedBox(height: 25),
      ],
    );
  }
}