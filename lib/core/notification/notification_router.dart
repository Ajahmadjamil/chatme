import 'dart:convert';

import 'package:flutter/material.dart';

import '../navigation/app_navigator.dart';
import '../../features/chats/screens/conversation_screens.dart';

/// Opens the right chat when the user taps a notification.
class NotificationRouter {
  /// Payload JSON: { "chat_id": "...", "chat_name": "...", "is_group": "true/false" }
  static void openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _openChat(
        chatId: data['chat_id'] as String?,
        chatName: data['chat_name'] as String? ?? 'Chat',
        isGroup: data['is_group']?.toString() == 'true',
      );
    } catch (_) {
      // Ignore bad payloads.
    }
  }

  /// FCM data map (string values).
  static void openFromData(Map<String, dynamic> data) {
    _openChat(
      chatId: data['chat_id'] as String?,
      chatName: data['chat_name'] as String? ?? 'Chat',
      isGroup: data['is_group']?.toString() == 'true',
    );
  }

  static void _openChat({
    required String? chatId,
    required String chatName,
    required bool isGroup,
  }) {
    if (chatId == null || chatId.isEmpty) return;

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          chatId: chatId,
          otherUserName: chatName,
          isGroup: isGroup,
        ),
      ),
    );
  }
}
