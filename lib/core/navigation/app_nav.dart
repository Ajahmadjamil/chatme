import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';

enum AppTransition {
  /// Side-to-side slide + fade (default for chats, profile, etc.).
  forward,

  /// Soft vertical rise — sheets / settings-style.
  vertical,

  /// Fade only — photo previews, overlays.
  fade,

  /// Fade through — tab-like content swaps.
  fadeThrough,
}

/// Polished page route used across the app.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required Widget page,
    this.type = AppTransition.forward,
    super.fullscreenDialog,
    Duration? duration,
    Duration? reverseDuration,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration ?? const Duration(milliseconds: 300),
          reverseTransitionDuration:
              reverseDuration ?? const Duration(milliseconds: 260),
          opaque: type != AppTransition.fade,
          barrierColor: type == AppTransition.fade ? Colors.black54 : null,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              type: type,
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        );

  final AppTransition type;

  static Widget _buildTransition({
    required AppTransition type,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    final primary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    switch (type) {
      case AppTransition.fade:
        return FadeTransition(opacity: primary, child: child);

      case AppTransition.vertical:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(primary),
          child: FadeTransition(opacity: primary, child: child),
        );

      case AppTransition.fadeThrough:
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.2, 1, curve: Curves.easeOut),
            ),
          ),
          child: child,
        );

      case AppTransition.forward:
        final incoming = SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(primary),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.7, curve: Curves.easeOut),
                reverseCurve: Curves.easeIn,
              ),
            ),
            child: child,
          ),
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.25, 0),
          ).animate(secondary),
          child: incoming,
        );
    }
  }
}

/// Navigation helpers with built-in haptic feedback.
class AppNav {
  AppNav._();

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget page, {
    AppTransition transition = AppTransition.forward,
  }) {
    AppHaptics.navigate();
    return Navigator.of(context).push<T>(
      AppPageRoute<T>(page: page, type: transition),
    );
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    AppTransition transition = AppTransition.forward,
    TO? result,
  }) {
    AppHaptics.navigate();
    return Navigator.of(context).pushReplacement<T, TO>(
      AppPageRoute<T>(page: page, type: transition),
      result: result,
    );
  }

  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    AppHaptics.back();
    Navigator.of(context).pop<T>(result);
  }

  static Future<bool> maybePop<T extends Object?>(
    BuildContext context, [
    T? result,
  ]) {
    AppHaptics.back();
    return Navigator.of(context).maybePop<T>(result);
  }

  static Future<T?> fade<T extends Object?>(BuildContext context, Widget page) {
    return push<T>(context, page, transition: AppTransition.fade);
  }
}
