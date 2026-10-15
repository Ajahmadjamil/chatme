import 'package:local_auth/local_auth.dart';

// Asks for the phone's own lock (PIN, pattern, password or fingerprint)
class PhoneLockService {
  final LocalAuthentication _auth = LocalAuthentication();

  // False if the phone has no screen lock set at all
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // Shows the phone's lock screen. True only if the user passed it.
  Future<bool> verify() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirm it is you to manage chat locks',
      );
    } catch (e) {
      return false;
    }
  }
}