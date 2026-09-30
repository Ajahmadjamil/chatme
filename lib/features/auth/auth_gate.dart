import '/features/Base/main_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shared/widgets/app_skeletons.dart';
import 'controller.dart';
import 'forget_password/reset_password.dart';
import 'signin/view.dart';

// Decides the screen:
//   checking reset link  -> skeleton
//   reset link is OK     -> Reset Password
//   logged in            -> Home
//   logged out           -> Sign In
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<RecoveryState>(passwordRecoveryProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final recovery = ref.watch(passwordRecoveryProvider);
    final session = ref.watch(sessionProvider);

    if (recovery.status == RecoveryStatus.processing) {
      return AppSkeletons.authGate();
    }
    if (recovery.status == RecoveryStatus.ready) {
      return const ResetPasswordView();
    }

    return session.when(
      data: (s) => s == null ? const SignInView() : const MainScreen(),
      loading: () => AppSkeletons.authGate(),
      error: (error, stack) => const SignInView(),
    );
  }
}
