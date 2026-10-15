import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../model.dart';


// Bottom sheet where the user picks a duration.
// onSelected gives back the chosen minutes value (or null for "Off").
void showAutoClearSheet({
  required BuildContext context,
  required int? currentMinutes,
  required void Function(int? minutes) onSelected,
}) {
  final currentOption = AutoClearOptionData.fromMinutes(currentMinutes);
  // Colors of the currently selected theme
  final p = ProviderScope.containerOf(context).read(themeProvider).preset;

  showModalBottomSheet(
    context: context,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Auto-delete messages',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: p.textMain,
                ),
              ),
            ),
            for (final option in AutoClearOption.values)
              ListTile(
                leading: Icon(
                  option == currentOption
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: option == currentOption ? p.primary : p.icon,
                ),
                title: Text(option.label, style: TextStyle(color: p.textMain)),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(option.minutes);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}