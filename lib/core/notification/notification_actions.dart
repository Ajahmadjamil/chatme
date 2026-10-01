import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/Auto Clear Chat/auto_service.dart';
import 'notification_display.dart';
import 'notification_router.dart';
import 'push_notifier.dart';

/// Action IDs shown on chat notifications (Android + iOS).
class NotificationActionIds {
  static const reply = 'reply';
  static const markRead = 'mark_read';
}

/// Handles taps / Reply / Mark as read from a notification.
class NotificationActions {
  NotificationActions._();

  static Future<void> handle(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;

    debugPrint(
      'Notif action: id=$actionId input=${response.input} '
      'type=${response.notificationResponseType}',
    );

    // Plain tap (no action button) → open chat.
    if (actionId == null || actionId.isEmpty) {
      NotificationRouter.openFromPayload(payload);
      return;
    }

    final data = _decode(payload);
    final chatId = data['chat_id'] as String?;
    if (chatId == null || chatId.isEmpty) {
      debugPrint('Notif action: missing chat_id in payload=$payload');
      return;
    }

    try {
      await _ensureSupabase();
      final client = Supabase.instance.client;
      final userId = await _waitForUserId(client);
      if (userId == null) {
        debugPrint('Notif action: no auth session — open chat instead');
        NotificationRouter.openFromPayload(payload);
        return;
      }

      switch (actionId) {
        case NotificationActionIds.reply:
          final text = response.input?.trim() ?? '';
          if (text.isEmpty) {
            debugPrint('Notif action: empty reply text');
            NotificationRouter.openFromPayload(payload);
            return;
          }
          await _sendReply(chatId: chatId, userId: userId, text: text);
          debugPrint('Notif action: reply sent to $chatId');
        case NotificationActionIds.markRead:
          await client.rpc('mark_chat_read', params: {'p_chat_id': chatId});
          debugPrint('Notif action: marked read $chatId');
      }

      // Dismiss the notification after a successful action.
      await NotificationDisplay(
        FlutterLocalNotificationsPlugin(),
      ).cancelForChat(chatId);
    } catch (e, st) {
      debugPrint('Notif action failed: $e\n$st');
    }
  }

  static Future<void> _sendReply({
    required String chatId,
    required String userId,
    required String text,
  }) async {
    final expiresAt = await AutoClearService().calculateExpiry(chatId);
    final inserted = await Supabase.instance.client
        .from('messages')
        .insert({
          'chat_id': chatId,
          'sender_id': userId,
          'content': text,
          'status': 'sent',
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        })
        .select('id')
        .single();

    final messageId = inserted['id'] as String;
    // Fire-and-forget push; don't block the reply.
    // ignore: unawaited_futures
    PushNotifier.notifyNewMessage(chatId: chatId, messageId: messageId);
  }

  static Map<String, dynamic> _decode(String? payload) {
    if (payload == null || payload.isEmpty) return {};
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<String?> _waitForUserId(SupabaseClient client) async {
    for (var i = 0; i < 10; i++) {
      final id = client.auth.currentUser?.id;
      if (id != null) return id;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return client.auth.currentUser?.id;
  }

  static Future<void> _ensureSupabase() async {
    try {
      Supabase.instance.client;
      return;
    } catch (_) {}

    WidgetsFlutterBinding.ensureInitialized();
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env');
    }

    final url = dotenv.env['SUPABASE_URL'];
    final anon = dotenv.env['SUPABASE_ANON_KEY'];
    if (url == null || anon == null) {
      throw StateError('Missing SUPABASE_URL / SUPABASE_ANON_KEY');
    }

    await Supabase.initialize(
      url: url,
      anonKey: anon,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
  }
}

/// Must be top-level for [FlutterLocalNotificationsPlugin.initialize].
@pragma('vm:entry-point')
Future<void> onNotificationActionBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationActions.handle(response);
}
