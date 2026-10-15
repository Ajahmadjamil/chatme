import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_model.dart';

// Fetches all chats the current user is part of.
// For 1-on-1 chats: shows the other person's name.
// For group chats: shows the group name.
final chatListProvider = FutureProvider<List<ChatModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser!.id;

  //  get all chat_ids the current user belongs to
  // NEW: also select cleared_at, so we know if I "deleted" this chat before
  final myMemberships = await supabase
      .from('chat_members')
      .select('chat_id, cleared_at, left_at, chats!inner(id, is_group, name, created_at, avatar_url, created_by)')
      .eq('user_id', currentUserId);

  //  process every chat's extra lookups in PARALLEL.
  final futures = (myMemberships as List).map((row) async {
    final chatData = row['chats'];
    final chatId = chatData['id'] as String;
    final isGroup = chatData['is_group'] as bool? ?? false;

    //  when did I last "delete" this chat? (null if never deleted)
    final clearedAt = row['cleared_at'] != null
        ? DateTime.parse(row['cleared_at'] as String)
        : null;
    final leftAt = row['left_at'] != null
        ? DateTime.parse(row['left_at'] as String)
        : null;

    String displayName;
    String? avatarUrl;
    String? otherUsername;

    if (isGroup) {
      displayName = chatData['name'] as String? ?? 'Group';
      avatarUrl = chatData['avatar_url'] as String?;
    } else {
      final otherMember = await supabase
          .from('chat_members')
          .select('profiles!inner(name, username, avatar_url)') // CHANGED: username added
          .eq('chat_id', chatId)
          .neq('user_id', currentUserId)
          .maybeSingle();

      if (otherMember != null) {
        final otherProfile = otherMember['profiles'];
        final rawName = otherProfile['name'] as String;
        final username = otherProfile['username'] as String?;

        // Prefer the username if the user has set one, else fall back to name
        displayName = (username != null && username.isNotEmpty) ? username : rawName;
        otherUsername = username;
        avatarUrl = otherProfile['avatar_url'] as String?;
      } else {
        displayName = 'Unknown';
      }
    }

    // Get the last message — NEW: only messages sent AFTER I cleared this chat
    var lastMsgQuery = supabase
        .from('messages')
        .select('content, created_at')
        .eq('chat_id', chatId);

    if (clearedAt != null) {
      lastMsgQuery = lastMsgQuery.gt('created_at', clearedAt.toIso8601String());
    }

    // After I left, ignore anything sent later
    if (leftAt != null) {
      lastMsgQuery = lastMsgQuery.lte('created_at', leftAt.toIso8601String());
    }

    final lastMsg = await lastMsgQuery
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    // NEW: if I deleted this chat AND no new message has arrived since ->
    // hide it completely by returning null for this chat
    if (clearedAt != null && lastMsg == null) {
      return null;
    }

    String? lastMessage;
    DateTime? lastMessageAt;
    if (lastMsg != null) {
      lastMessage = lastMsg['content'] as String;
      lastMessageAt = DateTime.parse(lastMsg['created_at']);
    }

    // Count unread — NEW: only count messages after I cleared this chat
    var unreadQuery = supabase
        .from('messages')
        .select('id')
        .eq('chat_id', chatId)
        .neq('sender_id', currentUserId)
        .neq('status', 'read');

    if (clearedAt != null) {
      unreadQuery = unreadQuery.gt('created_at', clearedAt.toIso8601String());
    }

    final unreadRows = await unreadQuery;
    int unreadCount = (unreadRows as List).length;
    if (leftAt != null) unreadCount = 0;

    return ChatModel(
      id: chatId,
      isGroup: isGroup,
      createdAt: DateTime.parse(chatData['created_at']),
      otherUserName: displayName,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      avatarUrl: avatarUrl,
      createdBy: chatData['created_by'] as String?,
      otherUsername: otherUsername,
    );
  });

  // Wait for all chats to finish at once
  final results = await Future.wait(futures);

  // NEW: remove the hidden (null) chats — only keep the visible ones
  final chats = results.whereType<ChatModel>().toList();

  // Sort so most recently active chat shows on top
  chats.sort((a, b) {
    final aTime = a.lastMessageAt ?? a.createdAt;
    final bTime = b.lastMessageAt ?? b.createdAt;
    return bTime.compareTo(aTime);
  });

  return chats;
});