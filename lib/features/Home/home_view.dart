import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shared/widgets/app_skeletons.dart';
import '../../core/shared/widgets/chat_tile.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/app_dialogs.dart';
import '../../core/utils/app_haptics.dart';
import '../../core/utils/time_formatter.dart';
import '../auth/Profile/Screens/full_avatar_view.dart';
import '../chat lock/provider.dart';
import '../chat lock/screens/enter_pin_view.dart';
import '../chat lock/screens/set_pin_view.dart';
import '../chats/providers/chat_actions_provider.dart';
import '../chats/providers/chat_list_provider.dart';
import '../chats/providers/chat_list_refresh_provider.dart';
import '../chats/screens/conversation_screens.dart';
import '../chats/screens/new_chat_screen.dart';
import '../../core/navigation/app_nav.dart';

const Color kAccentColor = Color(0xFF25D366);
const Color kHeaderColor = Color(0xFF075E54);

Color avatarColorFor(String name) {
  const colors = [
    Colors.indigo,
    Colors.deepOrange,
    Colors.teal,
    Colors.purple,
    Colors.blueGrey,
    Colors.pink,
  ];
  if (name.isEmpty) return colors[0];
  int index = name.codeUnitAt(0) % colors.length;
  return colors[index];
}

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});
  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  // Sirf UI ke liye: search text
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _handleChatTap(
      BuildContext context,
      WidgetRef ref,
      dynamic chat,
      String name,
      bool isLocked,
      ) async {
    if (isLocked && !ref.read(chatLockProvider.notifier).isUnlockedNow(chat.id)) {
      final success = await AppNav.push<bool>(
        context,
        const EnterPinScreen(
          title: 'Locked Chat',
          subtitle: 'Enter your PIN to open this chat.',
        ),
      );
      if (success != true) return;
      ref.read(chatLockProvider.notifier).markUnlocked(chat.id);
    }
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

  void _showChatOptionsSheet(
      BuildContext context,
      WidgetRef ref,
      dynamic chat,
      bool isLocked,
      ) {
    final name = chat.otherUserName ?? 'Unknown';

    final p = ref.read(themeProvider).preset;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: p.textGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Lock / Unlock option
                _sheetActionTile(
                  icon: isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  iconBg: Colors.blue.withOpacity(0.12),
                  iconColor: Colors.blue,
                  title: isLocked ? 'Unlock chat' : 'Lock chat',
                  subtitle: isLocked
                      ? 'Remove the PIN lock from this chat'
                      : 'Protect this chat with a PIN',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleLockToggle(context, ref, chat, isLocked);
                  },
                ),
                const SizedBox(height: 8),

                // Delete option
                _sheetActionTile(
                  icon: Icons.delete_outline_rounded,
                  iconBg: Colors.red.withOpacity(0.10),
                  iconColor: Colors.redAccent,
                  title: 'Delete chat',
                  subtitle: 'Remove this chat from your list',
                  titleColor: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteChat(context, ref, chat);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // One row inside the options sheet: circle icon + title + subtitle
  Widget _sheetActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    final p = ref.read(themeProvider).preset;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          AppHaptics.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: titleColor ?? p.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: p.textGrey, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLockToggle(
      BuildContext context,
      WidgetRef ref,
      dynamic chat,
      bool isLocked,
      ) async {
    final notifier = ref.read(chatLockProvider.notifier);

    if (isLocked) {
      final success = await AppNav.push<bool>(
      context,
      const EnterPinScreen(
            title: 'Unlock Chat',
            subtitle: 'Enter your PIN to remove the lock on this chat.',
          ),
      );
      if (success == true) {
        await notifier.removeLock(chat.id);
      }
      return;
    }

    final hasPin = await notifier.hasPinSet();
    if (!hasPin) {
      if (!context.mounted) return;
      final created = await AppNav.push<bool>(
      context,
      const SetPinScreen(),
      );
      if (created != true) return;
    }

    await notifier.lockChat(chat.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chat locked')));
    }
  }
  Future<void> _deleteChat(
      BuildContext context, WidgetRef ref, dynamic chat) async {
    final name = chat.otherUserName ?? 'this chat';


    final confirmed = await AppDialogs.confirmDeleteChat(context, name);
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(chatActionsProvider).clearChatForMe(chat.id);
      ref.invalidate(chatListProvider);
    } catch (e) {
      debugPrint('clearChatForMe error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Failed to delete chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatListProvider);
    ref.watch(chatListRefresherProvider);
    final p = ref.watch(themeProvider).preset;

    final List<Widget> chatSlivers = chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return <Widget>[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No chats yet',
                subtitle: 'Tap the button below to start one.',
              ),
            ),
          ];
        }

        // Local search (provider ko touch nahi karta)
        final String q = _query.trim().toLowerCase();
        final visible = chats.where((c) {
          final String n =
          (c.otherUserName ?? 'Unknown').toString().toLowerCase();
          return q.isEmpty || n.contains(q);
        }).toList();

        if (visible.isEmpty) {
          return <Widget>[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Try a different name.',
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
                  final name = chat.otherUserName ?? 'Unknown';
                  final isLocked = ref.watch(chatLockProvider).lockedChatIds.contains(chat.id);

                  // Swipe left = delete (long press bhi pehle jaisa chalega)
                  return Dismissible(
                    key: ValueKey('chat_${chat.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await _deleteChat(context, ref, chat);
                      return false; // list provider refresh karega
                    },
                    background: Container(
                      color: Colors.red.shade400,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                    ),
                    child: ChatTile(
                      index: idx,
                      name: name,
                      lastMessage: isLocked ? ' Locked chat' : chat.lastMessage,
                      time: chat.lastMessageAt != null
                          ? formatMessageTime(chat.lastMessageAt!)
                          : null,
                      unreadCount: chat.unreadCount,
                      isGroup: chat.isGroup,
                      avatarUrl: chat.avatarUrl,
                      avatarHeroTag: 'list-avatar-${chat.id}',
                      avatarColor:
                      chat.isGroup ? Colors.teal : avatarColorFor(name),
                      onTap: () => _handleChatTap(context, ref, chat, name, isLocked),
                      onLongPress: () => _showChatOptionsSheet(context, ref, chat, isLocked),
                      onAvatarTap: () {
                        final url = chat.avatarUrl;
                        if (url == null || url.isEmpty || chat.isGroup) {
                          _handleChatTap(context, ref, chat, name, isLocked);
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
                    ),
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

    return PopScope(
      canPop: false, // we decide when the app closes
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await AppDialogs.confirmExit(context);
        if (shouldExit) SystemNavigator.pop(); // closes the app
      },
      child: Scaffold(
        backgroundColor: p.surface,
        floatingActionButton: FloatingActionButton(
          backgroundColor: p.accent,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: () {
            AppHaptics.navigate();
            AppNav.push(context, const NewChatScreen());
          },
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            ChatUi.sliverHeader('Chats'),
            SliverToBoxAdapter(
              child: ChatSearchField(
                controller: _searchController,
                hint: 'Search chats',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            ...chatSlivers,
          ],
        ),
      ),
    );
  }
}
