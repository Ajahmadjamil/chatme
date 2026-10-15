import 'dart:io';
import 'package:chatme/features/chats/Groups/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_dialogs.dart';
import '../providers/chat_actions_provider.dart';
import '../providers/chat_list_provider.dart';
import '../providers/message_provider.dart';
import 'add_memebers_view.dart' show AddMembersScreen;


class GroupInfoScreen extends ConsumerStatefulWidget {
  final String chatId;
  const GroupInfoScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _isUploadingAvatar = false;

  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  // Reload this screen's data and the Home list
  void _refreshAll() {
    ref.invalidate(messagesProvider(widget.chatId));
    ref.invalidate(groupInfoProvider(widget.chatId));
    ref.invalidate(chatListProvider);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Admin only: pick a photo and upload it as the group photo
  Future<void> _changeAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(chatActionsProvider).updateGroupAvatar(
        chatId: widget.chatId,
        imageFile: File(picked.path),
      );
      _refreshAll();
    } catch (e) {
      _showError('Failed to update photo: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // Admin only: rename the group
  Future<void> _renameGroup(String currentName) async {
    final newName = await AppDialogs.editText(
      context,
      title: 'Group name',
      initialText: currentName,
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      await ref.read(chatActionsProvider).updateGroupName(
        chatId: widget.chatId,
        newName: newName,
      );
      _refreshAll();
    } catch (e) {
      _showError('Failed to rename group: $e');
    }
  }
  // Admin only: pick people and add them to this group
  Future<void> _addMembers(GroupInfo info) async {
    final ids = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMembersScreen(
          existingMemberIds: info.members.map((m) => m.id).toSet(),
        ),
      ),
    );
    if (ids == null || ids.isEmpty) return;

    try {
      await ref.read(chatActionsProvider).addGroupMembers(
        chatId: widget.chatId,
        userIds: ids,
      );
      _refreshAll();
    } catch (e) {
      _showError('Failed to add members: $e');
    }
  }
  // Everyone: leave the group, then go back to Home
  Future<void> _exitGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit group?'),
        content: const Text('You will no longer receive messages from this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(chatActionsProvider).leaveGroup(widget.chatId);
      ref.invalidate(groupInfoProvider(widget.chatId));
      ref.invalidate(hasLeftGroupProvider(widget.chatId));
      ref.invalidate(messagesProvider(widget.chatId)); // <- ye add karo
      ref.invalidate(chatListProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to exit group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(themeProvider).preset;
    final infoAsync = ref.watch(groupInfoProvider(widget.chatId));

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.header,
        foregroundColor: Colors.white,
        elevation: 1,
        title: const Text('Group info'),
      ),
      body: infoAsync.when(
        data: (info) {
          final bool isAdmin = info.amIAdmin && !info.iLeft;
          final bool hasAvatar = info.avatarUrl != null && info.avatarUrl!.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 24),

              // ---- Group photo (camera badge only for admin) ----
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: p.primary.withOpacity(0.15),
                      backgroundImage: hasAvatar ? NetworkImage(info.avatarUrl!) : null,
                      child: hasAvatar
                          ? null
                          : Icon(Icons.groups_rounded, size: 52, color: p.primary),
                    ),
                    if (isAdmin)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _isUploadingAvatar ? null : _changeAvatar,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: p.primary,
                            child: _isUploadingAvatar
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Group name (pencil only for admin) ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        info.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: p.textMain,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: Icon(Icons.edit, size: 20, color: p.primary),
                        onPressed: () => _renameGroup(info.name),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${info.members.length} members',
                  style: TextStyle(color: p.textGrey, fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 24),
              // ---- Add members (admin only) ----
              if (isAdmin)
                Container(
                  color: p.surface,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.primary,
                      child: const Icon(Icons.person_add, color: Colors.white),
                    ),
                    title: Text(
                      'Add members',
                      style: TextStyle(
                        color: p.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _addMembers(info),
                  ),
                ),
              // ---- Members list ----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.textMain,
                  ),
                ),
              ),
              Container(
                color: p.surface,
                child: Column(
                  children: info.members.map((m) {
                    final bool isMe = m.id == _myId;
                    final bool isMemberAdmin = m.isAdmin;
                    final bool memberHasAvatar =
                        m.avatarUrl != null && m.avatarUrl!.isNotEmpty;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p.primary.withOpacity(0.15),
                        backgroundImage:
                        memberHasAvatar ? NetworkImage(m.avatarUrl!) : null,
                        child: memberHasAvatar
                            ? null
                            : Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: p.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        isMe ? '${m.name} (You)' : m.name,
                        style: TextStyle(
                          color: p.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        m.email,
                        style: TextStyle(color: p.textGrey, fontSize: 12.5),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMemberAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  color: p.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          // Admin controls menu — shown only to admins, and
                          // never on my own row
                          if (isAdmin && !isMe)
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: p.icon, size: 20),
                              onSelected: (value) => _handleMemberAction(value, m),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: isMemberAdmin ? 'remove_admin' : 'make_admin',
                                  child: Text(isMemberAdmin ? 'Remove as admin' : 'Make admin'),
                                ),
                                const PopupMenuItem(
                                  value: 'remove_member',
                                  child: Text('Remove from group', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Exit group (everyone) ----
              if (!info.iLeft)
              Container(
                color: p.surface,
                child: ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text(
                    'Exit group',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  onTap: _exitGroup,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
  // Runs whichever admin action was picked from a member's menu
  Future<void> _handleMemberAction(String action, GroupMemberInfo member) async {
    try {
      if (action == 'make_admin') {
        await ref.read(chatActionsProvider).makeGroupAdmin(
          chatId: widget.chatId,
          userId: member.id,
          memberName: member.name,
        );
      } else if (action == 'remove_admin') {
        await ref.read(chatActionsProvider).removeGroupAdmin(
          chatId: widget.chatId,
          userId: member.id,
          memberName: member.name,
        );
      } else if (action == 'remove_member') {
        await ref.read(chatActionsProvider).removeGroupMember(
          chatId: widget.chatId,
          userId: member.id,
          memberName: member.name,
        );
      }
      _refreshAll();
    } catch (e) {
      _showError('Action failed: $e');
    }
  }
}