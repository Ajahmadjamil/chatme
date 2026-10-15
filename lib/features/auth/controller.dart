import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, Session;

import '../../core/notification/notification_service.dart';
import 'repository.dart';
import '../chats/providers/chat_list_provider.dart';

// ---------- 1) Is the user logged in? ----------
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);

  yield repo.currentSession; // saved login from last time

  await for (final authState in repo.authStateChanges) {
    yield authState.session;
  }
});

// ---------- 2) Error text that is OK to show to the user ----------
String authErrorMessage(Object error) {
  if (error is AuthException) return error.message;

  if (error is GoogleSignInException) {
    final details = error.description ?? error.code.name;
    // Android reports "[16] Account reauth failed" as "canceled". It means
    // either this build's SHA-1 / OAuth client is wrong, or this phone can't
    // sign apps in to Google (account needs attention, or the phone isn't
    // Play Protect certified, e.g. a custom ROM). Check that first.
    if (details.contains('[16]') || details.toLowerCase().contains('reauth')) {
      return 'Google couldn\'t sign in on this phone ($details). '
          'If it works on other phones, check this phone\'s Google account '
          'and Play Protect certification, or try another account.';
    }
    if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
        error.code == GoogleSignInExceptionCode.providerConfigurationError) {
      return 'Google Sign-In is not set up for this app build '
          '(SHA-1 / OAuth client). Details: $details';
    }
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return 'Sign-in was cancelled.';
    }
    return 'Google sign-in failed: $details';
  }

  return 'Something went wrong. Please check your internet and try again.';
}

// ---------- 3) The controller ----------
// Not autoDispose: sign-in/out outlive AuthGate rebuilds when the session flips.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signInWithGoogle() async {
    if (!ref.mounted) return false;
    final repo = ref.read(authRepositoryProvider);

    final success = await _run(repo.signInWithGoogle);
    if (!success && ref.mounted && state.hasError) {
      // Full error in the console, the snackbar only shows a short version
      debugPrint('[auth] Google sign-in failed: ${state.error}');
    }
    if (success && ref.mounted) {
      // New user logged in -> throw away old cached chat list, load fresh one
      ref.invalidate(chatListProvider);
    }
    return success;
  }

  Future<bool> signOut() async {
    if (!ref.mounted) return false;
    final repo = ref.read(authRepositoryProvider);

    // Must run BEFORE the actual sign-out, while the user is still
    // authenticated, or the token-removal request will be rejected
    await NotificationService.clearTokenOnLogout();

    // Session may already be clearing / AuthGate rebuilding — finish logout
    // with the captured repo even if this notifier is gone.
    if (!ref.mounted) {
      try {
        await repo.signOut();
      } catch (_) {}
      return true;
    }

    final success = await _run(repo.signOut);
    if (success && ref.mounted) {
      // Logged out -> clear cached chat list so next user doesn't see it
      ref.invalidate(chatListProvider);
    }
    return success;
  }

  Future<bool> _run(Future<void> Function() work) async {
    if (!ref.mounted) return false;
    if (state.isLoading) return false; // ignore double taps

    state = const AsyncLoading();
    final result = await AsyncValue.guard(work);

    if (!ref.mounted) return !result.hasError;
    state = result;
    return !result.hasError;
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
