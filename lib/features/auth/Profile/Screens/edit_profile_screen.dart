import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/shared/widgets/custom_button.dart';
import '../../../../core/shared/widgets/custom_text_field.dart';
import '../../../../core/shared/widgets/avatar_viewer_screen.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/page_transitions.dart';
import '../../widget/auth_header.dart';
import '../provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loadedOnce = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Tapping the photo itself: just VIEW it full-screen (no edit here)
  void _viewAvatar(String? avatarUrl) {
    if (avatarUrl == null) return;
    Navigator.push(
      context,
      PageTransitions.fadeTransition(
        AvatarViewerScreen(
          imageUrl: avatarUrl,
          title: _nameController.text,
        ),
      ),
    );
  }

  // Tapping the small camera/pencil icon: pick a new photo and upload it
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(profileActionsProvider).updateAvatar(File(picked.path));
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileActionsProvider).updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('duplicate')
            ? 'This username is already taken'
            : 'Failed to save: $e';
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
    final headerColor = p.primary;

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: profileAsync.when(
              data: (profile) {
                if (!_loadedOnce) {
                  _nameController.text = (profile['name'] as String?) ?? '';
                  _usernameController.text = (profile['username'] as String?) ?? '';
                  _bioController.text = (profile['bio'] as String?) ?? '';
                  _emailController.text = (profile['email'] as String?) ?? '';
                  _loadedOnce = true;
                }
                final avatarUrl = profile['avatar_url'] as String?;
                final name = _nameController.text;

                return Column(
                  children: [
                    const AuthHeader(
                      title: 'Profile Settings',
                      showBackButton: true,
                      subtitle: 'Update your photo and personal details.',
                    ),

                    // ---- Avatar: tap photo to VIEW, tap pencil to EDIT ----
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _viewAvatar(avatarUrl),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: headerColor.withOpacity(0.15),
                            backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null
                                ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: headerColor,
                              ),
                            )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: headerColor,
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    CustomTextField(
                      controller: _nameController,
                      hintText: 'Name',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _usernameController,
                      hintText: 'Username',
                      prefixIcon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _bioController,
                      hintText: 'Bio',
                      prefixIcon: Icons.info_outline,
                    ),
                    const SizedBox(height: 18),
                    // Email comes from the Google account, so it is read-only
                    CustomTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      prefixIcon: Icons.mail_outline,
                      readOnly: true,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Your email is managed by your Google account.',
                        style: TextStyle(fontSize: 11.5, color: p.textGrey),
                      ),
                    ),
                    const SizedBox(height: 32),

                    CustomButton(
                      text: 'Save Changes',
                      isLoading: _isSaving,
                      onPressed: _save,
                    ),
                    const SizedBox(height: 70),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Center(child: Text('Error: $err')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}