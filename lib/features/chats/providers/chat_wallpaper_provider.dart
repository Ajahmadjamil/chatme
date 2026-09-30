import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Maps chatId -> local file path of that chat's wallpaper image.
// Nothing here goes to Supabase; this is purely a per-device preference.
class ChatWallpaperNotifier extends Notifier<Map<String, String>> {
  static const _prefsKey = 'chat_wallpapers';

  @override
  Map<String, String> build() {
    _loadSaved();
    return {};
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    state = decoded.map((key, value) => MapEntry(key, value as String));
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state));
  }

  // Copies the picked image into the app's own folder (so it survives even
  // if the original gallery file is deleted), then remembers its path.
  Future<void> setWallpaper(String chatId, File pickedFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.jpg';
    final savedFile = await pickedFile.copy('${dir.path}/$fileName');

    // Delete the old wallpaper file for this chat, if there was one
    final oldPath = state[chatId];
    if (oldPath != null) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) await oldFile.delete();
    }

    state = {...state, chatId: savedFile.path};
    await _saveToPrefs();
  }

  Future<void> removeWallpaper(String chatId) async {
    final path = state[chatId];
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }

    final updated = Map<String, String>.from(state)..remove(chatId);
    state = updated;
    await _saveToPrefs();
  }
}

final chatWallpaperProvider =
NotifierProvider<ChatWallpaperNotifier, Map<String, String>>(
  ChatWallpaperNotifier.new,
);