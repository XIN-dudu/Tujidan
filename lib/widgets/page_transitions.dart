import 'package:flutter/material.dart';

/// 自定义页面过渡动画
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            if (direction == SlideDirection.left) {
              tween = Tween(begin: const Offset(-1.0, 0.0), end: end).chain(
                CurveTween(curve: curve),
              );
            } else if (direction == SlideDirection.up) {
              tween = Tween(begin: const Offset(0.0, 1.0), end: end).chain(
                CurveTween(curve: curve),
              );
            } else if (direction == SlideDirection.down) {
              tween = Tween(begin: const Offset(0.0, -1.0), end: end).chain(
                CurveTween(curve: curve),
              );
            }

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
}

enum SlideDirection {
  right,
  left,
  up,
  down,
}

/// Fade过渡动画
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}


