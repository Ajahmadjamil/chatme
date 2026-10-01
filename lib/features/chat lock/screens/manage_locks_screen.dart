import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../chats/providers/chat_list_provider.dart';
import '../chat_lock_actions.dart';
import '../provider.dart';
import '../service.dart';
import 'set_pin_view.dart';

/// Profile → Chat locks. Caller must pass biometric before opening.
class ManageLocksScreen extends ConsumerWidget {
  const ManageLocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(chatLockProvider);
    final chatsAsync = ref.watch(chatListProvider);
    final shared = lock.mode == ChatLockMode.shared;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chat locks'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Lock mode',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile.adaptive(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                shared ? 'Same PIN for all chats' : 'Separate PIN per chat',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
              subtitle: Text(
                shared
                    ? 'One PIN covers every locked chat'
                    : 'Each locked chat gets its own PIN',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              value: shared,
              activeThumbColor: AppColors.primary,
              onChanged: (useShared) async {
                AppHaptics.select();
                final next =
                    useShared ? ChatLockMode.shared : ChatLockMode.separate;
                await ref.read(chatLockProvider.notifier).setMode(next);

                if (useShared) {
                  final has = await ref
                      .read(chatLockProvider.notifier)
                      .hasPinForLock();
                  if (!has && context.mounted) {
                    await AppNav.push<bool>(
                      context,
                      const SetPinScreen(isChange: false),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          if (shared)
            _ActionCard(
              icon: Icons.password_rounded,
              title: 'Change shared PIN',
              onTap: () async {
                AppHaptics.tap();
                await AppNav.push(
                  context,
                  const SetPinScreen(isChange: true),
                );
              },
            ),
          const SizedBox(height: 28),
          Text(
            'Locked chats',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          chatsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (chats) {
              final locked = chats
                  .where((c) => lock.lockedChatIds.contains(c.id))
                  .toList();

              if (locked.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No locked chats yet. Lock one from a chat’s menu.',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < locked.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          color: AppColors.divider,
                        ),
                      _LockedChatRow(
                        chatId: locked[i].id,
                        name: locked[i].otherUserName ??
                            (locked[i].isGroup ? 'Group' : 'Chat'),
                        isGroup: locked[i].isGroup,
                        separateMode: !shared,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedChatRow extends ConsumerWidget {
  final String chatId;
  final String name;
  final bool isGroup;
  final bool separateMode;

  const _LockedChatRow({
    required this.chatId,
    required this.name,
    required this.isGroup,
    required this.separateMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Icon(
          isGroup ? Icons.groups_outlined : Icons.lock_outline,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textMain,
        ),
      ),
      subtitle: Text(
        separateMode ? 'Separate PIN' : 'Shared PIN',
        style: TextStyle(color: AppColors.textGrey, fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: AppColors.textGrey),
        onSelected: (value) async {
          final notifier = ref.read(chatLockProvider.notifier);
          switch (value) {
            case 'change_pin':
              await AppNav.push(
                context,
                SetPinScreen(
                  chatId: separateMode ? chatId : null,
                  isChange: true,
                ),
              );
            case 'relock':
              notifier.clearSessionUnlock(chatId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name locked again')),
                );
              }
            case 'remove':
              final ok = await ChatLockActions.removeLock(
                context,
                ref,
                chatId: chatId,
              );
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lock removed from $name')),
                );
              }
          }
        },
        itemBuilder: (_) => [
          if (separateMode ||
              ref.read(chatLockProvider).mode == ChatLockMode.shared)
            const PopupMenuItem(
              value: 'change_pin',
              child: Text('Change PIN'),
            ),
          const PopupMenuItem(
            value: 'relock',
            child: Text('Lock again (clear session)'),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove lock'),
          ),
        ],
      ),
    );
  }
}
