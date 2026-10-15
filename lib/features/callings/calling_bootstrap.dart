import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/call_push_sender.dart';
import '../../core/services/call_signaling.dart';
import 'controller/controller.dart';
/// The ONLY place where the calling module meets the chat app's backend
/// (Supabase). Everything else in the module stays app-independent.
class CallingBootstrap {
  CallingBootstrap._();

  /// Call after login (and on app start when a session already exists).
  static Future<void> start(WidgetRef ref) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Name that the other person sees on the incoming call screen.
    var name = user.email?.split('@').first ?? 'Someone';
    try {
      final row = await client
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      final profileName = row?['name']?.toString();
      if (profileName != null && profileName.isNotEmpty) name = profileName;
    } catch (_) {}

    await ref.read(callControllerProvider.notifier).init(
      userId: user.id,
      userName: name,
      signaling: SupabaseCallSignaling(),
      pushSender: SupabaseCallPushSender(),
    );
  }

  /// Call on logout.
  static Future<void> stop(WidgetRef ref) =>
      ref.read(callControllerProvider.notifier).shutdown();
}