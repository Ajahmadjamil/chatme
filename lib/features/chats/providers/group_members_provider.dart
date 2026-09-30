import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Returns a map of userId -> name for everyone in a group chat.
// Used to show "who sent this message" above each bubble in group chats.
final groupMembersProvider =
FutureProvider.family<Map<String, String>, String>((ref, chatId) async {
  final supabase = Supabase.instance.client;

  final rows = await supabase
      .from('chat_members')
      .select('user_id, profiles!inner(name)')
      .eq('chat_id', chatId);

  Map<String, String> namesById = {};

  for (var row in rows) {
    String userId = row['user_id'] as String;
    String name = row['profiles']['name'] as String;
    namesById[userId] = name;
  }

  return namesById;
});