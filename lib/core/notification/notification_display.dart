import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_actions.dart';

/// Builds WhatsApp-style notification details (MessagingStyle + actions).
class NotificationDisplay {
  NotificationDisplay(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const channelId = 'chat_messages';
  static const channelName = 'Messages';
  static const channelDescription = 'New chat messages';
  static const iosCategoryId = 'chat_message';

  /// iOS categories registered once during plugin init.
  static List<DarwinNotificationCategory> get iosCategories => [
        DarwinNotificationCategory(
          iosCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.text(
              NotificationActionIds.reply,
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Message',
              options: {
                DarwinNotificationActionOption.authenticationRequired,
              },
            ),
            DarwinNotificationAction.plain(
              NotificationActionIds.markRead,
              'Mark as read',
              options: {
                DarwinNotificationActionOption.authenticationRequired,
              },
            ),
          ],
        ),
      ];

  Future<void> ensureChannel() async {
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Shows a chat notification like WhatsApp:
  /// title = sender (or "Sender · Group"), body = message preview,
  /// with Reply + Mark as read actions.
  Future<void> showChatMessage({
    required String title,
    required String body,
    required String chatId,
    String? chatName,
    String? senderName,
    bool isGroup = false,
  }) async {
    final person = Person(
      name: senderName ?? title,
      key: senderName ?? title,
    );

    final style = MessagingStyleInformation(
      person,
      conversationTitle: isGroup ? title : null,
      groupConversation: isGroup,
      messages: <Message>[
        Message(body, DateTime.now(), person),
      ],
    );

    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: style,
      visibility: NotificationVisibility.private,
      autoCancel: true,
      groupKey: 'chat_$chatId',
      setAsGroupSummary: false,
      ticker: '$title: $body',
      // showsUserInterface: true so Oppo/ColorOS delivers the action on the
      // main isolate (where Supabase session is available). Background-only
      // actions were silently dropped on these devices.
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          NotificationActionIds.reply,
          'Reply',
          inputs: const <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'Reply'),
          ],
          showsUserInterface: true,
          cancelNotification: true,
          semanticAction: SemanticAction.reply,
          allowGeneratedReplies: true,
        ),
        const AndroidNotificationAction(
          NotificationActionIds.markRead,
          'Mark as read',
          showsUserInterface: true,
          cancelNotification: true,
          semanticAction: SemanticAction.markAsRead,
        ),
      ],
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'chat_messages',
      categoryIdentifier: iosCategoryId,
    );

    final payload = jsonEncode({
      'chat_id': chatId,
      'chat_name': chatName ?? title,
      'is_group': isGroup ? 'true' : 'false',
      'type': 'new_message',
    });

    await _plugin.show(
      id: chatId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  Future<void> cancelForChat(String chatId) async {
    await _plugin.cancel(id: chatId.hashCode & 0x7fffffff);
  }
}
