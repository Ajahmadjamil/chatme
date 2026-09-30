import 'package:flutter/material.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';

// Top part of every auth screen: (optional) back button, title, subtitle.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBackButton = true,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBackButton) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => AppNav.maybePop(context),
              child: Container(
                height: 44,
                width: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ] else
          const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }
}
