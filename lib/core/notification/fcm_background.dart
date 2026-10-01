import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import 'notification_actions.dart';
import 'notification_display.dart';

/// Must be a top-level function (not a class method) for FCM background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate — Firebase must be initialized again here.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Data-only FCM: we always build the local notification so Reply /
  // Mark as read actions are available. Skip if FCM already showed one
  // (legacy pushes that still include a notification payload).
  if (message.notification != null) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final iosInit = DarwinInitializationSettings(
    notificationCategories: NotificationDisplay.iosCategories,
  );
  await plugin.initialize(
    settings: InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    ),
    onDidReceiveBackgroundNotificationResponse: onNotificationActionBackground,
  );

  final display = NotificationDisplay(plugin);
  await display.ensureChannel();

  final title = message.data['title'] ?? 'New message';
  final body = message.data['body'] ?? '';
  final chatId = message.data['chat_id'] ?? '';

  if (body.isEmpty || chatId.isEmpty) return;

  await display.showChatMessage(
    title: title,
    body: body,
    chatId: chatId,
    chatName: message.data['chat_name'],
    senderName: message.data['sender_name'],
    isGroup: message.data['is_group'] == 'true',
  );
}
