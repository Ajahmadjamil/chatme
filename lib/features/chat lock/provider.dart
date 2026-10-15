import 'package:chatme/features/chat%20lock/service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// How long a chat stays open after a correct PIN, before it locks again
const Duration kUnlockDuration = Duration(minutes: 10);

class ChatLockState {
  final Set<String> lockedChatIds; // chats the user has locked
  final Map<String, DateTime> unlockedUntil; // chatId -> when the unlock expires

  const ChatLockState({
    this.lockedChatIds = const {},
    this.unlockedUntil = const {},
  });

  ChatLockState copyWith({
    Set<String>? lockedChatIds,
    Map<String, DateTime>? unlockedUntil,
  }) {
    return ChatLockState(
      lockedChatIds: lockedChatIds ?? this.lockedChatIds,
      unlockedUntil: unlockedUntil ?? this.unlockedUntil,
    );
  }
}

class ChatLockNotifier extends Notifier<ChatLockState> {
  final _service = ChatLockService();

  // Which user the current state belongs to
  String? _userId;

  @override
  ChatLockState build() {
    _userId = Supabase.instance.client.auth.currentUser?.id;

    // When a different user logs in (or the user logs out), forget everything
    // and load the new user's locks
    final sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final newId = data.session?.user.id;
      if (newId == _userId) return; // same user (e.g. token refresh), do nothing
      _userId = newId;
      state = const ChatLockState();
      _loadLockedIds();
    });
    ref.onDispose(sub.cancel);

    _loadLockedIds();
    return const ChatLockState();
  }

  Future<void> _loadLockedIds() async {
    // Not logged in yet, so there is nothing to load
    if (Supabase.instance.client.auth.currentUser == null) return;
    final ids = await _service.getLockedChatIds();
    state = state.copyWith(lockedChatIds: ids);
  }

  bool isLocked(String chatId) => state.lockedChatIds.contains(chatId);

  // True if the PIN was entered for this chat within the last 10 minutes
  bool isUnlockedNow(String chatId) {
    final expiry = state.unlockedUntil[chatId];
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  // Sets the PIN for this chat and locks it
  Future<void> lockChat(String chatId, String pin) async {
    await _service.saveLock(chatId, pin);
    final updated = Set<String>.from(state.lockedChatIds)..add(chatId);
    state = state.copyWith(lockedChatIds: updated);
  }

  Future<bool> verifyPin(String chatId, String pin) {
    return _service.verifyPin(chatId, pin);
  }
  // Locks many chats with the same PIN/password (used by Manage Lock)
  Future<void> lockManyChats(
      List<String> chatIds, String secret, String type) async {
    final updated = Set<String>.from(state.lockedChatIds);
    for (final chatId in chatIds) {
      await _service.saveLock(chatId, secret, type: type);
      updated.add(chatId);
    }
    state = state.copyWith(lockedChatIds: updated);
  }

  // Removes the lock from many chats at once
  Future<void> removeManyLocks(List<String> chatIds) async {
    final updatedLocked = Set<String>.from(state.lockedChatIds);
    final updatedUnlocked = Map<String, DateTime>.from(state.unlockedUntil);
    for (final chatId in chatIds) {
      await _service.deleteLock(chatId);
      updatedLocked.remove(chatId);
      updatedUnlocked.remove(chatId);
    }
    state = state.copyWith(
      lockedChatIds: updatedLocked,
      unlockedUntil: updatedUnlocked,
    );
  }

  // 'pin' or 'password'
  Future<String> getLockType(String chatId) {
    return _service.getLockType(chatId);
  }
  // Called after the user enters the correct PIN for a specific chat
  void markUnlocked(String chatId) {
    final updated = Map<String, DateTime>.from(state.unlockedUntil);
    updated[chatId] = DateTime.now().add(kUnlockDuration);
    state = state.copyWith(unlockedUntil: updated);
  }

  // Removes the lock entirely. The caller must verify the PIN before calling this.
  Future<void> removeLock(String chatId) async {
    await _service.deleteLock(chatId);
    final updatedLocked = Set<String>.from(state.lockedChatIds)..remove(chatId);
    final updatedUnlocked = Map<String, DateTime>.from(state.unlockedUntil)
      ..remove(chatId);
    state = state.copyWith(
      lockedChatIds: updatedLocked,
      unlockedUntil: updatedUnlocked,
    );
  }
}

final chatLockProvider =
NotifierProvider<ChatLockNotifier, ChatLockState>(ChatLockNotifier.new);