import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_model.dart';

/// Single round-trip chat list via `get_my_chat_list` RPC.
final chatListProvider = FutureProvider<List<ChatModel>>((ref) async {
  final supabase = Supabase.instance.client;

  final rows = await supabase.rpc('get_my_chat_list');

  return (rows as List)
      .map((row) => ChatModel.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList();
});
