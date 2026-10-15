import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/notification/push_notifier.dart';
import '../../Auto Clear Chat/auto_service.dart';

class ChatActions {
  final supabase = Supabase.instance.client;


  // Upload a document/file and send it as a message
  Future<void> sendFileMessage({
    required String chatId,
    required File file,
    required String fileName,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;


    final storagePath = '$chatId/${const Uuid().v4()}_$fileName';
    await supabase.storage.from('chat-media').upload(storagePath, file);
    final publicUrl = supabase.storage.from('chat-media').getPublicUrl(storagePath);
    final expiresAt = await AutoClearService().calculateExpiry(chatId);

    final inserted = await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'file',
      'media_url': publicUrl,
      'content': fileName, // shown as the file's display name
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    }).select().single();

    PushNotifier.notifyNewMessage(chatId: chatId, messageId: inserted['id'] as String);
  }

// Send the current GPS location as a message (a Google Maps link)
  // Send the current GPS location as a message (a Google Maps link).
// durationLabel is optional text like "15 minutes" chosen by the user.
  // Send the current GPS location. liveDurationMinutes is null for a
// one-time pin, or a number (15/60/480) for a "live" share.
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

    final inserted = await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'location',
      'media_url': mapUrl,
      'content': messageText,
      'duration_seconds': durationSecondsToStore, // reusing this column for live-share length
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    }).select().single();

    PushNotifier.notifyNewMessage(chatId: chatId, messageId: inserted['id'] as String);
  }

  // Ends an active live location share before its time runs out
  Future<void> stopLiveLocation(String messageId) async {
    await supabase.from('messages').update({
      'content': 'Live location ended',
      'duration_seconds': 0,
    }).eq('id', messageId);
  }
  // Copies one existing message into a different chat (forwarding).
  // Works for text, image, voice, file, and location messages.
  Future<void> forwardMessage({
    required String targetChatId,
    required dynamic message,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final expiresAt = await AutoClearService().calculateExpiry(targetChatId);

    final inserted = await supabase.from('messages').insert({
      'chat_id': targetChatId,
      'sender_id': currentUserId,
      'message_type': message.messageType,
      'media_url': message.mediaUrl,
      'content': message.content,
      'duration_seconds': message.durationSeconds,
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    }).select().single();

    PushNotifier.notifyNewMessage(chatId: targetChatId, messageId: inserted['id'] as String);
  }

  // Renames a group (admin only — screen enforces this before calling)
  Future<void> updateGroupName({
    required String chatId,
    required String newName,
  }) async {
    await supabase.from('chats').update({'name': newName}).eq('id', chatId);
  }

  // Uploads a new group photo and saves its URL
  Future<void> updateGroupAvatar({
    required String chatId,
    required File imageFile,
  }) async {
    final fileName = '${const Uuid().v4()}.jpg';
    final storagePath = 'group-avatars/$chatId/$fileName';

    await supabase.storage.from('chat-media').upload(storagePath, imageFile);
    final publicUrl = supabase.storage.from('chat-media').getPublicUrl(storagePath);

    await supabase.from('chats').update({'avatar_url': publicUrl}).eq('id', chatId);
  }

  // Posts "<name> left the group" for the others, then marks me as left
  Future<void> leaveGroup(String chatId) async {
    final currentUserId = supabase.auth.currentUser!.id;

    final me = await supabase
        .from('profiles')
        .select('name')
        .eq('id', currentUserId)
        .maybeSingle();
    final myName = (me?['name'] as String?)?.trim();
    final shownName = (myName == null || myName.isEmpty) ? 'Someone' : myName;

    // 1) System message first (I'm still a member, so this insert is allowed)
    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'content': '$shownName left the group',
      'message_type': 'system',
    });

    // 2) Then mark me as left
    await supabase
        .from('chat_members')
        .update({'left_at': DateTime.now().toUtc().toIso8601String()})
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }
  Future<String> getOrCreateChat(String otherUserId) async {
    final currentUserId = supabase.auth.currentUser!.id;

    // Step 1: get all the 1-on-1 chats I am part of
    final myChats = await supabase
        .from('chat_members')
        .select('chat_id, chats!inner(is_group)')
        .eq('user_id', currentUserId)
        .eq('chats.is_group', false);

    List<String> myChatIds = [];
    for (var row in myChats) {
      myChatIds.add(row['chat_id'] as String);
    }

    // Step 2: check if the other user is already in one of my chats
    if (myChatIds.isNotEmpty) {
      final match = await supabase
          .from('chat_members')
          .select('chat_id')
          .eq('user_id', otherUserId)
          .inFilter('chat_id', myChatIds)
          .maybeSingle();

      if (match != null) {
        String existingChatId = match['chat_id'] as String;
        return existingChatId;
      }
    }

    // Step 3: no existing chat found, so create a new one
    final newChatId = const Uuid().v4();

    await supabase.from('chats').insert({
      'id': newChatId,
      'is_group': false,
    });

    // Step 4: add both users as members of this new chat
    await supabase.from('chat_members').insert([
      {'chat_id': newChatId, 'user_id': currentUserId},
      {'chat_id': newChatId, 'user_id': otherUserId},
    ]);

    return newChatId;
  }

  // Create a new GROUP chat with a name and multiple members
  Future<String> createGroupChat({
    required String groupName,
    required List<String> memberIds,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final newChatId = const Uuid().v4();

    // Step 1: create the chat row with is_group = true and the group name
    await supabase.from('chats').insert({
      'id': newChatId,
      'is_group': true,
      'name': groupName,
      'created_by': currentUserId,
    });

    // Step 2: build a list of all members (me + everyone selected).
    // The creator starts out as an admin; everyone else does not.
    List<Map<String, dynamic>> membersToAdd = [];
    membersToAdd.add({'chat_id': newChatId, 'user_id': currentUserId, 'is_admin': true});

    for (var userId in memberIds) {
      membersToAdd.add({'chat_id': newChatId, 'user_id': userId, 'is_admin': false});
    }

    // Step 3: add everyone as a member in one go
    await supabase.from('chat_members').insert(membersToAdd);

    return newChatId;
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String content,
    String? replyToId, // NEW
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;
    final expiresAt = await AutoClearService().calculateExpiry(chatId);

    final inserted = await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'content': content,
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
      'reply_to_id': replyToId, // NEW
    }).select().single();

    PushNotifier.notifyNewMessage(chatId: chatId, messageId: inserted['id'] as String);
  }


  // Mark the other user's messages as 'read'
  Future<void> markMessagesAsRead(String chatId) async {
    final currentUserId = supabase.auth.currentUser!.id;

    await supabase
        .from('messages')
        .update({'status': 'read'})
        .eq('chat_id', chatId)
        .neq('sender_id', currentUserId)
        .neq('status', 'read');
  }
  // Edit an existing message's text
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    await supabase
        .from('messages')
        .update({'content': newContent})
        .eq('id', messageId);
  }

  // Removes the message for EVERYONE (only works because of the
  // sender-only RLS policy — recipients can't call this on others' messages)
  Future<void> deleteForEveryone(String messageId) async {
    await supabase.from('messages').update({
      'content': 'This message was deleted',
      'message_type': 'deleted',
      'media_url': null,
      'duration_seconds': null,
    }).eq('id', messageId);
  }

  // Hides the message only on THIS account, the other person still sees it
  Future<void> deleteForMe(String messageId) async {
    await supabase.rpc('delete_message_for_me', params: {'target_message_id': messageId});
  }
  // "Delete chat" — hides it for ME only, other person still sees it normally
  Future<void> clearChatForMe(String chatId) async {
    final currentUserId = supabase.auth.currentUser!.id;

    await supabase
        .from('chat_members')
        .update({'cleared_at': DateTime.now().toUtc().toIso8601String()})
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }
  // Upload an image file to Supabase Storage and send it as a message
  Future<void> sendImageMessage({
    required String chatId,
    required File imageFile,
    String? caption,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;

    // Create a unique file name so images never overwrite each other
    final fileName = '${const Uuid().v4()}.jpg';
    final storagePath = '$chatId/$fileName';

    // Upload the file bytes to Supabase Storage
    await supabase.storage.from('chat-media').upload(storagePath, imageFile);
    final expiresAt = await AutoClearService().calculateExpiry(chatId);

    // Get the public URL for this uploaded file
    final publicUrl = supabase.storage.from('chat-media').getPublicUrl(storagePath);

    // Save the message with type 'image' and the file's URL
    final inserted = await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'image',
      'media_url': publicUrl,
      'content': (caption != null && caption.isNotEmpty) ? caption : '📷 Photo',
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    }).select().single();

    PushNotifier.notifyNewMessage(chatId: chatId, messageId: inserted['id'] as String);
  }
  // Sends a sticker picked from Giphy. We just save the sticker's image
  // URL — no upload needed, since Giphy hosts the image itself.
  Future<void> sendStickerMessage({
    required String chatId,
    required String stickerImageUrl,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;

    final inserted = await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'sticker',
      'media_url': stickerImageUrl,
      'content': 'Sticker',
      'status': 'sent',
    }).select().single();

    PushNotifier.notifyNewMessage(chatId: chatId, messageId: inserted['id'] as String);
  }
  // Upload a voice recording to Supabase Storage and send it as a message
  Future<void> sendVoiceMessage({
    required String chatId,
    required File audioFile,
    required int durationSeconds,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;

    // Unique file name, same pattern as images
    final fileName = '${const Uuid().v4()}.m4a';
    final storagePath = '$chatId/$fileName';
    final minutes = durationSeconds ~/ 60;
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    final durationText = '$minutes:$seconds';
    final expiresAt = await AutoClearService().calculateExpiry(chatId);

    // Upload the audio file bytes to Supabase Storage (same bucket as images)
    await supabase.storage.from('chat-media').upload(storagePath, audioFile);


    // Get the public URL for this uploaded file
    final publicUrl = supabase.storage.from('chat-media').getPublicUrl(storagePath);

    // Save the message with type 'voice', the file's URL, and its duration
    final inserted = await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'voice',
      'media_url': publicUrl,
      'duration_seconds': durationSeconds,
      'content': '$durationText',
      'status': 'sent',
      'expires_at': expiresAt?.toIso8601String(),
    }).select().single();

    PushNotifier.notifyNewMessage(chatId: chatId, messageId: inserted['id'] as String);
  }
  // Adds new people to an existing group, as regular (non-admin) members,
