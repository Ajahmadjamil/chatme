import 'package:flutter/material.dart';

class PageTransitions {
  static const Duration animationTime = Duration(milliseconds: 400);
  // 1) FADE ANIMATION
  static Route<T> fadeTransition<T>(Widget newPage) {
    return PageRouteBuilder<T>(
      transitionDuration: animationTime,
      pageBuilder: (context, animation, secondaryAnimation) {
        return newPage;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // FadeTransition opacity
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
  // 2) SLIDE FROM RIGHT

  static Route<T> slideFromRight<T>(Widget newPage) {
    return PageRouteBuilder<T>(
      transitionDuration: animationTime,
      pageBuilder: (context, animation, secondaryAnimation) {
        return newPage;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var startPosition = const Offset(1.0, 0.0);
        var endPosition = Offset.zero;

        var tween = Tween(begin: startPosition, end: endPosition);

        return SlideTransition(
          position: animation.drive(tween.chain(CurveTween(curve: Curves.easeOutCubic))),
          child: child,
        );
      },
    );
  }
  // 3) SLIDE FROM LEFT
  static Route<T> slideFromLeft<T>(Widget newPage) {
    return PageRouteBuilder<T>(
      transitionDuration: animationTime,
      pageBuilder: (context, animation, secondaryAnimation) {
        return newPage;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var startPosition = const Offset(-1.0, 0.0);
        var endPosition = Offset.zero;

        var tween = Tween(begin: startPosition, end: endPosition);

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
  // 4) SLIDE FROM BOTTOM (neeche se upar)
  static Route<T> slideFromBottom<T>(Widget newPage) {
    return PageRouteBuilder<T>(
      transitionDuration: animationTime,
      pageBuilder: (context, animation, secondaryAnimation) {
        return newPage;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var startPosition = const Offset(0.0, 1.0);
        var endPosition = Offset.zero;

        var tween = Tween(begin: startPosition, end: endPosition);

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // 5) SLIDE FROM TOP
  static Route<T> slideFromTop<T>(Widget newPage) {
    return PageRouteBuilder<T>(
      transitionDuration: animationTime,
      pageBuilder: (context, animation, secondaryAnimation) {
        return newPage;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var startPosition = const Offset(0.0, -1.0);
        var endPosition = Offset.zero;

        var tween = Tween(begin: startPosition, end: endPosition);

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
  // 6) SCALE (ZOOM) ANIMATION
  static Route<T> scaleTransition<T>(Widget newPage) {
    return PageRouteBuilder<T>(
      transitionDuration: animationTime,
      pageBuilder: (context, animation, secondaryAnimation) {
        return newPage;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: animation,
          child: child,
        );
      },
    );
  }
  // 7) ROTATE ANIMATION

  static Route<T> rotateTransition<T>(Widget newPage) {
    return PageRouteBuilder<T>(
      transitionDuration: animationTime,
      pageBuilder: (context, animation, secondaryAnimation) {
        return newPage;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return RotationTransition(
          turns: animation,
          child: child,
        );
      },
    );
  }
}