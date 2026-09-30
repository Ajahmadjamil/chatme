import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../Auto Clear Chat/auto_service.dart';

class ChatActions {
  final supabase = Supabase.instance.client;

  Future<void> sendFileMessage({
    required String chatId,
    required File file,
    required String fileName,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final storagePath = '$chatId/${const Uuid().v4()}_$fileName';
    await supabase.storage.from('chat-media').upload(storagePath, file);
    final publicUrl =
        supabase.storage.from('chat-media').getPublicUrl(storagePath);
    final expiresAt = await AutoClearService().calculateExpiry(chatId);

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'file',
      'media_url': publicUrl,
      'content': fileName,
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    });
  }

  Future<void> sendLocationMessage({
    required String chatId,
    required double latitude,
    required double longitude,
    int? liveDurationMinutes,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final mapUrl = 'https://www.google.com/maps?q=$latitude,$longitude';

    String messageText = 'Location';
    int? durationSecondsToStore;
    final expiresAt = await AutoClearService().calculateExpiry(chatId);
    if (liveDurationMinutes != null) {
      messageText = 'Live location';
      durationSecondsToStore = liveDurationMinutes * 60;
    }

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'location',
      'media_url': mapUrl,
      'content': messageText,
      'duration_seconds': durationSecondsToStore,
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    });
  }

  Future<void> stopLiveLocation(String messageId) async {
    await supabase.from('messages').update({
      'content': 'Live location ended',
      'duration_seconds': 0,
    }).eq('id', messageId);
  }

  Future<void> forwardMessage({
    required String targetChatId,
    required dynamic message,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final expiresAt = await AutoClearService().calculateExpiry(targetChatId);

    await supabase.from('messages').insert({
      'chat_id': targetChatId,
      'sender_id': currentUserId,
      'message_type': message.messageType,
      'media_url': message.mediaUrl,
      'content': message.content,
      'duration_seconds': message.durationSeconds,
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    });
  }

  /// Find or create a 1:1 chat (atomic server-side RPC).
  Future<String> getOrCreateChat(String otherUserId) async {
    final chatId = await supabase.rpc(
      'get_or_create_dm',
      params: {'other_user_id': otherUserId},
    );
    return chatId as String;
  }

  /// Create a group with the current user as owner.
  Future<String> createGroupChat({
    required String groupName,
    required List<String> memberIds,
  }) async {
    final chatId = await supabase.rpc(
      'create_group_chat',
      params: {
        'p_group_name': groupName,
        'p_member_ids': memberIds,
      },
    );
    return chatId as String;
  }

  Future<void> sendMessage({
    required String chatId,
    required String content,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final expiresAt = await AutoClearService().calculateExpiry(chatId);

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'content': content,
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    });
  }

  /// Per-member read cursor (does not mutate shared message.status).
  Future<void> markMessagesAsRead(String chatId) async {
    await supabase.rpc('mark_chat_read', params: {'p_chat_id': chatId});
  }

  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    await supabase.from('messages').update({
      'content': newContent,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  /// Soft-delete so chat preview trigger can recompute cleanly.
  Future<void> deleteMessage(String messageId) async {
    await supabase.from('messages').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'content': '',
    }).eq('id', messageId);
  }

  Future<void> clearChatForMe(String chatId) async {
    final currentUserId = supabase.auth.currentUser!.id;

    await supabase
        .from('chat_members')
        .update({
          'cleared_at': DateTime.now().toUtc().toIso8601String(),
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }

  Future<void> sendImageMessage({
    required String chatId,
    required File imageFile,
    String? caption,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final fileName = '${const Uuid().v4()}.jpg';
    final storagePath = '$chatId/$fileName';

    await supabase.storage.from('chat-media').upload(storagePath, imageFile);
    final expiresAt = await AutoClearService().calculateExpiry(chatId);
    final publicUrl =
        supabase.storage.from('chat-media').getPublicUrl(storagePath);

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'image',
      'media_url': publicUrl,
      'content':
          (caption != null && caption.isNotEmpty) ? caption : '📷 Photo',
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    });
  }

  Future<void> sendVoiceMessage({
    required String chatId,
    required File audioFile,
    required int durationSeconds,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final fileName = '${const Uuid().v4()}.m4a';
    final storagePath = '$chatId/$fileName';
    final minutes = durationSeconds ~/ 60;
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    final durationText = '$minutes:$seconds';
    final expiresAt = await AutoClearService().calculateExpiry(chatId);

    await supabase.storage.from('chat-media').upload(storagePath, audioFile);
    final publicUrl =
        supabase.storage.from('chat-media').getPublicUrl(storagePath);

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'voice',
      'media_url': publicUrl,
      'duration_seconds': durationSeconds,
      'content': durationText,
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    });
  }
}

final chatActionsProvider = Provider<ChatActions>((ref) => ChatActions());
