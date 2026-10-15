// All field checks are here.
// Each function returns:
//   null            -> field is OK
//   "some message"  -> this message is shown in red under the field
class Validators {
  Validators._();

  // Example: name@gmail.com
  static final RegExp _emailRegex =
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

  // Only digits, and an optional + at the start
  static final RegExp _phoneRegex = RegExp(r'^\+?\d+$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Name is required';
    if (text.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Phone number is required';
    if (!_phoneRegex.hasMatch(text)) return 'Use digits only';
    final digits = text.replaceAll('+', '');
    if (digits.length < 10) return 'Phone number must be at least 10 digits';
    if (digits.length > 15) return 'Phone number is too long';
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  // "original" is the text of the Password field
  static String? confirmPassword(String? value, String original) {
    final text = value ?? '';
    if (text.isEmpty) return 'Please confirm your password';
    if (text != original) return 'Passwords do not match';
    return null;
  }
}
