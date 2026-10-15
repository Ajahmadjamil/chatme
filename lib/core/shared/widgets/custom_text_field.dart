import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';

// One text field used on every screen.
//  - icon on the left
//  - obscureText: true  -> it is a password field, so an eye icon is shown
//  - error message comes in red below the field
class CustomTextField extends ConsumerStatefulWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.onSubmitted,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hintText; // e.g. "Email address"
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly; // true = shown but can't be edited

  @override
  ConsumerState<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends ConsumerState<CustomTextField> {
  bool _hidePassword = true; // true = dots are shown, false = text is shown

  @override
  Widget build(BuildContext context) {
    // Colors of the currently selected theme
    final p = ref.watch(themeProvider).preset;

    // FormField lets this widget work with Form.validate() on the screen.
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (_) => widget.validator?.call(widget.controller.text),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) {
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rounded pill with a soft shadow (like the design)
            Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: hasError ? AppColors.error : Colors.transparent,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: widget.controller,
                obscureText: widget.obscureText && _hidePassword,
                readOnly: widget.readOnly,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                onSubmitted: widget.onSubmitted,
                onChanged: (value) => state.didChange(value), // re-check while typing
                style: TextStyle(fontSize: 15, color: p.textMain),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(fontSize: 15, color: p.icon),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  prefixIcon: Icon(widget.prefixIcon, color: p.icon, size: 22),
                  suffixIcon: widget.obscureText
                      ? IconButton(
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: p.icon,
                      size: 22,
                    ),
                  )
                      : null,
                ),
              ),
            ),

            // Red error text under the field
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 6),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                ),
              ),
          ],
        );
      },
    );
  }
}