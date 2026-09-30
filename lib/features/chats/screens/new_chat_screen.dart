import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../core/shared/widgets/app_skeletons.dart';
import '../../../core/shared/widgets/user_avatar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_haptics.dart';
import '../providers/all_users_provider.dart';
import '../providers/chat_actions_provider.dart';
import '../providers/chat_list_provider.dart';
import 'conversation_screens.dart';
import 'create_group_screen.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // A small fixed palette so each avatar gets a nice, consistent color
  // based on the user's name (not random every rebuild).
  static const List<Color> _avatarPalette = [
    Color(0xFF3CB67C),
    Color(0xFF6C63FF),
    Color(0xFFFF7A59),
    Color(0xFF3B9AE1),
    Color(0xFFE55C8A),
    Color(0xFFF2B84B),
  ];

  Color _colorForName(String name) {
    if (name.isEmpty) return _avatarPalette.first;
    final index = name.codeUnitAt(0) % _avatarPalette.length;
    return _avatarPalette[index];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    // Colors of the currently selected theme
    final p = ref.watch(themeProvider).preset;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'New Chat',
          style: TextStyle(
            color: p.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: p.textMain),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Select a person to start chatting with',
                style: TextStyle(color: p.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // ---- Search box ----
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  style: TextStyle(color: p.textMain),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    hintStyle: TextStyle(color: p.icon, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: p.icon),
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ---- New group row ----
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.primary,
                    child: const Icon(Icons.group_add, color: Colors.white),
                  ),
                  title: Text(
                    'New group',
                    style: TextStyle(
                      color: p.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    AppNav.push(
      context,
      const CreateGroupScreen(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Contacts on app',
                style: TextStyle(
                  color: p.textMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),

              // ---- User list card ----
              Expanded(
                child: usersAsync.when(
                  data: (users) {
                    final filtered = _query.isEmpty
                        ? users
                        : users
                        .where((u) =>
                    u.name.toLowerCase().contains(_query) ||
                        u.email.toLowerCase().contains(_query))
                        .toList();

                    if (users.isEmpty) {
                      return _EmptyState(
                        icon: Icons.person_off_outlined,
                        message: 'No other users found',
                      );
                    }

                    if (filtered.isEmpty) {
                      return _EmptyState(
                        icon: Icons.search_off,
                        message: 'No matches for "$_query"',
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: p.divider,
                        ),
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final avatarColor = _colorForName(user.name);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                AppHaptics.tap();
                                _onUserTap(context, user);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    UserAvatar(
                                      name: user.name,
                                      avatarUrl: user.avatarUrl,
                                      radius: 22,
                                      backgroundColor:
                                          avatarColor.withOpacity(0.15),
                                      foregroundColor: avatarColor,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            style: TextStyle(
                                              color: p.textMain,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user.email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: p.textGrey,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: p.icon,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => AppSkeletons.userList(),
                  error: (err, stack) => _EmptyState(
                    icon: Icons.error_outline,
                    message: 'Error: $err',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Same logic as before, just moved into its own method ----
  Future<void> _onUserTap(BuildContext context, dynamic user) async {
    try {
      final chatId = await AppSkeletons.showBlockingOverlay(
        context: context,
        future: ref.read(chatActionsProvider).getOrCreateChat(user.id),
      );

      if (!context.mounted || chatId == null) return;

      AppNav.push(
        context,
        ConversationScreen(
          chatId: chatId,
          otherUserName: user.name,
          otherUserId: user.id,
          avatarUrl: user.avatarUrl,
        ),
      );
      ref.invalidate(chatListProvider);
    } catch (e) {
      debugPrint('getOrCreateChat error: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }
}

// Small reusable empty/error state widget for this screen
class _EmptyState extends ConsumerWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: p.icon),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: p.textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
