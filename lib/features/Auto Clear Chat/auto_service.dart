import 'package:supabase_flutter/supabase_flutter.dart';

import 'model.dart';

/// Auto-delete settings + expiry helpers.
/// Global expiry cleanup runs on the DB via pg_cron; this still cleans
/// opportunistically when a chat is opened.
class AutoClearService {
  final supabase = Supabase.instance.client;

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

  Future<DateTime?> calculateExpiry(String chatId) async {
    final minutes = await getAutoClearMinutes(chatId);
    if (minutes == null) return null;
    return DateTime.now().toUtc().add(Duration(minutes: minutes));
  }

  /// Opportunistic cleanup for this chat; server cron also runs globally.
  Future<int> deleteExpiredMessages(String chatId) async {
    final count = await supabase.rpc(
      'cleanup_expired_messages_for_chat',
      params: {'p_chat_id': chatId},
    );
    return (count as num?)?.toInt() ?? 0;
  }

  /// Ask the DB to purge all expired messages (also scheduled via cron).
  Future<int> cleanupAllExpired() async {
    final count = await supabase.rpc('cleanup_expired_messages');
    return (count as num?)?.toInt() ?? 0;
  }
}
