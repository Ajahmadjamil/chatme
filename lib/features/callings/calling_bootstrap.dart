import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/call_push_sender.dart';
import '../../core/services/call_signaling.dart';
import '../../core/services/calling_service.dart';
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
      iceServers: _iceServers(),
    );
  }

  /// Free STUN servers, plus a TURN server when one is set in `.env`.
  /// TURN relays the call when the two phones can't reach each other
  /// directly (some mobile networks / strict NAT).
  static List<Map<String, dynamic>> _iceServers() {
    final turnUrl = dotenv.env['TURN_URL']?.trim() ?? '';
    if (turnUrl.isEmpty) return CallingService.defaultIceServers;

    return [
      ...CallingService.defaultIceServers,
      {
        'urls': turnUrl.split(',').map((u) => u.trim()).toList(),
        'username': dotenv.env['TURN_USERNAME']?.trim() ?? '',
        'credential': dotenv.env['TURN_CREDENTIAL']?.trim() ?? '',
      },
    ];
  }

  /// Call on logout.
  static Future<void> stop(WidgetRef ref) =>
      ref.read(callControllerProvider.notifier).shutdown();
}