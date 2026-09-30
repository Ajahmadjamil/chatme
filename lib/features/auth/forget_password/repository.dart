import 'package:flutter_riverpod/flutter_riverpod.dart';

// Forgot Password backend calls live here.
// Now it only waits 2 seconds (fake). Supabase code will come here later.
class ForgotPasswordRepository {
  Future<void> sendResetEmail({required String email}) async {
    // TODO: Supabase -> resetPasswordForEmail
    await Future.delayed(const Duration(seconds: 2));
  }
}

final forgotPasswordRepositoryProvider = Provider<ForgotPasswordRepository>((ref) {
  return ForgotPasswordRepository();
});
