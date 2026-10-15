import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/widget/auth_header.dart';
import '../provider.dart';

// Asks for the PIN of ONE chat. Pops with `true` if the PIN was correct.
class EnterPinScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String title;
  final String subtitle;

  const EnterPinScreen({
    super.key,
    required this.chatId,
    this.title = 'Enter PIN',
    this.subtitle = 'Enter the 4-digit PIN for this chat.',
  });

  @override
  ConsumerState<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends ConsumerState<EnterPinScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _isChecking = false;
  bool _isPassword = false; // true when this chat is locked with a password

  @override
  void initState() {
    super.initState();
    _loadLockType();
  }

  // Finds out if this chat uses a PIN or a password, so we show the right keyboard
  Future<void> _loadLockType() async {
    try {
      final type =
      await ref.read(chatLockProvider.notifier).getLockType(widget.chatId);
      if (!mounted) return;
      setState(() => _isPassword = type == 'password');
    } catch (e) {
      // If this fails we simply keep the normal PIN screen
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _pinController.text.trim();
    if (_isPassword) {
      if (pin.isEmpty) {
        setState(() => _error = 'Enter your password');
        return;
      }
    } else if (pin.length != 4) {
      setState(() => _error = 'Enter your 4-digit PIN');
      return;
    }

    setState(() {
      _error = null;
      _isChecking = true;
    });

    bool correct = false;
    try {
      correct = await ref
          .read(chatLockProvider.notifier)
          .verifyPin(widget.chatId, pin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _error = 'Could not check PIN, check your internet';
      });
      return;
    }

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
                  title: widget.title,
                  showBackButton: true,
                  subtitle: _isPassword
                      ? widget.subtitle.replaceAll('PIN', 'password')
                      : widget.subtitle,
                ),
                CustomTextField(
                  controller: _pinController,
                  hintText: _isPassword ? 'Enter password' : 'Enter PIN',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType:
                  _isPassword ? TextInputType.text : TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: _isPassword
                      ? <TextInputFormatter>[]
                      : <TextInputFormatter>[
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