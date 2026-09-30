import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

// One text field used on every screen.
//  - icon on the left
//  - obscureText: true  -> it is a password field, so an eye icon is shown
//  - error message comes in red below the field
class CustomTextField extends StatefulWidget {
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
    this.maxLines = 1,
    this.maxLength,
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
  final int maxLines;
  final int? maxLength;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _hidePassword = true; // true = dots are shown, false = text is shown

  @override
  Widget build(BuildContext context) {
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
            // White pill with a soft shadow (like the design)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  widget.maxLines > 1 ? 22 : 30,
                ),
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
                keyboardType: widget.maxLines > 1
                    ? TextInputType.multiline
                    : widget.keyboardType,
                textInputAction: widget.maxLines > 1
                    ? TextInputAction.newline
                    : widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                onSubmitted: widget.onSubmitted,
                onChanged: (value) => state.didChange(value),
                maxLines: widget.obscureText ? 1 : widget.maxLines,
                maxLength: widget.maxLength,
                style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(fontSize: 15, color: AppColors.icon),
                  border: InputBorder.none,
                  counterText: widget.maxLength == null ? '' : null,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: widget.maxLines > 1 ? 16 : 20,
                  ),
                  prefixIcon: Icon(widget.prefixIcon, color: AppColors.icon, size: 22),
                  suffixIcon: widget.obscureText
                      ? IconButton(
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.icon,
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
