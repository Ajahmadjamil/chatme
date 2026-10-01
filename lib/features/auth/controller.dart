import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, Session;

import '../../core/notification/notification_service.dart';
import '../chats/providers/chat_list_provider.dart';
import 'repository.dart';

// ---------- 1) Is the user logged in? ----------
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);

  yield repo.currentSession;

  await for (final authState in repo.authStateChanges) {
    yield authState.session;
  }
});

// ---------- 2) Error text that is OK to show to the user ----------
String authErrorMessage(Object error) {
  if (error is AuthException) return error.message;
  final text = error.toString();
  if (text.contains('canceled') || text.contains('cancelled')) {
    return 'Sign-in was cancelled.';
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
    if (!ref.mounted) return success;
    if (success) {
      ref.invalidate(chatListProvider);
      await NotificationService.syncTokenForLoggedInUser();
    }
    return success;
  }

  Future<bool> signOut() async {
    if (!ref.mounted) return false;
    final repo = ref.read(authRepositoryProvider);

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
      ref.invalidate(chatListProvider);
    }
    return success;
  }

  Future<bool> _run(Future<void> Function() work) async {
    if (!ref.mounted) return false;
    if (state.isLoading) return false;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(work);

    if (!ref.mounted) return !result.hasError;
    state = result;
    return !result.hasError;
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
