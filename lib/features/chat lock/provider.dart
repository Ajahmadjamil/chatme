import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service.dart';

/// How long a chat stays open after a successful biometric unlock.
const Duration kUnlockDuration = Duration(minutes: 10);

class ChatLockState {
  final ChatLockMode mode;
  final Set<String> lockedChatIds;
  final Map<String, DateTime> unlockedUntil;
  final bool loaded;

  const ChatLockState({
    this.mode = ChatLockMode.shared,
    this.lockedChatIds = const {},
    this.unlockedUntil = const {},
    this.loaded = false,
  });

  ChatLockState copyWith({
    ChatLockMode? mode,
    Set<String>? lockedChatIds,
    Map<String, DateTime>? unlockedUntil,
    bool? loaded,
  }) {
    return ChatLockState(
      mode: mode ?? this.mode,
      lockedChatIds: lockedChatIds ?? this.lockedChatIds,
      unlockedUntil: unlockedUntil ?? this.unlockedUntil,
      loaded: loaded ?? this.loaded,
    );
  }
}

class ChatLockNotifier extends Notifier<ChatLockState> {
  final _service = ChatLockService();

  @override
  ChatLockState build() {
    _load();
    return const ChatLockState();
  }

  Future<void> _load() async {
    final mode = await _service.getMode();
    final ids = await _service.getLockedChatIds();
    state = state.copyWith(
      mode: mode,
      lockedChatIds: ids,
      loaded: true,
    );
  }

  bool isLocked(String chatId) => state.lockedChatIds.contains(chatId);

  bool isUnlockedNow(String chatId) {
    final expiry = state.unlockedUntil[chatId];
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  Future<bool> hasPinForLock({String? chatId}) async {
    if (state.mode == ChatLockMode.shared) {
      final pin = await _service.getSharedPin();
      return pin != null && pin.isNotEmpty;
    }
    if (chatId == null) return false;
    final pins = await _service.getPerChatPins();
    final pin = pins[chatId];
    return pin != null && pin.isNotEmpty;
  }

  /// Shared-mode PIN, or a specific chat's PIN in separate mode.
  Future<void> setPin(String pin, {String? chatId}) async {
    if (state.mode == ChatLockMode.shared || chatId == null) {
      await _service.saveSharedPin(pin);
      return;
    }
    final pins = await _service.getPerChatPins();
    pins[chatId] = pin;
    await _service.savePerChatPins(pins);
  }

  Future<bool> verifyPin(String pin, {String? chatId}) async {
    if (state.mode == ChatLockMode.shared) {
      final saved = await _service.getSharedPin();
      return saved != null && saved == pin;
    }
    if (chatId == null) return false;
    final pins = await _service.getPerChatPins();
    return pins[chatId] == pin;
  }

  void markUnlocked(String chatId) {
    final updated = Map<String, DateTime>.from(state.unlockedUntil);
    updated[chatId] = DateTime.now().add(kUnlockDuration);
    state = state.copyWith(unlockedUntil: updated);
  }

  void clearSessionUnlock(String chatId) {
    final updated = Map<String, DateTime>.from(state.unlockedUntil)
      ..remove(chatId);
    state = state.copyWith(unlockedUntil: updated);
  }

  Future<void> lockChat(String chatId) async {
    final updated = Set<String>.from(state.lockedChatIds)..add(chatId);
    state = state.copyWith(lockedChatIds: updated);
    await _service.saveLockedChatIds(updated);
  }

  Future<void> removeLock(String chatId) async {
    final updatedLocked = Set<String>.from(state.lockedChatIds)..remove(chatId);
    final updatedUnlocked = Map<String, DateTime>.from(state.unlockedUntil)
      ..remove(chatId);
    state = state.copyWith(
      lockedChatIds: updatedLocked,
      unlockedUntil: updatedUnlocked,
    );
    await _service.saveLockedChatIds(updatedLocked);

    if (state.mode == ChatLockMode.separate) {
      final pins = await _service.getPerChatPins()..remove(chatId);
      await _service.savePerChatPins(pins);
    }
  }

  Future<void> setMode(ChatLockMode mode) async {
    if (mode == state.mode) return;

    if (mode == ChatLockMode.separate) {
      // Seed each locked chat with the current shared PIN (if any).
      final shared = await _service.getSharedPin();
      if (shared != null && shared.isNotEmpty) {
        final pins = await _service.getPerChatPins();
        for (final id in state.lockedChatIds) {
          pins.putIfAbsent(id, () => shared);
        }
        await _service.savePerChatPins(pins);
      }
    } else {
      // Prefer an existing shared PIN; else pick any per-chat PIN.
      var shared = await _service.getSharedPin();
      if (shared == null || shared.isEmpty) {
        final pins = await _service.getPerChatPins();
        if (pins.isNotEmpty) {
          shared = pins.values.first;
          await _service.saveSharedPin(shared);
        }
      }
    }

    await _service.saveMode(mode);
    state = state.copyWith(mode: mode);
  }

  Future<void> changeSharedPin(String newPin) async {
    await _service.saveSharedPin(newPin);
  }

  Future<void> changeChatPin(String chatId, String newPin) async {
    final pins = await _service.getPerChatPins();
    pins[chatId] = newPin;
    await _service.savePerChatPins(pins);
  }
}

final chatLockProvider =
    NotifierProvider<ChatLockNotifier, ChatLockState>(ChatLockNotifier.new);
