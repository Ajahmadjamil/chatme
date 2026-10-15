import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/callings/model/calling_model.dart';

/// Wakes up the other phone when its app is closed (FCM data push).
/// Kept behind an interface so the calling module does not depend on Supabase.
abstract class CallPushSender {
  Future<void> sendInvite(CallModel call);
  Future<void> sendCancel(CallModel call);
}

/// Uses the Supabase Edge Function `push-call`.
class SupabaseCallPushSender implements CallPushSender {
  SupabaseCallPushSender({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> sendInvite(CallModel call) => _invoke('invite', call);

  @override
  Future<void> sendCancel(CallModel call) => _invoke('cancel', call);

  // Never throws: a failed push must not break the call itself.
  Future<void> _invoke(String action, CallModel call) async {
    try {
      await _client.functions.invoke(
        'push-call',
        body: {'action': action, 'call': call.toJson()},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[calling] push-call $action failed: $e');
    }
  }
}