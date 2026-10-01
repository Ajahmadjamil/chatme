import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../Profile/provider.dart';
import '../controller.dart';
import '../widget/auth_header.dart';

/// Shown once after the first Google sign-in until name + phone are saved.
class CompleteProfileView extends ConsumerStatefulWidget {
  const CompleteProfileView({super.key});

  @override
  ConsumerState<CompleteProfileView> createState() =>
      _CompleteProfileViewState();
}

class _CompleteProfileViewState extends ConsumerState<CompleteProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aboutController = TextEditingController();
  bool _loadedOnce = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileActionsProvider).completeProfile(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            about: _aboutController.text.trim(),
          );
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('$err')),
          data: (profile) {
            if (!_loadedOnce) {
              _nameController.text = (profile['name'] as String?)?.trim() ?? '';
              _phoneController.text =
                  (profile['phone'] as String?)?.trim() ?? '';
              _aboutController.text =
                  (profile['about'] as String?)?.trim().isNotEmpty == true
                      ? (profile['about'] as String).trim()
                      : 'Hey there! I am using ChatMe.';
              _loadedOnce = true;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const AuthHeader(
                      showBackButton: false,
                      title: 'Finish your profile',
                      subtitle:
                          'You’re signed in with Google. Add a few details so friends can find and recognize you.',
                    ),
                    if ((profile['email'] as String?)?.isNotEmpty == true) ...[
                      Text(
                        profile['email'] as String,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    CustomTextField(
                      controller: _nameController,
                      hintText: 'Display name',
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
                      controller: _aboutController,
                      hintText: 'About',
                      prefixIcon: Icons.info_outline,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onContinue(),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Continue',
                      isLoading: _isSaving,
                      onPressed: _onContinue,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                      child: Text(
                        'Use a different Google account',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
