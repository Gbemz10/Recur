import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// The delete animation, played once.
///
/// Wrapped rather than dropped inline at each call site so there is one place
/// that decides how it behaves: once, forward, no loop. A looping animation
/// above a destructive question reads as "working on it", which is the
/// opposite of what a confirmation is for.
///
/// Falls back to a static icon if the asset cannot be decoded. A confirmation
/// dialog that fails to render because of a decorative file would be a bad
/// trade, and the dialog still works without it.
class AppDeleteAnimation extends StatelessWidget {
  const AppDeleteAnimation({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/animations/delete.json',
        repeat: false,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Icon(
          Icons.delete_outline_rounded,
          size: size * 0.5,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
