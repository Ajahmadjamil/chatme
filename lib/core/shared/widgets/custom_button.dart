import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../theme/app_colors.dart';
import '../../utils/app_haptics.dart';

/// Green rounded button.
/// When [isLoading] is true it shows a shimmer skeleton and cannot be tapped.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                AppHaptics.success();
                onPressed();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 6,
          shadowColor: AppColors.buttonShadow,
          shape: const StadiumBorder(),
        ),
        child: isLoading
            ? Skeletonizer(
                enabled: true,
                effect: const ShimmerEffect(
                  baseColor: Color(0x33FFFFFF),
                  highlightColor: Color(0x66FFFFFF),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : Text(
                text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }
}
