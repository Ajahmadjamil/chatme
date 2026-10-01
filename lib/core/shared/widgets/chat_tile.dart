import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../utils/app_haptics.dart';
import 'user_avatar.dart';

class ChatUi {
  static Color get ink => AppColors.textMain;
  static Color get muted => AppColors.textGrey;
  static Color get line => AppColors.divider;
  static Color get surface => AppColors.surface;
  static Color get accent => AppColors.accent;
  // Never map this to glass header fill — that made icons/text vanish.
  static Color get accentDark => AppColors.primary;

  static Widget sliverHeader(
    String title, {
    List<Widget>? actions,
  }) {
    final glass = AppColors.isGlass;
    final titleStyle = TextStyle(
      color: ink,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    );

    if (glass) {
      return SliverAppBar(
        pinned: true,
        floating: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        actions: actions,
        systemOverlayStyle: (AppColors.isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
        flexibleSpace: const GlassImmersiveBar(),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(title, style: titleStyle),
          ),
        ),
      );
    }

    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 48,
      expandedHeight: 68,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        expandedTitleScale: 1.35,
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 10),
        title: Text(title, style: titleStyle),
      ),
    );
  }
}

// ---------- Search field ----------
class ChatSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const ChatSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 15, color: ChatUi.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: ChatUi.muted, fontSize: 15),
        prefixIcon: Icon(Icons.search_rounded, color: ChatUi.muted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: ChatUi.muted),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            );
          },
        ),
        filled: !AppColors.isGlass,
        fillColor: ChatUi.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: AppColors.isGlass
          ? GlassCard(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: field,
            )
          : field,
    );
  }
}

// ---------- Filter chips ----------
class ChatFilterChips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const ChatFilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final bool isSelected = i == selected;
          return GestureDetector(
            onTap: () {
              AppHaptics.select();
              onSelected(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? ChatUi.accentDark : ChatUi.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.onPrimary : ChatUi.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------- Chat tile ----------
class ChatTile extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final String? time;
  final int unreadCount;
  final bool isGroup;
  final Color avatarColor;
  final String? avatarUrl;
  final Object? avatarHeroTag;
  final int index; // sirf halki entry animation ke liye
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
    required this.avatarColor,
    this.avatarUrl,
    this.avatarHeroTag,
    required this.onTap,
    this.index = 0,
    this.onLongPress,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = unreadCount > 0;
    final String badge = unreadCount > 99 ? '99+' : '$unreadCount';
    final int ms = 220 + (index < 10 ? index : 10) * 40;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: _TileSurface(
        onTap: () {
          AppHaptics.tap();
          onTap();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                AppHaptics.medium();
                onLongPress!();
              },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppColors.isGlass ? 14 : 20,
            vertical: 12,
          ),
          child: Row(
            children: [
              // Avatar (unread ho to green ring) — tap opens photo preview
              GestureDetector(
                onTap: onAvatarTap == null
                    ? null
                    : () {
                        AppHaptics.light();
                        onAvatarTap!();
                      },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasUnread ? ChatUi.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: avatarHeroTag == null
                      ? UserAvatar(
                          name: name,
                          avatarUrl: isGroup ? null : avatarUrl,
                          radius: 24,
                          backgroundColor: avatarColor.withOpacity(0.14),
                          foregroundColor: avatarColor,
                          fallbackIcon: isGroup ? Icons.groups_rounded : null,
                        )
                      : Hero(
                          tag: avatarHeroTag!,
                          child: UserAvatar(
                            name: name,
                            avatarUrl: isGroup ? null : avatarUrl,
                            radius: 24,
                            backgroundColor: avatarColor.withOpacity(0.14),
                            foregroundColor: avatarColor,
                            fallbackIcon: isGroup ? Icons.groups_rounded : null,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ChatUi.ink,
                        fontSize: 16,
                        fontWeight:
                        hasUnread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastMessage ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread ? ChatUi.ink : ChatUi.muted,
                        fontSize: 14,
                        fontWeight:
                        hasUnread ? FontWeight.w500 : FontWeight.normal,
                        fontStyle: lastMessage == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Time + unread badge
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time != null)
                    Text(
                      time!,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasUnread ? ChatUi.accentDark : ChatUi.muted,
                        fontWeight:
                        hasUnread ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  if (hasUnread) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ChatUi.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass themes: each row is its own inset glass card (text never sits on the
/// raw gradient). Solid themes: classic full-bleed row with ink.
class _TileSurface extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _TileSurface({
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!AppColors.isGlass) {
      return InkWell(onTap: onTap, onLongPress: onLongPress, child: child);
    }
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

class ChatDivider extends StatelessWidget {
  const ChatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    // Glass rows are separate cards — a gap reads better than a hairline.
    if (AppColors.isGlass) return const SizedBox(height: 8);
    // 20 (padding) + 56 (avatar) + 14 (gap) = 90
    return Divider(
        height: 1, thickness: 1, indent: 90, color: ChatUi.line);
  }
}

// ---------- Empty / Error ----------
class ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ChatEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer Theme colorScheme so empty states stay readable even if a
    // static facade briefly lags a theme switch.
    final scheme = Theme.of(context).colorScheme;
    final titleColor = scheme.onSurface;
    final subtitleColor = scheme.onSurface.withValues(alpha: 0.72);
    final accent = scheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: accent),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatErrorState extends StatelessWidget {
  final Object error;
  const ChatErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 44, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: ChatUi.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ChatUi.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}