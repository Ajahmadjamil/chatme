import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../controller.dart';
import '../repository.dart';
import '../widget/auth_bottom_link.dart';
import '../widget/auth_header.dart';
class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onCreateAccountPressed() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authControllerProvider.notifier).signUp(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted || !success) return;

    final hasSession = ref.read(authRepositoryProvider).currentSession != null;

    if (hasSession) {
      // Already logged in -> close this screen. AuthGate shows Home.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      // "Confirm email" is ON in Supabase -> user must verify the email first.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Please check your email to verify it.'),
        ),
      );
      AppNav.pop(context); // back to Sign In
    }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const AuthHeader(
                  showBackButton: false,
                  title: 'Create Account',
                  subtitle:
                  'Create a new account to get started and enjoy seamless access to our features.',
                ),
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Name',
                  prefixIcon: Icons.person,
                  keyboardType: TextInputType.name,
                  validator: Validators.name,
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _phoneController,
                  hintText: 'Phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  validator: Validators.phone,
                ),
                const SizedBox(height: 18),
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
                  validator: Validators.password,
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _confirmController,
                  hintText: 'Confirm Password',
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onCreateAccountPressed(),
                  validator: (value) => Validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Create Account',
                  isLoading: isLoading,
                  onPressed: _onCreateAccountPressed,
                ),
                const SizedBox(height: 24),
                AuthBottomLink(
                  text: 'Already have an account?',
                  linkText: 'Sign In here',
                  onTap: () => AppNav.maybePop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}