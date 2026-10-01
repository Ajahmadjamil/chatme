import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shared/widgets/app_skeletons.dart';
import '../../core/shared/widgets/chat_tile.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/app_haptics.dart';
import '../../core/utils/time_formatter.dart';
import '../auth/Profile/Screens/full_avatar_view.dart';
import '../chat lock/chat_lock_actions.dart';
import '../chat lock/provider.dart';
import '../chat lock/screens/locked_chats_screen.dart';

import '../chats/providers/chat_list_provider.dart';
import '../chats/screens/conversation_screens.dart';
import '../../core/navigation/app_nav.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openGroup(BuildContext context, dynamic chat, String name) async {
    final locked =
        ref.read(chatLockProvider).lockedChatIds.contains(chat.id);
    if (locked) {
      final ok = await ChatLockActions.unlockWithBiometric(
        context: context,
        ref: ref,
        chatId: chat.id,
        reason: 'Unlock $name',
      );
      if (!ok) return;
    }
    if (!context.mounted) return;
    AppNav.push(
      context,
      ConversationScreen(
        chatId: chat.id,
        otherUserName: name,
        avatarUrl: chat.avatarUrl,
        isGroup: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final chatsAsync = ref.watch(chatListProvider);
    final lockedIds = ref.watch(chatLockProvider).lockedChatIds;

    final List<Widget> groupSlivers = chatsAsync.when(
      data: (chats) {
        final groupChats = chats
            .where((c) => c.isGroup && !lockedIds.contains(c.id))
            .toList();

        if (groupChats.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.groups_outlined,
                title: 'No groups yet',
                subtitle: 'Groups you create or join will show up here.',
              ),
            ),
          ];
        }

        final String q = _query.trim().toLowerCase();
        final visible = groupChats.where((c) {
          final String n =
              (c.otherUserName ?? 'Group').toString().toLowerCase();
          return q.isEmpty || n.contains(q);
        }).toList();

        if (visible.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Try a different group name.',
              ),
            ),
          ];
        }

        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i.isOdd) return const ChatDivider();

                  final int idx = i ~/ 2;
                  final chat = visible[idx];
                  final String name = chat.otherUserName ?? 'Group';

                  return ChatTile(
                    index: idx,
                    name: name,
                    lastMessage: chat.lastMessage,
                    time: chat.lastMessageAt != null
                        ? formatMessageTime(chat.lastMessageAt!)
                        : null,
                    unreadCount: chat.unreadCount,
                    isGroup: true,
                    avatarUrl: chat.avatarUrl,
                    avatarHeroTag: 'groups-avatar-${chat.id}',
                    avatarColor: AppColors.primary,
                    onTap: () => _openGroup(context, chat, name),
                    onAvatarTap: () {
                      final url = chat.avatarUrl;
                      if (url == null || url.isEmpty) {
                        _openGroup(context, chat, name);
                        return;
                      }
                      AppNav.fade(
                        context,
                        FullAvatarView(
                          imageUrl: url,
                          title: name,
                          heroTag: 'groups-avatar-${chat.id}',
                        ),
                      );
                    },
                  );
                },
                childCount: visible.length * 2 - 1,
              ),
            ),
          ),
        ];
      },
      loading: () => <Widget>[
        AppSkeletons.chatListSliver(),
      ],
      error: (err, stack) => <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ChatErrorState(error: err),
        ),
      ],
    );

    return Scaffold(
      backgroundColor:
          AppColors.isGlass ? Colors.transparent : AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          ChatUi.sliverHeader(
            'Groups',
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.textMain),
                onSelected: (value) {
                  if (value == 'locked') {
                    AppHaptics.tap();
                    AppNav.push(context, const LockedChatsScreen());
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'locked',
                    child: Text('Show locked chats'),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: ChatSearchField(
              controller: _searchController,
              hint: 'Search groups',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          ...groupSlivers,
          if (AppColors.isGlass)
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
