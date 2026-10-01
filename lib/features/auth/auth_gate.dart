import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shared/widgets/app_skeletons.dart';
import '../../core/theme/app_colors.dart';
import '../Base/main_view.dart';
import 'Profile/provider.dart';
import 'complete_profile/view.dart';
import 'controller.dart';
import 'signin/view.dart';

/// Root router:
///   logged out              -> Google Sign-In
///   logged in, incomplete   -> Complete Profile
///   logged in, ready        -> Main
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return session.when(
      loading: () => AppSkeletons.authGate(),
      error: (_, __) => const SignInView(),
      data: (s) {
        if (s == null) return const SignInView();

        final profileAsync = ref.watch(myProfileProvider);
        return profileAsync.when(
          loading: () => AppSkeletons.authGate(),
          error: (err, _) => Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load your profile.\n$err',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMain),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.invalidate(myProfileProvider),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (profile) {
            final complete = profile['profile_complete'] == true;
            if (!complete) return const CompleteProfileView();
            return const MainScreen();
          },
        );
      },
    );
  }
}
