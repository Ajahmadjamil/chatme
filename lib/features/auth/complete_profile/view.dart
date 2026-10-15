import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared/widgets/custom_button.dart';
import '../../../core/shared/widgets/custom_text_field.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/validators.dart';
import '../Profile/provider.dart';
import '../controller.dart';
import '../widget/auth_header.dart';

// Shown once after the first Google sign-in, until the profile is saved.
class CompleteProfileView extends ConsumerStatefulWidget {
  const CompleteProfileView({super.key});

  @override
  ConsumerState<CompleteProfileView> createState() =>
      _CompleteProfileViewState();
}

class _CompleteProfileViewState extends ConsumerState<CompleteProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _loadedOnce = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileActionsProvider).completeProfile(
            name: _nameController.text.trim(),
            username: _usernameController.text.trim(),
            bio: _bioController.text.trim(),
          );
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('duplicate')
            ? 'This username is already taken'
            : 'Could not save profile: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final p = ref.watch(themeProvider).preset;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('$err')),
          data: (profile) {
            if (!_loadedOnce) {
              _nameController.text = (profile['name'] as String?)?.trim() ?? '';
              _usernameController.text =
                  (profile['username'] as String?)?.trim() ?? '';
              _bioController.text = (profile['bio'] as String?)?.trim() ?? '';
              _loadedOnce = true;
            }
            final email = profile['email'] as String?;

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
                    if (email != null && email.isNotEmpty) ...[
                      Text(email, style: TextStyle(color: p.textGrey, fontSize: 14)),
                      const SizedBox(height: 18),
                    ],
                    CustomTextField(
                      controller: _nameController,
                      hintText: 'Name',
                      prefixIcon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _usernameController,
                      hintText: 'Username (optional)',
                      prefixIcon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _bioController,
                      hintText: 'Bio (optional)',
                      prefixIcon: Icons.info_outline,
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
                          : () =>
                              ref.read(authControllerProvider.notifier).signOut(),
                      child: Text(
                        'Use a different Google account',
                        style: TextStyle(color: p.textGrey),
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
