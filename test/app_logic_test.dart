import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;

import 'package:chatme/core/utils/validators.dart';
import 'package:chatme/features/Auto Clear Chat/model.dart';
import 'package:chatme/features/auth/controller.dart';

// Plain logic only — nothing here needs Supabase, Firebase or a device.
void main() {
  group('Validators.name (Finish your profile)', () {
    test('rejects empty and one-letter names', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('   '), isNotNull);
      expect(Validators.name('A'), isNotNull);
    });

    test('accepts a normal name', () {
      expect(Validators.name('Ali'), isNull);
    });
  });

  group('Auto-delete options', () {
    test('minutes round-trip for every option', () {
      for (final option in AutoClearOption.values) {
        expect(AutoClearOptionData.fromMinutes(option.minutes), option);
      }
    });

    test('unknown minutes fall back to off', () {
      expect(AutoClearOptionData.fromMinutes(17), AutoClearOption.off);
    });
  });

  group('authErrorMessage', () {
    test('[16] reauth error points at the phone, not the app setup', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );
      expect(authErrorMessage(error), contains('on this phone'));
    });

    test('a real cancel says cancelled', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'The user canceled the sign-in flow.',
      );
      expect(authErrorMessage(error), 'Sign-in was cancelled.');
    });

    test('client configuration errors mention SHA-1 / OAuth client', () {
      const error = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'bad client',
      );
      expect(authErrorMessage(error), contains('SHA-1'));
    });
  });
}
