import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widget/auth_header.dart';
import '../provider.dart';
// Asks for the PIN. Pops with `true` if the entered PIN was correct.
class EnterPinScreen extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;

  const EnterPinScreen({
    super.key,
    this.title = 'Enter PIN',
    this.subtitle = 'Enter your 4-digit PIN to continue.',
  });

  @override
  ConsumerState<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends ConsumerState<EnterPinScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _isChecking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'Enter your 4-digit PIN');
      return;
    }

    setState(() {
      _error = null;
      _isChecking = true;
    });

    final correct = await ref.read(chatLockProvider.notifier).verifyPin(pin);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (correct) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Incorrect PIN, try again');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                AuthHeader(
                  title: widget.title,
                  showBackButton: true,
                  subtitle: widget.subtitle,
                ),
                CustomTextField(
                  controller: _pinController,
                  hintText: 'Enter PIN',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
                ],
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Unlock',
                  isLoading: _isChecking,
                  onPressed: _verify,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}