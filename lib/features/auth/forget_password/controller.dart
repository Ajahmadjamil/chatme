import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository.dart';

// Holds the loading / error state of Forgot Password.
class ForgotPasswordController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Nothing to load at the start.
  }

  // Returns true if the email request worked, false if there was an error.
  Future<bool> sendResetEmail({required String email}) async {
    if (state.isLoading) return false; // ignore double taps

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(forgotPasswordRepositoryProvider).sendResetEmail(email: email),
    );

    if (!ref.mounted) return false; // screen was closed while waiting
    state = result;
    return !result.hasError;
  }
}

final forgotPasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<ForgotPasswordController, void>(
  ForgotPasswordController.new,
);
