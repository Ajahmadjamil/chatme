import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Result of a phone-keypass attempt.
enum BiometricResult {
  success,
  failed,
  unavailable,
  canceled,
}

/// Phone keypass gate (fingerprint / face / device PIN-pattern).
class BiometricGate {
  BiometricGate._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Prompts for fingerprint / face / phone lock screen credential.
  ///
  /// Returns [BiometricResult.unavailable] when the plugin/channel isn't ready
  /// or the device has no lock screen — callers should fall back to chat PIN.
  static Future<BiometricResult> authenticate({
    String reason = 'Authenticate to continue',
  }) async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        if (kDebugMode) debugPrint('BiometricGate: device not supported');
        return BiometricResult.unavailable;
      }

      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.canceled;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('BiometricGate PlatformException: ${e.code} ${e.message}');
      }
      // User dismissed the system sheet.
      if (e.code == 'UserCancel' ||
          e.code == 'AuthenticationCanceled' ||
          e.code == 'Canceled') {
        return BiometricResult.canceled;
      }
      if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return BiometricResult.failed;
      }
      // channel-error / NotAvailable / PasscodeNotSet / hot-restart issues, etc.
      // → treat as unavailable so the chat PIN fallback can run.
      return BiometricResult.unavailable;
    } catch (e) {
      if (kDebugMode) debugPrint('BiometricGate error: $e');
      return BiometricResult.unavailable;
    }
  }
}
