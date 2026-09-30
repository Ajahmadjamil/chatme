import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';

// Example: "Don't have an account?  Sign Up here"
// The green part is tappable.
class AuthBottomLink extends StatelessWidget {
  const AuthBottomLink({
    super.key,
    required this.text,
    required this.linkText,
    required this.onTap,
  });

  final String text;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            AppHaptics.tap();
            onTap();
          },
          child: Text(
            linkText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
