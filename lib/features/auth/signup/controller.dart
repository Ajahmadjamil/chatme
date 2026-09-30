import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository.dart';

// Holds the loading / error state of Sign Up.
class SignUpController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Nothing to load at the start.
  }

  // Returns true if signup worked, false if there was an error.
  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return false; // ignore double taps

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(signUpRepositoryProvider).signUp(
            name: name,
            phone: phone,
            email: email,
            password: password,
          ),
    );

    if (!ref.mounted) return false; // screen was closed while waiting
    state = result;
    return !result.hasError;
  }
}

final signUpControllerProvider =
    AsyncNotifierProvider.autoDispose<SignUpController, void>(
  SignUpController.new,
);
