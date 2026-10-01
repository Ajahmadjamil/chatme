import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ChatLockMode {
  /// One PIN unlocks / manages every locked chat.
  shared,

  /// Each locked chat has its own PIN.
  separate,
}

extension ChatLockModeX on ChatLockMode {
  String get storageValue => name;

  static ChatLockMode fromStorage(String? raw) {
    if (raw == ChatLockMode.separate.storageValue) {
      return ChatLockMode.separate;
    }
    return ChatLockMode.shared;
  }
}

/// Device-only storage for chat locks (not synced to Supabase).
class ChatLockService {
  final _storage = const FlutterSecureStorage();

  static const _modeKey = 'chat_lock_mode';
  static const _pinKey = 'chat_lock_pin';
  static const _perChatPinsKey = 'chat_lock_per_chat_pins';
  static const _lockedIdsKey = 'chat_lock_locked_ids';

  Future<ChatLockMode> getMode() async {
    final raw = await _storage.read(key: _modeKey);
    return ChatLockModeX.fromStorage(raw);
  }

  Future<void> saveMode(ChatLockMode mode) =>
      _storage.write(key: _modeKey, value: mode.storageValue);

  Future<String?> getSharedPin() => _storage.read(key: _pinKey);

  Future<void> saveSharedPin(String pin) =>
      _storage.write(key: _pinKey, value: pin);

  Future<void> clearSharedPin() => _storage.delete(key: _pinKey);

  Future<Map<String, String>> getPerChatPins() async {
    final raw = await _storage.read(key: _perChatPinsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> savePerChatPins(Map<String, String> pins) async {
    if (pins.isEmpty) {
      await _storage.delete(key: _perChatPinsKey);
      return;
    }
    await _storage.write(key: _perChatPinsKey, value: jsonEncode(pins));
  }

  Future<Set<String>> getLockedChatIds() async {
    final raw = await _storage.read(key: _lockedIdsKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((e) => e.isNotEmpty).toSet();
  }

  Future<void> saveLockedChatIds(Set<String> ids) async {
    if (ids.isEmpty) {
      await _storage.delete(key: _lockedIdsKey);
      return;
    }
    await _storage.write(key: _lockedIdsKey, value: ids.join(','));
  }
}
