import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sign In backend calls live here.
// Now it only waits 2 seconds (fake). Supabase code will come here later.
class SignInRepository {
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    // TODO: Supabase -> signInWithPassword
    await Future.delayed(const Duration(seconds: 2));
  }
}

final signInRepositoryProvider = Provider<SignInRepository>((ref) {
  return SignInRepository();
});
