import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';

// "Remember me" checkbox (left) and "Forgot Password" link (right).
// Used only on the Sign In screen.
class RememberForgotRow extends StatelessWidget {
  const RememberForgotRow({
    super.key,
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotTap,
  });

  final bool rememberMe;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: rememberMe,
            activeColor: AppColors.primary,
            side: const BorderSide(color: AppColors.icon, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
            onChanged: (value) {
              AppHaptics.light();
              onRememberChanged(value ?? false);
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Remember me',
          style: TextStyle(fontSize: 13, color: AppColors.textDark),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            AppHaptics.tap();
            onForgotTap();
          },
          child: const Text(
            'Forgot Password',
            style: TextStyle(fontSize: 13, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
