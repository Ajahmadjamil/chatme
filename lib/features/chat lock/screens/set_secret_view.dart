import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/widget/auth_header.dart';
import '../provider.dart';

// Sets ONE PIN or password for all the chats passed in.
// Pops with `true` once they are locked.
class SetSecretScreen extends ConsumerStatefulWidget {
  final List<String> chatIds;

  const SetSecretScreen({super.key, required this.chatIds});

  @override
  ConsumerState<SetSecretScreen> createState() => _SetSecretScreenState();
}

class _SetSecretScreenState extends ConsumerState<SetSecretScreen> {
  final _secretController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _usePin = true; // true = 4-digit PIN, false = password
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _secretController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Switching between PIN and password clears both fields
  void _chooseType(bool usePin) {
    setState(() {
      _usePin = usePin;
      _error = null;
      _secretController.clear();
      _confirmController.clear();
    });
  }

  Future<void> _save() async {
    final secret = _secretController.text.trim();
    final confirm = _confirmController.text.trim();

    if (_usePin) {
      if (secret.length != 4) {
        setState(() => _error = 'PIN must be exactly 4 digits');
        return;
      }
    } else {
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(secret);
      final hasNumber = RegExp(r'[0-9]').hasMatch(secret);
      if (secret.length < 6 || !hasLetter || !hasNumber) {
        setState(() =>
        _error = 'Password needs 6+ characters with letters and numbers');
        return;
      }
    }

    if (secret != confirm) {
      setState(() => _error = 'Both entries do not match');
      return;
    }

    setState(() {
      _error = null;
      _isSaving = true;
    });

    try {
      await ref.read(chatLockProvider.notifier).lockManyChats(
        widget.chatIds,
        secret,
        _usePin ? 'pin' : 'password',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Could not save, check your internet';
      });
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(themeProvider).preset;

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                AuthHeader(
                  title: 'Set lock',
                  showBackButton: true,
                  subtitle:
                  'Choose a PIN or password for ${widget.chatIds.length} chat(s).',
                ),

                // PIN or Password choice
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('PIN (4 digits)'),
                      selected: _usePin,
                      onSelected: (_) => _chooseType(true),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Password'),
                      selected: !_usePin,
                      onSelected: (_) => _chooseType(false),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                CustomTextField(
                  controller: _secretController,
                  hintText: _usePin ? 'Enter 4-digit PIN' : 'Enter password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType:
                  _usePin ? TextInputType.number : TextInputType.text,
                  inputFormatters: _usePin
                      ? <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ]
                      : <TextInputFormatter>[],
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _confirmController,
                  hintText: _usePin ? 'Confirm PIN' : 'Confirm password',
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  keyboardType:
                  _usePin ? TextInputType.number : TextInputType.text,
                  textInputAction: TextInputAction.done,
                  inputFormatters: _usePin
                      ? <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ]
                      : <TextInputFormatter>[],
                  onSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12.5)),
                ],
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Save lock',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}