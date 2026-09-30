import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, Session;

import 'repository.dart';
import '../chats/providers/chat_list_provider.dart'; // apna sahi relative path daal dein

// ---------- 1) Is the user logged in? ----------
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);

  yield repo.currentSession; // saved login from last time

  await for (final authState in repo.authStateChanges) {
    yield authState.session;
  }
});

// ---------- 2) The reset link from the email ----------
// none        -> nothing happening
// processing  -> we are checking the link (show a spinner)
// ready       -> link is OK, show the Reset Password screen
enum RecoveryStatus { none, processing, ready }

class RecoveryState {
  const RecoveryState(this.status, {this.error});

  final RecoveryStatus status;
  final String? error; // message to show if the link did not work
}

class PasswordRecoveryNotifier extends Notifier<RecoveryState> {
  String? _lastHandledCode; // so the same link is never handled twice

  @override
  RecoveryState build() {
    // Listens to ALL links that open our app (also the one that started the app).
    final subscription = AppLinks().uriLinkStream.listen(_onLink);
    ref.onDispose(subscription.cancel);
    return const RecoveryState(RecoveryStatus.none);
  }

  Future<void> _onLink(Uri uri) async {
    if (uri.host != 'reset-password') return; // some other link, ignore it
    if (state.status != RecoveryStatus.none) return; // already busy

    final code = uri.queryParameters['code'];
    if (code != null && code == _lastHandledCode) return; // same link again
    _lastHandledCode = code;

    state = const RecoveryState(RecoveryStatus.processing);

    try {
      await ref.read(authRepositoryProvider).openRecoveryLink(uri);
      if (!ref.mounted) return;
      state = const RecoveryState(RecoveryStatus.ready);
    } catch (e) {
      debugPrint('Recovery link error: $e'); // helps us to find the reason
      if (!ref.mounted) return;
      state = const RecoveryState(
        RecoveryStatus.none,
        error: 'This reset link is not valid anymore. '
            'Please request a new one and open it on this phone.',
      );
    }
  }

  void finish() => state = const RecoveryState(RecoveryStatus.none);
}

final passwordRecoveryProvider =
NotifierProvider<PasswordRecoveryNotifier, RecoveryState>(
  PasswordRecoveryNotifier.new,
);

// ---------- 3) Error text that is OK to show to the user ----------
String authErrorMessage(Object error) {
  if (error is AuthException) return error.message;
  return 'Something went wrong. Please check your internet and try again.';
}

// ---------- 4) The controller ----------
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) async {
    final success = await _run(() => _repo.signIn(email: email, password: password));
    if (success) {
      // New user logged in -> throw away old cached chat list, load fresh one
      ref.invalidate(chatListProvider);
    }
    return success;
  }

  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final success = await _run(() => _repo.signUp(
      name: name,
      phone: phone,
      email: email,
      password: password,
    ));
    if (success) {
      // New account created -> make sure chat list starts empty/fresh
      ref.invalidate(chatListProvider);
    }
    return success;
  }

  Future<bool> sendResetEmail({required String email}) {
    return _run(() => _repo.sendResetEmail(email: email));
  }

  Future<bool> updatePassword({required String password}) async {
    final success = await _run(() => _repo.updatePassword(password));
    if (success) {
      // Password is changed -> leave the Reset Password screen.
      ref.read(passwordRecoveryProvider.notifier).finish();
    }
    return success;
  }

  Future<bool> signOut() async {
    final success = await _run(_repo.signOut);
    if (success) {
      // Logged out -> clear cached chat list so next user doesn't see it
      ref.invalidate(chatListProvider);
    }
    return success;
  }

  Future<bool> _run(Future<void> Function() work) async {
    if (state.isLoading) return false; // ignore double taps

    state = const AsyncLoading();
    final result = await AsyncValue.guard(work);

    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}

final authControllerProvider =
AsyncNotifierProvider.autoDispose<AuthController, void>(AuthController.new);