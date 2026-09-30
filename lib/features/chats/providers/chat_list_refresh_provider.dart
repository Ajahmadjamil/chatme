import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_list_provider.dart';

/// Refresh chat list when messages or chat previews change.
final chatListRefresherProvider = StreamProvider<void>((ref) {
  final supabase = Supabase.instance.client;

  // Prefer chats stream: last_message_* is denormalized there.
  return supabase.from('chats').stream(primaryKey: ['id']).map((_) {
    ref.invalidate(chatListProvider);
  });
});
