import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, Session, Supabase, UserAttributes;

// Must be EXACTLY the same as: Supabase dashboard (Redirect URLs) and AndroidManifest.
const resetPasswordRedirectUrl = 'chatapp://reset-password';

// This class only talks to Supabase. No UI code here.
class AuthRepository {
  final _auth = Supabase.instance.client.auth;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    await _auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'phone': phone},
    );
  }

  Future<void> sendResetEmail({required String email}) async {
    await _auth.resetPasswordForEmail(email, redirectTo: resetPasswordRedirectUrl);
  }

  // Called when the user opens the reset link from the email.
  // It turns the link into a (temporary) login session.
  Future<void> openRecoveryLink(Uri link) async {
    await _auth.getSessionFromUrl(link);
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});