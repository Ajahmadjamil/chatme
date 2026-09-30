import '/features/auth/Profile/Screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/shared/widgets/app_skeletons.dart';
import '../../../../core/shared/widgets/user_avatar.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/app_dialogs.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../controller.dart';
import '../provider.dart';
import 'change_password.dart';
import 'edit_profile_screen.dart';
import 'full_avatar_view.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.confirmLogout(context);
    if (!confirmed) return;
    AppHaptics.warning();
    ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final theme = ref.watch(themeProvider);
    final headerColor = theme.seedColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: profileAsync.when(
        data: (profile) {
          final name = (profile['name'] as String?) ?? '';
          final email = (profile['email'] as String?) ?? '';
          final avatarUrl = profile['avatar_url'] as String?;
          final about = (profile['about'] as String?)?.trim();

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _logout(context, ref),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 0),
                          ),
                          icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(60),
                          onTap: () {
                            AppHaptics.tap();
                            if (avatarUrl != null) {
                              AppNav.fade(
                                context,
                                FullAvatarView(
                                  imageUrl: avatarUrl,
                                  title: name,
                                ),
                              );
                            } else {
                              AppNav.push(context, const EditProfileScreen());
                            }
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: headerColor.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                                child: UserAvatar(
                                  name: name,
                                  avatarUrl: avatarUrl,
                                  radius: 46,
                                  backgroundColor:
                                      headerColor.withValues(alpha: 0.12),
                                  foregroundColor: headerColor,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () => AppNav.push(
                                    context,
                                    const EditProfileScreen(),
                                  ),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: headerColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13.5,
                          ),
                        ),
                        if (about != null && about.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            about,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 34, 20, 8),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.person_outline,
                            title: 'Profile settings',
                            iconColor: headerColor,
                            onTap: () => AppNav.push(
                              context,
                              const EditProfileScreen(),
                            ),
                          ),
                          const _TileDivider(),
                          _SettingsTile(
                            icon: Icons.lock_outline,
                            title: 'Privacy',
                            iconColor: Colors.orange.shade700,
                            onTap: () => AppNav.push(
                              context,
                              const ChangePasswordScreen(),
                            ),
                          ),
                          const _TileDivider(),
                          _SettingsTile(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            iconColor: Colors.blueGrey.shade600,
                            isLast: true,
                            onTap: () => AppNav.push(
                              context,
                              const SettingsScreen(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => AppSkeletons.profile(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 66, color: Colors.grey.shade100);
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppHaptics.tap();
        onTap();
      },
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(20),
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
