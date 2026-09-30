import '/features/chat%20lock/service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


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

  @override
  ChatLockState build() {
    // Load which chats are locked as soon as the app starts
    _loadLockedIds();
    return const ChatLockState();
  }

  Future<void> _loadLockedIds() async {
    final ids = await _service.getLockedChatIds();
    state = state.copyWith(lockedChatIds: ids);
  }

  bool isLocked(String chatId) => state.lockedChatIds.contains(chatId);

  // True if the PIN was entered for this chat within the last 10 minutes
  bool isUnlockedNow(String chatId) {
    final expiry = state.unlockedUntil[chatId];
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  Future<bool> hasPinSet() async {
    final pin = await _service.getPin();
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) => _service.savePin(pin);

  Future<bool> verifyPin(String pin) async {
    final saved = await _service.getPin();
    return saved != null && saved == pin;
  }

  // Called after the user enters the correct PIN for a specific chat
  void markUnlocked(String chatId) {
    final updated = Map<String, DateTime>.from(state.unlockedUntil);
    updated[chatId] = DateTime.now().add(kUnlockDuration);
    state = state.copyWith(unlockedUntil: updated);
  }

  Future<void> lockChat(String chatId) async {
    final updated = Set<String>.from(state.lockedChatIds)..add(chatId);
    state = state.copyWith(lockedChatIds: updated);
    await _service.saveLockedChatIds(updated);
  }

  // Removes the lock entirely. The caller must verify the PIN before calling this.
  Future<void> removeLock(String chatId) async {
    final updatedLocked = Set<String>.from(state.lockedChatIds)..remove(chatId);
    final updatedUnlocked = Map<String, DateTime>.from(state.unlockedUntil)
      ..remove(chatId);
    state = state.copyWith(
      lockedChatIds: updatedLocked,
      unlockedUntil: updatedUnlocked,
    );
    await _service.saveLockedChatIds(updatedLocked);
  }
}

final chatLockProvider =
NotifierProvider<ChatLockNotifier, ChatLockState>(ChatLockNotifier.new);