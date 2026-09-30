import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/shared/widgets/app_skeletons.dart';
import '../../../../core/shared/widgets/user_avatar.dart';
import '../../../../core/utils/app_haptics.dart';
import '../provider.dart';
import 'full_avatar_view.dart';

/// WhatsApp-inspired contact info — photo-led, no green wash.
class UserProfileScreen extends ConsumerWidget {
  final String userId;
  final String? fallbackName;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName,
  });

  static const _bg = Color(0xFFF0F2F5);
  static const _ink = Color(0xFF111B21);
  static const _muted = Color(0xFF667781);
  static const _card = Colors.white;
  static const _accent = Color(0xFF008069);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _bg,
      body: profileAsync.when(
        loading: () => AppSkeletons.profile(),
        error: (err, _) => Center(child: Text('Could not load profile\n$err')),
        data: (profile) {
          final name = (profile['name'] as String?)?.trim().isNotEmpty == true
              ? profile['name'] as String
              : (fallbackName ?? 'User');
          final email = (profile['email'] as String?)?.trim() ?? '';
          final phone = (profile['phone'] as String?)?.trim() ?? '';
          final avatarUrl = profile['avatar_url'] as String?;
          final about = (profile['about'] as String?)?.trim().isNotEmpty == true
              ? profile['about'] as String
              : 'Hey there! I am using ChatMe.';
          final createdAt = profile['created_at'] != null
              ? DateTime.tryParse(profile['created_at'] as String)
              : null;
          final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: !hasPhoto
                          ? null
                          : () {
                              AppHaptics.light();
                              AppNav.fade(
                                context,
                                FullAvatarView(
                                  imageUrl: avatarUrl,
                                  title: name,
                                  heroTag: 'profile-$userId',
                                ),
                              );
                            },
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Hero(
                          tag: 'profile-$userId',
                          child: hasPhoto
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      _FallbackHero(name: name),
                                )
                              : _FallbackHero(name: name),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 18),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x99000000),
                            ],
                          ),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: topPad + 8,
                      left: 12,
                      child: _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => AppNav.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: _SectionCard(
                  children: [
                    if (phone.isNotEmpty)
                      _ContactRow(
                        label: 'Phone',
                        value: phone,
                        icon: Icons.call_outlined,
                      ),
                    if (phone.isNotEmpty && email.isNotEmpty) const _Hairline(),
                    if (email.isNotEmpty)
                      _ContactRow(
                        label: 'Email',
                        value: email,
                        icon: Icons.mail_outline_rounded,
                      ),
                    if (phone.isEmpty && email.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Text(
                          'No phone or email on this profile yet.',
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: _SectionCard(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
                      child: Text(
                        'About',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                      child: Text(
                        about,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        child: Text(
                          'Joined ${DateFormat.yMMMMd().format(createdAt.toLocal())}',
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          );
        },
      ),
    );
  }
}

class _FallbackHero extends StatelessWidget {
  final String name;
  const _FallbackHero({required this.name});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFDFE5E7),
      child: Center(
        child: UserAvatar(
          name: name,
          radius: 64,
          backgroundColor: const Color(0xFFCFD8DC),
          foregroundColor: const Color(0xFF546E7A),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppHaptics.tap();
          onTap();
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: UserProfileScreen._card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 70,
      color: Colors.grey.shade200,
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ContactRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: UserProfileScreen._accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: UserProfileScreen._ink,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: UserProfileScreen._muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
