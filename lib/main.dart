import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/navigation/app_navigatior.dart';
import 'core/notification/notification_service.dart';
import 'core/services/call_notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';
import 'features/Shortcut/service.dart';
import 'features/auth/auth_gate.dart';
import 'features/callings/views/call_listener.dart';
import 'features/chat lock/provider.dart';
import 'features/chat lock/screens/enter_pin_view.dart';
import 'features/chats/screens/conversation_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );

  // Must run AFTER Supabase.initialize (it may need the logged-in user)
  await NotificationService.initialize();
  // Listens to the system call screen (Accept / Decline) from the very start,
  // so a tap made while the app was closed is not lost.
  await CallNotificationService.instance.start();

  // Handles the case where the app was fully closed and the user
  // tapped Reply / Mark as read on a notification to open it
  await NotificationService.handleLaunchAction();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    final service = ref.read(chatShortcutServiceProvider);

    // 1) App was closed, user tapped a shortcut
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = await service.getInitialChat();
      if (chat != null) _openChat(chat);
    });

    // 2) App was already running, user tapped a shortcut
    service.listenToTaps(_openChat);
  }

  Future<void> _openChat(ShortcutChat chat) async {
    // Only open if the user is logged in
    if (Supabase.instance.client.auth.currentSession == null) return;

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    // Same lock rule as HomeView: ask for PIN if the chat is locked
    final lockNotifier = ref.read(chatLockProvider.notifier);
    final isLocked =
    ref.read(chatLockProvider).lockedChatIds.contains(chat.chatId);

    if (isLocked && !lockNotifier.isUnlockedNow(chat.chatId)) {
      final success = await nav.push<bool>(
        MaterialPageRoute(
          builder: (_) => EnterPinScreen(
            chatId: chat.chatId,
            title: 'Locked Chat',
            subtitle: 'Enter your PIN to open this chat.',
          ),
        ),
      );
      if (success != true) return;
      lockNotifier.markUnlocked(chat.chatId);
    }

    nav.push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          chatId: chat.chatId,
          otherUserName: chat.name,
          isGroup: chat.isGroup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey, // important
      debugShowCheckedModeBanner: false,
      title: 'ChatMe',
      // Opens the call screen on ANY page when a call starts / arrives.
      builder: (context, child) => CallListener(
        navigatorKey: appNavigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: themeState.preset.toThemeData(),
      home: const AuthGate(),
    );
  }
}