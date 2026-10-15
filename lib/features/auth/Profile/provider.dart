import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Fetches the current user's profile row
final myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;

  final data = await supabase.from('profiles').select().eq('id', userId).single();
  return data;
});

class ProfileActions {
  final _supabase = Supabase.instance.client;

  // Updates name, username and bio for the logged-in user
  Future<void> updateProfile({
    required String name,
    required String username,
    required String bio,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({
      'name': name,
      'username': username.trim().toLowerCase(),
      'bio': bio,
    }).eq('id', userId);
  }

  // First-login onboarding after Google sign-in
  Future<void> completeProfile({
    required String name,
    required String username,
    required String bio,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({
      'name': name,
      'username': username.trim().toLowerCase(),
      'bio': bio,
      'profile_complete': true,
    }).eq('id', userId);
  }

  // Uploads a new avatar image and saves its link on the profile
  Future<void> updateAvatar(File imageFile) async {
    final userId = _supabase.auth.currentUser!.id;
    final fileName = '${const Uuid().v4()}.jpg';
    final storagePath = '$userId/$fileName';

    await _supabase.storage.from('avatars').upload(storagePath, imageFile);
    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(storagePath);

    await _supabase.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
  }
}

final profileActionsProvider = Provider<ProfileActions>((ref) => ProfileActions());