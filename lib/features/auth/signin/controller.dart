import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository.dart';

// Holds the loading / error state of Sign In.
// State can be: loading | data (idle or done) | error
class SignInController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Nothing to load at the start.
  }

  // Returns true if login worked, false if there was an error.
  Future<bool> signIn({required String email, required String password}) async {
    if (state.isLoading) return false; // ignore double taps

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(signInRepositoryProvider)
          .signIn(email: email, password: password),
    );

    if (!ref.mounted) return false; // screen was closed while waiting
    state = result;
    return !result.hasError;
  }
}

// autoDispose = state is cleared when the screen is closed.
final signInControllerProvider =
    AsyncNotifierProvider.autoDispose<SignInController, void>(
  SignInController.new,
);
