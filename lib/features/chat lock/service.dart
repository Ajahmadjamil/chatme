import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Talks to the phone's secure storage.
// Nothing here knows about the UI or Riverpod.
class ChatLockService {
  final _storage = const FlutterSecureStorage();

  static const _pinKey = 'chat_lock_pin';
  static const _lockedIdsKey = 'chat_lock_locked_ids';

  Future<String?> getPin() => _storage.read(key: _pinKey);

  Future<void> savePin(String pin) => _storage.write(key: _pinKey, value: pin);

  // Locked chat ids are stored as one comma-separated string
  Future<Set<String>> getLockedChatIds() async {
    final raw = await _storage.read(key: _lockedIdsKey);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').toSet();
  }

  Future<void> saveLockedChatIds(Set<String> ids) async {
    await _storage.write(key: _lockedIdsKey, value: ids.join(','));
  }
}