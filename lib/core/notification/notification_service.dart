import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../firebase_options.dart';
import '../constants/app_constants.dart';
import 'device_token_repository.dart';
import 'fcm_background.dart';
import 'notification_actions.dart';
import 'notification_display.dart';
import 'notification_router.dart';

/// Owns FCM + local notifications for ChatMe.
///
/// Call [initialize] once at app start (before runApp).
/// Call [syncTokenForLoggedInUser] after Google sign-in.
/// Call [clearTokenOnLogout] before signing out.
class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static final DeviceTokenRepository _tokens = DeviceTokenRepository();
  static late final NotificationDisplay _display;

  static bool _ready = false;

  static Future<void> initialize() async {
    if (_ready) return;

    await _initFirebase();
    await _askAndroidPermission();
    await _initLocalNotifications();
    await _askFcmPermission();

    // Background handler MUST be registered with a top-level function.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);

    // App was killed and opened from a notification.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      // Delay until first frame so navigator exists.
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        NotificationRouter.openFromData(initial.data);
      });
    }

    await _refreshLocalToken();
    _fcm.onTokenRefresh.listen((token) async {
      AppConstants.deviceToken = token;
      await _tokens.saveToken(token: token, platform: _platform);
    });

    _ready = true;
  }

  /// Save this device token for the current Supabase user.
  static Future<void> syncTokenForLoggedInUser() async {
    await _refreshLocalToken();
    final token = AppConstants.deviceToken;
    if (token.isEmpty) return;
    await _tokens.saveToken(token: token, platform: _platform);
  }

  /// Remove this device token when the user logs out.
  static Future<void> clearTokenOnLogout() async {
    final token = AppConstants.deviceToken;
    if (token.isNotEmpty) {
      try {
        await _tokens.removeToken(token);
      } catch (_) {}
    }
  }

  /// Cold start: user tapped Reply / Mark as read / the notification itself
  /// while the app was killed. Must run AFTER Supabase.initialize.
  static Future<void> handleLaunchAction() async {
    try {
      final details = await _local.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp != true || response == null) {
        return;
      }
      await NotificationActions.handle(response);
    } catch (e) {
      if (kDebugMode) debugPrint('Launch notif action failed: $e');
    }
  }

  // ---- private helpers ----

  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  static Future<void> _initFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  static Future<void> _askAndroidPermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  static Future<void> _initLocalNotifications() async {
    _display = NotificationDisplay(_local);
    await _display.ensureChannel();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      notificationCategories: NotificationDisplay.iosCategories,
    );

    await _local.initialize(
      settings: InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: NotificationActions.handle,
      onDidReceiveBackgroundNotificationResponse:
          onNotificationActionBackground,
    );
  }

  static Future<void> _askFcmPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('Notification permission: ${settings.authorizationStatus}');
    }
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _refreshLocalToken() async {
    try {
      final token = await _fcm.getToken();
      AppConstants.deviceToken = token ?? '';
      // Don't print the full token — it floods logs and is a secret.
      if (kDebugMode && token != null) {
        debugPrint('FCM token ready (${token.length} chars)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token error: $e');
    }
  }

  /// App is open — show a WhatsApp-style heads-up notification.
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title'] ??
        'New message';
    final body =
        message.notification?.body ?? message.data['body'] ?? '';
    final chatId = message.data['chat_id'] ?? '';
    if (body.isEmpty || chatId.isEmpty) return;

    await _display.showChatMessage(
      title: title,
      body: body,
      chatId: chatId,
      chatName: message.data['chat_name'],
      senderName: message.data['sender_name'],
      isGroup: message.data['is_group'] == 'true',
    );
  }

  static void _onOpenedFromBackground(RemoteMessage message) {
    NotificationRouter.openFromData(message.data);
  }
}
