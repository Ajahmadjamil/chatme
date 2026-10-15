import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_provider.dart';
import 'avatar_viewer_screen.dart';

class ChatUi {
  static const Color ink = Color(0xFF111B21);
  static const Color muted = Color(0xFF667781);
  static const Color line = Color(0xFFEDEFF0);
  static const Color surface = Color(0xFFF3F5F4);
  static const Color accent = Color(0xFF25D366);
  static const Color accentDark = Color(0xFF075E54);

  static Widget sliverHeader(String title, {List<Widget>? actions}) {
    // Consumer lets this static method read the selected theme
    return Consumer(
      builder: (context, ref, _) {
        final p = ref.watch(themeProvider).preset;

        return SliverAppBar(
          pinned: true,
          centerTitle: false,
          titleSpacing: 20,
          toolbarHeight: 60,
          backgroundColor: p.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          // Light status bar icons on dark theme, dark icons on light theme
          systemOverlayStyle: p.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          title: Text(
            title,
            style: TextStyle(
              color: p.textMain,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          actions: [
            ...?actions,
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}

// ---------- Search field ----------
class ChatSearchField extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 15, color: p.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.textGrey, fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: p.textGrey),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: p.textGrey),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
          filled: true,
          fillColor: p.inputField,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

//  Filter chips
class ChatFilterChips extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

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
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? p.header : p.inputField,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : p.textGrey,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

//  Chat tile
class ChatTile extends ConsumerWidget {
  final String name;
  final String? lastMessage;
  final String? time;
  final int unreadCount;
  final bool isGroup;
  final String? avatarUrl;
  final Color avatarColor;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
    required this.avatarColor,
    required this.onTap,
    this.index = 0,
    this.onLongPress,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;
    final bool hasUnread = unreadCount > 0;
    final bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
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
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: hasAvatar
                    ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AvatarViewerScreen(
                      imageUrl: avatarUrl!,
                      title: name,
                    ),
                  ),
                )
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasUnread ? p.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: avatarColor.withOpacity(0.14),
                      shape: BoxShape.circle,
                      image: hasAvatar
                          ? DecorationImage(
                        image: NetworkImage(avatarUrl!),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: hasAvatar
                        ? null
                        : isGroup
                        ? Icon(Icons.groups_rounded, color: avatarColor, size: 24)
                        : Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: avatarColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
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
                        color: p.textMain,
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
                        color: hasUnread ? p.textMain : p.textGrey,
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
                        color: hasUnread ? p.primary : p.textGrey,
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
                        color: p.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
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

class ChatDivider extends ConsumerWidget {
  const ChatDivider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

    // 20 (padding) + 56 (avatar) + 14 (gap) = 90
    return Divider(height: 1, thickness: 1, indent: 90, color: p.divider);
  }
}

// Empty / Error
class ChatEmptyState extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

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
                color: p.accent.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: p.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: p.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.textGrey,
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

class ChatErrorState extends ConsumerWidget {
  final Object error;
  const ChatErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

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
                color: p.textMain,
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
              style: TextStyle(color: p.textGrey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}