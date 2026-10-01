import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/shared/widgets/chat_tile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/time_formatter.dart';
import '../../auth/Profile/Screens/full_avatar_view.dart';
import '../../chats/providers/chat_list_provider.dart';
import '../../chats/screens/conversation_screens.dart';
import '../chat_lock_actions.dart';
import '../provider.dart';

/// Lists chats hidden from the main Chats / Groups tabs.
class LockedChatsScreen extends ConsumerWidget {
  const LockedChatsScreen({super.key});

  Color _avatarColor(String name) => AppColors.avatarFor(name);

  Future<void> _openChat(
    BuildContext context,
    WidgetRef ref,
    dynamic chat,
    String name,
  ) async {
    final ok = await ChatLockActions.unlockWithBiometric(
      context: context,
      ref: ref,
      chatId: chat.id,
      reason: 'Unlock $name',
    );
    if (!ok) return;
    if (!context.mounted) return;

    AppNav.push(
      context,
      ConversationScreen(
        chatId: chat.id,
        otherUserName: name,
        otherUserId: chat.otherUserId,
        avatarUrl: chat.avatarUrl,
        isGroup: chat.isGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(chatLockProvider);
    final chatsAsync = ref.watch(chatListProvider);

    return Scaffold(
      backgroundColor:
          AppColors.isGlass ? Colors.transparent : AppColors.background,
      appBar: AppBar(
        title: const Text('Locked chats'),
        backgroundColor:
            AppColors.isGlass ? Colors.transparent : AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chats) {
          final locked = chats
              .where((c) => lockState.lockedChatIds.contains(c.id))
              .toList();

          if (locked.isEmpty) {
            return const ChatEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'No locked chats',
              subtitle: 'Lock a chat from its menu to hide it here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            itemCount: locked.length,
            separatorBuilder: (_, __) => const ChatDivider(),
            itemBuilder: (context, i) {
              final chat = locked[i];
              final name =
                  chat.otherUserName ?? (chat.isGroup ? 'Group' : 'Unknown');
              return ChatTile(
                index: i,
                name: name,
                lastMessage: '🔒 Tap to unlock with fingerprint',
                time: chat.lastMessageAt != null
                    ? formatMessageTime(chat.lastMessageAt!)
                    : null,
                unreadCount: 0,
                isGroup: chat.isGroup,
                avatarUrl: chat.avatarUrl,
                avatarHeroTag: 'locked-avatar-${chat.id}',
                avatarColor:
                    chat.isGroup ? Colors.teal : _avatarColor(name),
                onTap: () {
                  AppHaptics.tap();
                  _openChat(context, ref, chat, name);
                },
                onAvatarTap: () {
                  final url = chat.avatarUrl;
                  if (url == null || url.isEmpty) {
                    _openChat(context, ref, chat, name);
                    return;
                  }
                  AppNav.fade(
                    context,
                    FullAvatarView(
                      imageUrl: url,
                      title: name,
                      heroTag: 'locked-avatar-${chat.id}',
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
