import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_nav.dart';
import 'biometric_gate.dart';
import 'provider.dart';
import 'screens/enter_pin_view.dart';
import 'screens/set_pin_view.dart';
import 'service.dart';

/// Shared lock / unlock helpers used by Home, Groups, Conversation, Profile.
class ChatLockActions {
  ChatLockActions._();

  /// Prefer phone fingerprint/PIN; fall back to the chat lock PIN.
  static Future<bool> _gate({
    required BuildContext context,
    required WidgetRef ref,
    required String reason,
    String? chatIdForPin,
    String pinTitle = 'Enter PIN',
    String pinSubtitle = 'Enter your chat lock PIN to continue.',
  }) async {
    final bio = await BiometricGate.authenticate(reason: reason);

    if (bio == BiometricResult.success) return true;
    if (bio == BiometricResult.canceled) return false;

    // Fingerprint / phone lock unavailable → use the app PIN instead.
    if (!context.mounted) return false;

    final hasPin = await ref
        .read(chatLockProvider.notifier)
        .hasPinForLock(chatId: chatIdForPin);

    if (!hasPin) {
      // No PIN set yet — let them create one, that counts as verified.
      final created = await AppNav.push<bool>(
        context,
        SetPinScreen(chatId: chatIdForPin),
      );
      return created == true;
    }

    return verifyPinFlow(
      context,
      chatId: chatIdForPin,
      title: pinTitle,
      subtitle: pinSubtitle,
    );
  }

  /// Opens a locked chat (biometric, or chat PIN fallback).
  static Future<bool> unlockWithBiometric({
    required BuildContext context,
    required WidgetRef ref,
    required String chatId,
    String reason = 'Unlock chat',
  }) async {
    final notifier = ref.read(chatLockProvider.notifier);
    if (notifier.isUnlockedNow(chatId)) return true;

    final mode = ref.read(chatLockProvider).mode;
    final pinChatId = mode == ChatLockMode.separate ? chatId : null;

    final ok = await _gate(
      context: context,
      ref: ref,
      reason: reason,
      chatIdForPin: pinChatId,
      pinTitle: 'Unlock chat',
      pinSubtitle: 'Enter your PIN to open this chat.',
    );
    if (!ok) return false;
    notifier.markUnlocked(chatId);
    return true;
  }

  /// Gate for the manage-locks screen.
  static Future<bool> authenticateForManage(
    BuildContext context,
    WidgetRef ref,
  ) {
    final mode = ref.read(chatLockProvider).mode;
    return _gate(
      context: context,
      ref: ref,
      reason: 'Confirm it\'s you to manage chat locks',
      chatIdForPin: null,
      pinTitle: 'Chat locks',
      pinSubtitle: mode == ChatLockMode.shared
          ? 'Enter your lock PIN to manage locked chats.'
          : 'Enter a lock PIN to manage locked chats.',
    );
  }

  /// Lock a chat (sets PIN first if needed for the current mode).
  static Future<bool> lockChat(
    BuildContext context,
    WidgetRef ref, {
    required String chatId,
  }) async {
    final notifier = ref.read(chatLockProvider.notifier);
    final mode = ref.read(chatLockProvider).mode;
    final chatIdForPin =
        mode == ChatLockMode.separate ? chatId : null;

    final hasPin = await notifier.hasPinForLock(chatId: chatIdForPin);
    if (!hasPin) {
      if (!context.mounted) return false;
      final created = await AppNav.push<bool>(
        context,
        SetPinScreen(chatId: chatIdForPin),
      );
      if (created != true) return false;
    }

    await notifier.lockChat(chatId);
    notifier.markUnlocked(chatId);
    return true;
  }

  /// Remove lock — biometric or chat PIN.
  static Future<bool> removeLock(
    BuildContext context,
    WidgetRef ref, {
    required String chatId,
  }) async {
    final mode = ref.read(chatLockProvider).mode;
    final pinChatId = mode == ChatLockMode.separate ? chatId : null;

    final ok = await _gate(
      context: context,
      ref: ref,
      reason: 'Confirm to remove chat lock',
      chatIdForPin: pinChatId,
      pinTitle: 'Remove lock',
      pinSubtitle: 'Enter your PIN to remove this lock.',
    );
    if (!ok) return false;
    await ref.read(chatLockProvider.notifier).removeLock(chatId);
    return true;
  }

  static Future<bool> verifyPinFlow(
    BuildContext context, {
    String? chatId,
    String title = 'Enter PIN',
    String subtitle = 'Enter your PIN to continue.',
  }) async {
    final success = await AppNav.push<bool>(
      context,
      EnterPinScreen(
        title: title,
        subtitle: subtitle,
        chatId: chatId,
      ),
    );
    return success == true;
  }
}
