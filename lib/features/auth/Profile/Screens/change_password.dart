import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/custom_button.dart';
import '../../../../core/shared/widgets/custom_text_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../widget/auth_header.dart';
import '../provider.dart';


class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Makes sure the two new-password fields match
  String? _confirmValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your new password';
    if (value != _newController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileActionsProvider).changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is incorrect')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const AuthHeader(
                    title: 'Change Password',
                    showBackButton: true,
                    subtitle:
                    'Enter your current password and choose a new one to keep your account secure.',
                  ),
                  CustomTextField(
                    controller: _currentController,
                    hintText: 'Current password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: _newController,
                    hintText: 'New password',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 18),
                  CustomTextField(
                    controller: _confirmController,
                    hintText: 'Confirm new password',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _changePassword(),
                    validator: _confirmValidator,
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Update Password',
                    isLoading: _isSaving,
                    onPressed: _changePassword,
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