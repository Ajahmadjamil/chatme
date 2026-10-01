import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widget/auth_header.dart';
import '../provider.dart';

/// Create / change a 4-digit PIN.
///
/// - [chatId] null → shared PIN (or mode is shared)
/// - [chatId] set → per-chat PIN in separate mode
/// - [isChange] true → title says "Change PIN"
class SetPinScreen extends ConsumerStatefulWidget {
  final String? chatId;
  final bool isChange;

  const SetPinScreen({
    super.key,
    this.chatId,
    this.isChange = false,
  });

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() {
      _error = null;
      _isSaving = true;
    });

    await ref.read(chatLockProvider.notifier).setPin(
          pin,
          chatId: widget.chatId,
        );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final digitsOnly = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ];
    final separate = widget.chatId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                AuthHeader(
                  title: widget.isChange ? 'Change PIN' : 'Set a PIN',
                  showBackButton: true,
                  subtitle: separate
                      ? 'This PIN is only for this chat and stays on this device.'
                      : 'Choose a 4-digit PIN used for locked chats. '
                          'Stored only on this device.',
                ),
                CustomTextField(
                  controller: _pinController,
                  hintText: 'Enter 4-digit PIN',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _confirmController,
                  hintText: 'Confirm PIN',
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: digitsOnly,
                  onSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                CustomButton(
                  text: widget.isChange ? 'Update PIN' : 'Save PIN',
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
