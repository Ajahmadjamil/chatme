import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Streams the wallpaper_url of one chat, live.
// Both users watching this chat see the same value, in realtime.
final chatWallpaperStreamProvider =
StreamProvider.autoDispose.family<String?, String>((ref, chatId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('chats')
      .stream(primaryKey: ['id'])
      .eq('id', chatId)
      .map((rows) {
    if (rows.isEmpty) return null;
    return rows.first['wallpaper_url'] as String?;
  });
});

class ChatWallpaperActions {
  final _supabase = Supabase.instance.client;

  // Uploads the picked image to Storage, then saves its link on the chat.
  // Because "chats" is realtime-enabled, the other user's screen updates
  // automatically, without them doing anything.
  Future<void> setWallpaper(String chatId, File imageFile) async {
    final fileName = '${const Uuid().v4()}.jpg';
    final storagePath = '$chatId/$fileName';

    await _supabase.storage.from('wallpapers').upload(storagePath, imageFile);
    final publicUrl = _supabase.storage.from('wallpapers').getPublicUrl(storagePath);

    await _supabase.from('chats').update({'wallpaper_url': publicUrl}).eq('id', chatId);
  }

  Future<void> removeWallpaper(String chatId) async {
    await _supabase.from('chats').update({'wallpaper_url': null}).eq('id', chatId);
  }
}

final chatWallpaperActionsProvider =
Provider<ChatWallpaperActions>((ref) => ChatWallpaperActions());