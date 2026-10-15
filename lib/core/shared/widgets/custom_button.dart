import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme_provider.dart';

// Rounded button that follows the selected theme.
// When isLoading is true it shows a spinner and cannot be tapped.
class CustomButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          disabledBackgroundColor: p.primary, // keep the color while loading
          foregroundColor: p.onPrimary,
          disabledForegroundColor: p.onPrimary,
          elevation: 6,
          shadowColor: p.primary.withOpacity(0.4),
          shape: const StadiumBorder(), // fully rounded ends
        ),
        child: isLoading
            ? SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: p.onPrimary,
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