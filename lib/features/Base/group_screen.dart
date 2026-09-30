import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shared/widgets/app_skeletons.dart';
import '../../core/shared/widgets/chat_tile.dart';
import '../../core/utils/time_formatter.dart';
import '../auth/Profile/Screens/full_avatar_view.dart';

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

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatListProvider);

    final List<Widget> groupSlivers = chatsAsync.when(
      data: (chats) {
        // Step 1: sirf group wali chats alag list mein daalo
        List<dynamic> groupChats = [];
        for (int i = 0; i < chats.length; i++) {
          if (chats[i].isGroup) {
            groupChats.add(chats[i]);
          }
        }

        // Step 2: agar koi group nahi hai
        if (groupChats.isEmpty) {
          return <Widget>[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.groups_outlined,
                title: 'No groups yet',
                subtitle: 'Groups you create or join will show up here.',
              ),
            ),
          ];
        }

        // Local search (sirf UI)
        final String q = _query.trim().toLowerCase();
        final visible = groupChats.where((c) {
          final String n = (c.otherUserName ?? 'Group').toString().toLowerCase();
          return q.isEmpty || n.contains(q);
        }).toList();

        if (visible.isEmpty) {
          return <Widget>[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Try a different group name.',
              ),
            ),
          ];
        }

        // Step 3: groups ki list dikhao
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
                    avatarHeroTag: 'list-avatar-${chat.id}',
                    avatarColor: Colors.teal,
                    onTap: () {
                      AppNav.push(
                        context,
                        ConversationScreen(
                          chatId: chat.id,
                          otherUserName: name,
                          avatarUrl: chat.avatarUrl,
                          isGroup: true,
                        ),
                      );
                    },
                    onAvatarTap: () {
                      final url = chat.avatarUrl;
                      if (url == null || url.isEmpty) {
                        AppNav.push(
                          context,
                          ConversationScreen(
                            chatId: chat.id,
                            otherUserName: name,
                            avatarUrl: chat.avatarUrl,
                            isGroup: true,
                          ),
                        );
                        return;
                      }
                      AppNav.fade(
                        context,
                        FullAvatarView(
                          imageUrl: url,
                          title: name,
                          heroTag: 'list-avatar-${chat.id}',
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
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          ChatUi.sliverHeader('Groups'),
          SliverToBoxAdapter(
            child: ChatSearchField(
              controller: _searchController,
              hint: 'Search groups',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          ...groupSlivers,
        ],
      ),
    );
  }
}
