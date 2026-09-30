import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../controller.dart';
import '../widget/auth_header.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onContinuePressed() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success =
    await ref.read(authControllerProvider.notifier).sendResetEmail(
      email: _emailController.text.trim(),
    );
    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset link sent. Please check your email.')),
    );
    Navigator.of(context).pop(); // back to Sign In
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      final isVisible = ModalRoute.of(context)?.isCurrent ?? false;
      if (next.hasError && isVisible) {
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
                    title: 'Forgot Password',
                    subtitle:
                    'Enter your email address to receive a reset link and regain access to your account.',
                  ),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Email address',
                    prefixIcon: Icons.mail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onContinuePressed(),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Continue',
                    isLoading: isLoading,
                    onPressed: _onContinuePressed,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}