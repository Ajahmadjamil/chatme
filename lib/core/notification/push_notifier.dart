import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks the Edge Function to push a WhatsApp-style FCM to other members.
/// Fire-and-forget — never blocks sending the chat message.
class PushNotifier {
  static Future<void> notifyNewMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'push-new-message',
        body: {
          'chat_id': chatId,
          'message_id': messageId,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push notify skipped: $e');
      }
    }
  }
}
