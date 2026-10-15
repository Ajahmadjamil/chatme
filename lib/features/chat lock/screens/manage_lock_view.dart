import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../chats/providers/chat_list_provider.dart';
import '../phone_lock_service.dart';
import '../provider.dart';
import 'set_secret_view.dart';

// Pick many chats, then set / reset / remove their lock in one go
class ManageLockScreen extends ConsumerStatefulWidget {
  const ManageLockScreen({super.key});

  @override
  ConsumerState<ManageLockScreen> createState() => _ManageLockScreenState();
}

class _ManageLockScreenState extends ConsumerState<ManageLockScreen> {
  final Set<String> _selected = {};
  final PhoneLockService _phoneLock = PhoneLockService();
  bool _isWorking = false;

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _toggleOne(String chatId) {
    setState(() {
      if (_selected.contains(chatId)) {
        _selected.remove(chatId);
      } else {
        _selected.add(chatId);
      }
    });
  }

  void _toggleAll(List<String> allIds) {
    setState(() {
      if (_selected.length == allIds.length) {
        _selected.clear();
      } else {
        _selected.clear();
        _selected.addAll(allIds);
      }
    });
  }

  // Extra privacy check: the phone's own PIN / pattern / fingerprint
  Future<bool> _passPhoneLock() async {
    final available = await _phoneLock.isAvailable();
    if (!available) {
      _showMessage('Please set a screen lock on your phone first');
      return false;
    }

    final passed = await _phoneLock.verify();
    if (!passed) {
      _showMessage('Phone lock check failed');
      return false;
    }
    return true;
  }

  // "Set lock" and "Reset" do the same thing: new PIN/password for the selection
  Future<void> _onSetPressed() async {
    final passed = await _passPhoneLock();
    if (!passed || !mounted) return;

    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SetSecretScreen(chatIds: _selected.toList()),
      ),
    );

    if (done == true && mounted) {
      setState(() => _selected.clear());
      _showMessage('Lock saved');
    }
  }

  Future<void> _onRemovePressed() async {
    final passed = await _passPhoneLock();
    if (!passed || !mounted) return;

    // Only the chats that are really locked need to be unlocked
    final lockedNow = ref.read(chatLockProvider).lockedChatIds;
    List<String> toRemove = [];
    for (final id in _selected) {
      if (lockedNow.contains(id)) {
        toRemove.add(id);
      }
    }

    setState(() => _isWorking = true);
    try {
      await ref.read(chatLockProvider.notifier).removeManyLocks(toRemove);
      if (!mounted) return;
      setState(() => _selected.clear());
      _showMessage('Lock removed');
    } catch (e) {
      _showMessage('Could not remove lock, check your internet');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(themeProvider).preset;
    final chatsAsync = ref.watch(chatListProvider);
    final lockedIds = ref.watch(chatLockProvider).lockedChatIds;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.header,
        foregroundColor: Colors.white,
        elevation: 1,
        title: const Text('Manage lock'),
      ),
      body: chatsAsync.when(
        data: (chats) {
          // All chat ids, used by "Select all"
          List<String> allIds = [];
          for (final chat in chats) {
            allIds.add(chat.id);
          }
          final bool allSelected =
              allIds.isNotEmpty && _selected.length == allIds.length;

          // Is at least one selected chat already locked?
          bool hasLockedSelected = false;
          for (final id in _selected) {
            if (lockedIds.contains(id)) {
              hasLockedSelected = true;
            }
          }

          if (chats.isEmpty) {
            return Center(
              child: Text('No chats yet', style: TextStyle(color: p.textGrey)),
            );
          }

          return Column(
            children: [
              // ---- Select all ----
              Container(
                color: p.surface,
                child: CheckboxListTile(
                  value: allSelected,
                  activeColor: p.primary,
                  onChanged: (_) => _toggleAll(allIds),
                  title: Text(
                    'Select all',
                    style: TextStyle(
                      color: p.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: p.divider),

              // ---- Chat list ----
              Expanded(
                child: ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final String name = chat.otherUserName ?? 'Unknown';
                    final String? avatarUrl = chat.avatarUrl;
                    final bool hasAvatar =
                        avatarUrl != null && avatarUrl.isNotEmpty;
                    final bool isLocked = lockedIds.contains(chat.id);
                    final bool isSelected = _selected.contains(chat.id);

                    return ListTile(
                      onTap: () => _toggleOne(chat.id),
                      leading: CircleAvatar(
                        backgroundColor: p.primary.withOpacity(0.15),
                        backgroundImage:
                        hasAvatar ? NetworkImage(avatarUrl!) : null,
                        child: hasAvatar
                            ? null
                            : (chat.isGroup
                            ? Icon(Icons.group, color: p.primary)
                            : Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: p.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: p.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLocked)
                            Icon(Icons.lock, size: 18, color: p.primary),
                          Checkbox(
                            value: isSelected,
                            activeColor: p.primary,
                            onChanged: (_) => _toggleOne(chat.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ---- Action buttons (only when something is selected) ----
              if (_selected.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        if (hasLockedSelected) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isWorking ? null : _onRemovePressed,
                              child: const Text('Remove lock'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isWorking ? null : _onSetPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              hasLockedSelected
                                  ? 'Reset (${_selected.length})'
                                  : 'Set lock (${_selected.length})',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: p.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}