import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_presets.dart';
import '../theme/theme_provider.dart';
import 'app_haptics.dart';

// What the user picked in the message options dialog
enum MessageAction { edit, delete }

// All dialogs of the app are here. Use them like:
//   final yes = await AppDialogs.confirmExit(context);
class AppDialogs {
  AppDialogs._();

  // Reads the selected theme colors (dialogs have no "ref", so we
  // get the Riverpod container from the context instead).
  static AppThemePreset _preset(BuildContext context) {
    return ProviderScope.containerOf(context).read(themeProvider).preset;
  }

  // ---------- BASE DIALOG (every yes/no dialog uses this) ----------

  // Returns true if the user pressed the confirm button,
  // false if they pressed cancel or tapped outside the dialog.
  static Future<bool> confirm(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Yes',
        String cancelText = 'No',
        bool isDestructive = false, // true = confirm button becomes red
      }) async {
    AppHaptics.light();
    final p = _preset(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: p.textMain,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 14, color: p.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              cancelText,
              style: TextStyle(color: p.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? AppColors.error : p.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false; // tapping outside counts as "No"
  }

  // ---------- READY-MADE CONFIRM DIALOGS ----------

  static Future<bool> confirmExit(BuildContext context) {
    return confirm(
      context,
      title: 'Close app?',
      message: 'Do you want to close the app?',
      confirmText: 'Yes',
      cancelText: 'No',
    );
  }

  static Future<bool> confirmLogout(BuildContext context) {
    return confirm(
      context,
      title: 'Logout?',
      message: 'Do you want to logout from your account?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      isDestructive: true,
    );
  }

  static Future<bool> confirmDeleteChat(BuildContext context, String chatName) {
    return confirm(
      context,
      title: 'Delete chat?',
      message: 'This will delete "$chatName" from your chat list. '
          'It will reappear if a new message arrives.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );
  }

  static Future<bool> confirmDeleteMessage(BuildContext context) {
    return confirm(
      context,
      title: 'Delete message?',
      message: 'This message will be deleted for everyone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );
  }

  // ---------- MESSAGE OPTIONS (Edit / Delete) ----------

  // Returns MessageAction.edit, MessageAction.delete, or null if cancelled.
  // canEdit = false hides the Edit button (voice and image messages can't be edited)
  static Future<MessageAction?> messageOptions(
      BuildContext context, {
        bool canEdit = true,
      }) {
    final p = _preset(context);

    return showDialog<MessageAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Message options',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: p.textMain,
          ),
        ),
        actions: [
          if (canEdit)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, MessageAction.edit),
              child: Text('Edit', style: TextStyle(color: p.primary)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, MessageAction.delete),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: p.textGrey)),
          ),
        ],
      ),
    );
  }

  // ---------- EDIT TEXT ----------

  // Returns the new text (trimmed), or null if the user cancelled.
  static Future<String?> editText(
      BuildContext context, {
        required String title,
        required String initialText,
        String saveText = 'Save',
      }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _EditTextDialog(
        title: title,
        initialText: initialText,
        saveText: saveText,
      ),
    );
  }
}

// Private widget: it owns the text controller, so the controller is
// disposed safely when the dialog closes.
class _EditTextDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final String saveText;

  const _EditTextDialog({
    required this.title,
    required this.initialText,
    required this.saveText,
  });

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppDialogs._preset(context);

    return AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: p.textMain,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: null,
        style: TextStyle(color: p.textMain),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // returns null
          child: Text('Cancel', style: TextStyle(color: p.textGrey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(
            widget.saveText,
            style: TextStyle(
              color: p.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}