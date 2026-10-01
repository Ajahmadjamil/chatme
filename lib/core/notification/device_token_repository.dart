import 'package:supabase_flutter/supabase_flutter.dart';

/// Saves / clears this device's FCM token in Supabase.
class DeviceTokenRepository {
  DeviceTokenRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Upsert token for the signed-in user (one row per user+token).
  Future<void> saveToken({
    required String token,
    required String platform,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || token.isEmpty) return;

    await _client.from('device_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
  }

  /// Remove this device token (call on logout).
  Future<void> removeToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || token.isEmpty) return;

    await _client
        .from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('token', token);
  }
}
