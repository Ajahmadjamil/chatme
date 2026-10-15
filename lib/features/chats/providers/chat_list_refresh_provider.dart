import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_list_provider.dart';
final chatListRefresherProvider = StreamProvider<void>((ref) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .map((_) {
    ref.invalidate(chatListProvider);
  });
});