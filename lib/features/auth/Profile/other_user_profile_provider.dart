import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile_models.dart'; // check this path matches your project

// Fetches the OTHER person's profile for a 1-on-1 chat
// (used by the Contact Info screen)
final otherUserProfileProvider =
FutureProvider.autoDispose.family<ProfileModel?, String>((ref, chatId) async {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser!.id;

  final row = await supabase
      .from('chat_members')
      .select('profiles!inner(id, name, email, username, bio, avatar_url)')
      .eq('chat_id', chatId)
      .neq('user_id', currentUserId)
      .maybeSingle();

  if (row == null) return null;
  final profileJson = row['profiles'] as Map<String, dynamic>;
  return ProfileModel.fromJson(profileJson);
});