import 'package:flutter/material.dart';

import '../../utils/app_haptics.dart';

/// InkWell that always fires a light haptic on tap / long-press.
class HapticInkWell extends StatelessWidget {
  const HapticInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      splashColor: splashColor,
      highlightColor: highlightColor,
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.tap();
              onTap!();
            },
      onLongPress: onLongPress == null
          ? null
          : () {
              AppHaptics.medium();
              onLongPress!();
            },
      child: child,
    );
  }
}

/// GestureDetector with haptic on tap / long-press.
class HapticTap extends StatelessWidget {
  const HapticTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.tap();
              onTap!();
            },
      onLongPress: onLongPress == null
          ? null
          : () {
              AppHaptics.medium();
              onLongPress!();
            },
      child: child,
    );
  }
}

/// IconButton with haptic.
class HapticIconButton extends StatelessWidget {
  const HapticIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.tooltip,
    this.iconSize,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      color: color,
      tooltip: tooltip,
      iconSize: iconSize,
      onPressed: onPressed == null
          ? null
          : () {
              AppHaptics.tap();
              onPressed!();
            },
    );
  }
}
