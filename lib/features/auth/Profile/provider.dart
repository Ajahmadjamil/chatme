import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Current user's full profile row.
final myProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;
  return await supabase.from('profiles').select().eq('id', userId).single();
});

/// Any user's public profile (for WhatsApp-style contact info).
final userProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, userId) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('profiles')
      .select('id, name, email, phone, avatar_url, about, created_at')
      .eq('id', userId)
      .single();
});

class ProfileActions {
  final _supabase = Supabase.instance.client;

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String about,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final trimmedAbout = about.trim();
    await _supabase.from('profiles').update({
      'name': name,
      'phone': phone,
      'about': trimmedAbout.isEmpty
          ? 'Hey there! I am using ChatMe.'
          : trimmedAbout,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  /// First-login onboarding after Google sign-in.
  Future<void> completeProfile({
    required String name,
    required String phone,
    required String about,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final trimmedAbout = about.trim();
    await _supabase.from('profiles').update({
      'name': name.trim(),
      'phone': phone.trim(),
      'about': trimmedAbout.isEmpty
          ? 'Hey there! I am using ChatMe.'
          : trimmedAbout,
      'profile_complete': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  /// Uploads an already-cropped (ideally 1:1) image, resizes to 512px, saves URL.
  Future<void> updateAvatar(File imageFile) async {
    final userId = _supabase.auth.currentUser!.id;
    final squareFile = await _normalizeSquareJpeg(imageFile, size: 512);

    final storagePath = '$userId/avatar.jpg';
    await _supabase.storage.from('avatars').upload(
          storagePath,
          squareFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl =
        '${_supabase.storage.from('avatars').getPublicUrl(storagePath)}'
        '?v=${DateTime.now().millisecondsSinceEpoch}';

    await _supabase.from('profiles').update({
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);

    try {
      await squareFile.delete();
    } catch (_) {}
  }

  Future<File> _normalizeSquareJpeg(File source, {required int size}) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not read image');
    }

    img.Image square = decoded;
    if (decoded.width != decoded.height) {
      final side =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final x = (decoded.width - side) ~/ 2;
      final y = (decoded.height - side) ~/ 2;
      square = img.copyCrop(decoded, x: x, y: y, width: side, height: side);
    }

    final resized = img.copyResize(
      square,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    final jpg = Uint8List.fromList(img.encodeJpg(resized, quality: 90));

    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(jpg, flush: true);
    return out;
  }
}

final profileActionsProvider =
    Provider<ProfileActions>((ref) => ProfileActions());
