import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../controller.dart';
import '../widget/auth_header.dart';

// Opens when the user taps the reset link in the email.
class ResetPasswordView extends ConsumerStatefulWidget {
  const ResetPasswordView({super.key});

  @override
  ConsumerState<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends ConsumerState<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onResetPressed() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authControllerProvider.notifier).updatePassword(
      password: _passwordController.text,
    );

    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully.')),
    );
    // AuthGate opens Home by itself.
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(next.error!))),
        );
      }
    });

    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const AuthHeader(
                    showBackButton: false,
                    title: 'Reset Password',
                    subtitle: 'Enter your new password below.',
                  ),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'New Password',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: _confirmController,
                    hintText: 'Confirm New Password',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onResetPressed(),
                    validator: (value) => Validators.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Reset Password',
                    isLoading: isLoading,
                    onPressed: _onResetPressed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}