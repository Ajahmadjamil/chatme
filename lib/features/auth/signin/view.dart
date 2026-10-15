import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_theme_presets.dart';
import '../../../core/theme/theme_provider.dart';
import '../controller.dart';
import '../widget/auth_header.dart';

// Google is the only way to sign in. On success, AuthGate sees the new
// session and opens Complete Profile / Home by itself.
class SignInView extends ConsumerWidget {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      final isVisible = ModalRoute.of(context)?.isCurrent ?? false;
      if (next.hasError && isVisible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(next.error!))),
        );
      }
    });

    final isLoading = ref.watch(authControllerProvider).isLoading;
    final p = ref.watch(themeProvider).preset;

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                const AuthHeader(
                  title: 'Welcome',
                  showBackButton: false,
                  subtitle:
                      'Sign in with your Google account to start chatting instantly.',
                ),
                const SizedBox(height: 12),
                _GoogleSignInButton(
                  preset: p,
                  isLoading: isLoading,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signInWithGoogle(),
                ),
                const SizedBox(height: 28),
                Text(
                  'By continuing you agree to our terms of use.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: p.textGrey, height: 1.4),
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.preset,
    required this.isLoading,
    required this.onPressed,
  });

  final AppThemePreset preset;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = preset;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.textMain,
          side: BorderSide(color: p.divider),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: p.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.google, size: 18, color: p.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: p.textMain,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
