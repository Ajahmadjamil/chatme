import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sign Up backend calls live here.
// Now it only waits 2 seconds (fake). Supabase code will come here later.
class SignUpRepository {
  Future<void> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    // TODO: Supabase -> signUp (name and phone go in user data)
    await Future.delayed(const Duration(seconds: 2));
  }
}

final signUpRepositoryProvider = Provider<SignUpRepository>((ref) {
  return SignUpRepository();
});
