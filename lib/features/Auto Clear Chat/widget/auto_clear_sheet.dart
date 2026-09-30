import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../model.dart';


// Bottom sheet where the user picks a duration.
// onSelected gives back the chosen minutes value (or null for "Off").
void showAutoClearSheet({
  required BuildContext context,
  required int? currentMinutes,
  required void Function(int? minutes) onSelected,
}) {
  final currentOption = AutoClearOptionData.fromMinutes(currentMinutes);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Auto-delete messages',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
            ),
            for (final option in AutoClearOption.values)
              ListTile(
                leading: Icon(
                  option == currentOption
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: option == currentOption ? AppColors.primary : AppColors.icon,
                ),
                title: Text(option.label, style: const TextStyle(color: AppColors.textDark)),
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