import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/messages_model.dart';

const int kMessagePageSize = 50;

/// Paginated history + realtime inserts/updates/deletes for one chat.
final messagesProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, chatId) async* {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser!.id;

  final membership = await supabase
      .from('chat_members')
      .select('cleared_at')
      .eq('chat_id', chatId)
      .eq('user_id', currentUserId)
      .maybeSingle();

  if (!ref.mounted) return;

  final clearedAt = membership != null && membership['cleared_at'] != null
      ? DateTime.parse(membership['cleared_at'] as String)
      : null;

  bool visible(MessageModel m) {
    if (m.deletedAt != null) return false;
    if (clearedAt != null && !m.createdAt.isAfter(clearedAt)) return false;
    return true;
  }

  final initialRows = await supabase.rpc(
    'get_chat_messages',
    params: {
      'p_chat_id': chatId,
      'p_limit': kMessagePageSize,
      'p_before': null,
    },
  );

  if (!ref.mounted) return;

  var messages = (initialRows as List)
      .map((row) => MessageModel.fromJson(Map<String, dynamic>.from(row as Map)))
      .where(visible)
      .toList()
      .reversed
      .toList();

  final controller = StreamController<List<MessageModel>>();
  RealtimeChannel? channel;

  void emit() {
    if (!controller.isClosed) controller.add(_dedupe(List.of(messages)));
  }

  // Provider may have been disposed during the awaits above.
  if (!ref.mounted) {
    await controller.close();
    return;
  }

  ref.onDispose(() {
    final ch = channel;
    if (ch != null) {
      supabase.removeChannel(ch);
    }
    if (!controller.isClosed) controller.close();
  });

  controller.add(_dedupe(messages));

  final chatFilter = PostgresChangeFilter(
    type: PostgresChangeFilterType.eq,
    column: 'chat_id',
    value: chatId,
  );

  channel = supabase
      .channel('messages:$chatId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: chatFilter,
        callback: (payload) {
          final msg = MessageModel.fromJson(payload.newRecord);
          if (!visible(msg)) return;
          if (messages.any((m) => m.id == msg.id)) return;
          messages = [...messages, msg];
          emit();
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: chatFilter,
        callback: (payload) {
          final msg = MessageModel.fromJson(payload.newRecord);
          if (!visible(msg)) {
            messages = messages.where((m) => m.id != msg.id).toList();
          } else {
            final idx = messages.indexWhere((m) => m.id == msg.id);
            if (idx >= 0) {
              messages = [...messages]..[idx] = msg;
            } else {
              messages = [...messages, msg]
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            }
          }
          emit();
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'messages',
        filter: chatFilter,
        callback: (payload) {
          final id = payload.oldRecord['id'] as String?;
          if (id == null) return;
          messages = messages.where((m) => m.id != id).toList();
          emit();
        },
      )
      .subscribe();

  yield* controller.stream;
});

List<MessageModel> _dedupe(List<MessageModel> messages) {
  final seenIds = <String>{};
  final unique = <MessageModel>[];
  for (final m in messages) {
    if (seenIds.add(m.id)) unique.add(m);
  }
  return unique;
}
