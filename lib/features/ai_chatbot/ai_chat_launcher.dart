import 'package:chatme/features/ai_chatbot/persona_view.dart';
import 'package:chatme/features/ai_chatbot/welcome_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, WidgetRef;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme_provider.dart';


Future<void> openAiChat(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool(kAiWelcomeSeenKey) ?? false;
  if (!context.mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => seen ? const PersonaScreen() : const WelcomeScreen(),
    ),
  );
}

class AiChatTile extends ConsumerWidget {
  const AiChatTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

    return InkWell(
      onTap: () => openAiChat(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [p.accent, p.header],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Chat',
                    style: TextStyle(
                      color: p.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Chat with fun AI characters',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textGrey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.push_pin_rounded, size: 16, color: p.textGrey),
          ],
        ),
      ),
    );
  }
}