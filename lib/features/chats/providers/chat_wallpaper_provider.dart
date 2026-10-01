import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Shared per-chat wallpaper URL (Supabase). Same image for every member.
class ChatWallpaperNotifier extends AsyncNotifier<String?> {
  ChatWallpaperNotifier(this.chatId);

  final String chatId;
  RealtimeChannel? _channel;

  @override
  Future<String?> build() async {
    final supabase = Supabase.instance.client;

    ref.onDispose(() {
      if (_channel != null) {
        supabase.removeChannel(_channel!);
        _channel = null;
      }
    });

    _channel = supabase
        .channel('chat-wallpaper-$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: chatId,
          ),
          callback: (payload) {
            final url = payload.newRecord['wallpaper_url'] as String?;
            state = AsyncData(url);
          },
        )
        .subscribe();

    final row = await supabase
        .from('chats')
        .select('wallpaper_url')
        .eq('id', chatId)
        .maybeSingle();

    return row?['wallpaper_url'] as String?;
  }

  Future<void> setWallpaper(File pickedFile) async {
    final supabase = Supabase.instance.client;
    final storagePath = '$chatId/wallpaper_${const Uuid().v4()}.jpg';

    await supabase.storage.from('chat-media').upload(
          storagePath,
          pickedFile,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    final publicUrl =
        supabase.storage.from('chat-media').getPublicUrl(storagePath);

    final previous = state.value;

    await supabase.from('chats').update({
      'wallpaper_url': publicUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', chatId);

    state = AsyncData(publicUrl);

    if (previous != null && previous.isNotEmpty) {
      await _tryDeleteStorageUrl(previous);
    }
  }

  Future<void> removeWallpaper() async {
    final supabase = Supabase.instance.client;
    final previous = state.value;

    await supabase.from('chats').update({
      'wallpaper_url': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', chatId);

    state = const AsyncData(null);

    if (previous != null && previous.isNotEmpty) {
      await _tryDeleteStorageUrl(previous);
    }
  }

  Future<void> _tryDeleteStorageUrl(String publicUrl) async {
    try {
      const marker = '/chat-media/';
      final idx = publicUrl.indexOf(marker);
      if (idx < 0) return;
      final path = Uri.decodeComponent(
        publicUrl.substring(idx + marker.length).split('?').first,
      );
      await Supabase.instance.client.storage.from('chat-media').remove([path]);
    } catch (_) {
      // Non-fatal — wallpaper row already cleared.
    }
  }
}

final chatWallpaperProvider = AsyncNotifierProvider.family<
    ChatWallpaperNotifier, String?, String>(ChatWallpaperNotifier.new);
