import 'package:supabase_flutter/supabase_flutter.dart';

import 'model.dart';

// Talks to Supabase for everything related to auto-delete messages
class AutoClearService {
  final supabase = Supabase.instance.client;

  // Reads the current auto-clear setting (in minutes) for one chat
  Future<int?> getAutoClearMinutes(String chatId) async {
    final row = await supabase
        .from('chats')
        .select('auto_clear_minutes')
        .eq('id', chatId)
        .single();

    return row['auto_clear_minutes'] as int?;
  }

  Future<void> setAutoClearMinutes(String chatId, int? minutes) async {
    await supabase
        .from('chats')
        .update({'auto_clear_minutes': minutes})
        .eq('id', chatId);

    // Post a small announcement into the chat, WhatsApp-style
    final currentUserId = supabase.auth.currentUser!.id;
    final String announcement;
    if (minutes == null) {
      announcement = 'Auto-delete messages turned off';
    } else {
      final label = AutoClearOptionData.fromMinutes(minutes).label;
      announcement = 'Auto-delete messages set to $label';
    }

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'system',
      'content': announcement,
      'status': 'sent',
    });
  }

  // Works out when a NEW message should expire, based on the chat's
  // current auto-clear setting. Returns null if auto-clear is off.
  Future<DateTime?> calculateExpiry(String chatId) async {
    final minutes = await getAutoClearMinutes(chatId);
    if (minutes == null) return null;
    return DateTime.now().toUtc().add(Duration(minutes: minutes));
  }

  // Deletes messages in this chat whose time has already run out
  // Deletes messages in this chat whose time has already run out.
  // Returns how many messages were deleted, so the caller only
  // refreshes the UI when something actually changed.
  Future<int> deleteExpiredMessages(String chatId) async {
    final nowText = DateTime.now().toUtc().toIso8601String();

    final deletedRows = await supabase
        .from('messages')
        .delete()
        .eq('chat_id', chatId)
        .lt('expires_at', nowText)
        .select('id');

    return deletedRows.length;
  }
}