// and posts "<name> was added to the group" for each of them
  Future<void> addGroupMembers({
    required String chatId,
    required List<String> userIds,
  }) async {
    if (userIds.isEmpty) return;

    List<Map<String, dynamic>> rows = [];
    for (var userId in userIds) {
      rows.add({
        'chat_id': chatId,
        'user_id': userId,
        'is_admin': false,
      });
    }
    await supabase.from('chat_members').insert(rows);

    // Naam nikalo taake message mein dikha sakein
    final profiles = await supabase
        .from('profiles')
        .select('id, name')
        .inFilter('id', userIds);

    for (final row in profiles) {
      final name = (row['name'] as String?)?.trim();
      final shownName = (name == null || name.isEmpty) ? 'Someone' : name;
      await _postSystemMessage(chatId, '$shownName was added to the group');
    }
  }
  // Admin action: removes a member from the group entirely
  // Admin action: removes a member from the group entirely, and posts
  // a system message so everyone sees it happened
  Future<void> removeGroupMember({
    required String chatId,
    required String userId,
    required String memberName,
  }) async {
    await supabase
        .from('chat_members')
        .delete()
        .eq('chat_id', chatId)
        .eq('user_id', userId);

    await _postSystemMessage(chatId, '$memberName was removed from the group');
  }

  // Admin action: gives someone else admin rights
  Future<void> makeGroupAdmin({
    required String chatId,
    required String userId,
    required String memberName,
  }) async {
    await supabase
        .from('chat_members')
        .update({'is_admin': true})
        .eq('chat_id', chatId)
        .eq('user_id', userId);

    await _postSystemMessage(chatId, '$memberName is now an admin');
  }

  // Admin action: takes admin rights away from someone
  Future<void> removeGroupAdmin({
    required String chatId,
    required String userId,
    required String memberName,
  }) async {
    await supabase
        .from('chat_members')
        .update({'is_admin': false})
        .eq('chat_id', chatId)
        .eq('user_id', userId);

    await _postSystemMessage(chatId, '$memberName is no longer an admin');
  }

  // Small helper so these 3 actions all post their announcement
  // the same way auto-delete settings already do
  Future<void> _postSystemMessage(String chatId, String text) async {
    final currentUserId = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'system',
      'content': text,
      'status': 'sent',
    });
  }
}
final chatActionsProvider = Provider<ChatActions>((ref) => ChatActions());