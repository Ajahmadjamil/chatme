import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../controller.dart';
import '../forget_password/view.dart';
import '../signup/view.dart';
import '../widget/auth_bottom_link.dart';
import '../widget/auth_header.dart';
import 'widget/remember_forgot_row.dart';

class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key});

  @override
  ConsumerState<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<SignInView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
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
                    title: 'Log in',
                    showBackButton: false,
                    subtitle:
                        'Enter your email and password to securely access your account and manage your services.',
                  ),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Email address',
                    prefixIcon: Icons.mail,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onLoginPressed(),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 14),
                  RememberForgotRow(
                    rememberMe: _rememberMe,
                    onRememberChanged: (value) =>
                        setState(() => _rememberMe = value),
                    onForgotTap: () =>
                        AppNav.push(context, const ForgotPasswordView()),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Login',
                    isLoading: isLoading,
                    onPressed: _onLoginPressed,
                  ),
                  const SizedBox(height: 24),
                  AuthBottomLink(
                    text: "Don't have an account?",
                    linkText: 'Sign Up here',
                    onTap: () => AppNav.push(context, const SignUpView()),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
