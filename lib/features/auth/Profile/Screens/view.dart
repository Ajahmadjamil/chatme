import 'package:chatme/core/utils/app_animations.dart';
import 'package:chatme/features/auth/Profile/Screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/app_dialogs.dart'; // adjust path if different
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/page_transitions.dart';
import '../../../chat lock/screens/manage_lock_view.dart';
import '../../controller.dart'; // adjust path to where authControllerProvider is defined
import '../provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final theme = ref.watch(themeProvider);
    final p = theme.preset;
    final headerColor = p.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: profileAsync.when(
        data: (profile) {
          final name = (profile['name'] as String?) ?? '';
          final email = (profile['email'] as String?) ?? '';
          final avatarUrl = profile['avatar_url'] as String?;

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                // ---- Top bar: "Profile" + "Logout" ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: const Text(
                      'Profile',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // ---- Avatar with pencil badge + name ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: FadeSlideIn(

                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(60),
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideFromRight(const EditProfileScreen()),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: headerColor.withOpacity(0.25), width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: headerColor.withOpacity(0.12),
                                    backgroundImage:
                                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null
                                        ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: headerColor,
                                      ),
                                    )
                                        : null,
                                  ),
                                ),
                                // Pencil badge, sitting on the bottom-right of the avatar
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: headerColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context).scaffoldBackgroundColor,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(color: p.textGrey, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ---- Settings section ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 34, 20, 8),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.textMain,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                // ---- Settings list card ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: FadeSlideIn(
                         offsetY: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.person_outline,
                              title: 'Edit Profile',
                              iconColor: headerColor,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                              ),
                            ),
                            const _TileDivider(),
                            _SettingsTile(
                              icon: Icons.shield_outlined,
                              title: 'Manage Lock',
                              iconColor: Colors.teal.shade600,
                              onTap: () => Navigator.push(
                                context,
                                  PageTransitions.slideFromRight(const ManageLockScreen())
                              ),
                            ),
                            const _TileDivider(),
                            _SettingsTile(
                              icon: Icons.settings_outlined,
                              title: 'Settings',
                              iconColor: Colors.blueGrey.shade600,
                              isLast: true,
                              onTap: () => Navigator.push(
                                context,
                                  PageTransitions.slideFromRight(const SettingsScreen())
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

// Thin divider line between tiles, indented past the icon
class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 66, color: Theme.of(context).dividerColor);
  }
}

// One row: colored circle icon + title + chevron
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
        AppHaptics.tap(); // NEW
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
                color: iconColor.withOpacity(0.12),
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