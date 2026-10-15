import 'package:chatme/features/Base/main_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notification/notification_service.dart';
import '../callings/calling_bootstrap.dart';
import 'Profile/provider.dart';
import 'complete_profile/view.dart';
import 'controller.dart';
import 'signin/view.dart';

// Decides the screen:
//   logged out                     -> Google Sign-In
//   logged in, profile not finished -> Complete Profile
//   logged in, profile finished     -> Home
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<dynamic>>(sessionProvider, (previous, next) {
      final session = next.value;
      if (session != null) {
        NotificationService.syncTokenForLoggedInUser();
        CallingBootstrap.start(ref); // calling ready for this user
      } else if (previous?.value != null) {
        // Only on a real logout — at app start with nobody signed in,
        // calling was never started, so there is nothing to stop
        CallingBootstrap.stop(ref);
      }
    });

    final session = ref.watch(sessionProvider);

    return session.when(
      data: (s) {
        if (s == null) return const SignInView();

        final profileAsync = ref.watch(myProfileProvider);
        return profileAsync.when(
          data: (profile) => profile['profile_complete'] == true
              ? const MainScreen()
              : const CompleteProfileView(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => _ProfileErrorView(error: err),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SignInView(),
    );
  }
}

class _ProfileErrorView extends ConsumerWidget {
  const _ProfileErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load your profile.\n$error',
                textAlign: TextAlign.center,
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
    );
  }
}
