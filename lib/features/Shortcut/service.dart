import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Small data holder: the chat that a shortcut points to.
class ShortcutChat {
  final String chatId;
  final String name;
  final bool isGroup;

  const ShortcutChat({
    required this.chatId,
    required this.name,
    required this.isGroup,
  });

  factory ShortcutChat.fromMap(Map<dynamic, dynamic> map) {
    return ShortcutChat(
      chatId: map['chatId'] as String,
      name: map['name'] as String,
      isGroup: map['isGroup'] as bool,
    );
  }
}

/// Talks to the native Android code (MainActivity.kt).
class ChatShortcutService {
  static const _channel = MethodChannel('chat_shortcut');

  /// Ask Android to pin a shortcut of this chat on the home screen.
  Future<bool> pinChat({
    required String chatId,
    required String name,
    required bool isGroup,
  }) async {
    final ok = await _channel.invokeMethod<bool>('pinShortcut', {
      'chatId': chatId,
      'name': name,
      'isGroup': isGroup,
    });
    return ok ?? false;
  }

  /// Returns the chat if the app was started by tapping a shortcut.
  Future<ShortcutChat?> getInitialChat() async {
    final map = await _channel.invokeMethod<Map>('getInitialChat');
    return map == null ? null : ShortcutChat.fromMap(map);
  }

  /// Called when a shortcut is tapped while the app is already running.
  void listenToTaps(void Function(ShortcutChat chat) onTap) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShortcutTapped') {
        onTap(ShortcutChat.fromMap(call.arguments as Map));
      }
    });
  }
}

final chatShortcutServiceProvider = Provider<ChatShortcutService>((ref) {
  return ChatShortcutService();
});