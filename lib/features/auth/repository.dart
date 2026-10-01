import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthState, OAuthProvider, Session, Supabase;

/// Native Google Sign-In → Supabase session via ID token.
/// Requires GOOGLE_WEB_CLIENT_ID (and optionally GOOGLE_IOS_CLIENT_ID) in `.env`.
class AuthRepository {
  final _auth = Supabase.instance.client.auth;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _googleReady = false;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;

    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
    if (webClientId == null || webClientId.isEmpty) {
      throw AuthException(
        'GOOGLE_WEB_CLIENT_ID is missing. Add it to your .env file.',
      );
    }

    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim();
    await _google.initialize(
      serverClientId: webClientId,
      clientId: (iosClientId == null || iosClientId.isEmpty) ? null : iosClientId,
    );
    _googleReady = true;
  }

  /// Opens the native Google account picker and exchanges the ID token
  /// for a Supabase session. Email confirmation is not required.
  Future<void> signInWithGoogle() async {
    await _ensureGoogleReady();

    const scopes = ['email', 'profile'];

    GoogleSignInAccount? googleUser;
    final lightweight = _google.attemptLightweightAuthentication();
    if (lightweight != null) {
      googleUser = await lightweight;
    }
    googleUser ??= await _google.authenticate(scopeHint: scopes);

    final authorization =
        await googleUser.authorizationClient.authorizationForScopes(scopes) ??
            await googleUser.authorizationClient.authorizeScopes(scopes);

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw AuthException('Google did not return an ID token.');
    }

    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }

  Future<void> signOut() async {
    try {
      if (_googleReady) {
        await _google.signOut();
      }
    } catch (_) {
      // Ignore Google sign-out failures; still clear Supabase session.
    }
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
