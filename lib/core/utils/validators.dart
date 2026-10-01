// Field checks used by profile forms.
// Each function returns:
//   null            -> field is OK
//   "some message"  -> this message is shown in red under the field
class Validators {
  Validators._();

  // Only digits, and an optional + at the start
  static final RegExp _phoneRegex = RegExp(r'^\+?\d+$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Name is required';
    if (text.length < 2) return 'Name must be at least 2 characters';
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
}
