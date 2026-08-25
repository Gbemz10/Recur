import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';

/// The motion assets the app uses, all played once.
///
/// Wrapped rather than dropped inline at each call site so there is one place
/// that decides how they behave: once, forward, no loop. A looping animation
/// reads as "working on it" — wrong above a destructive question, and wrong
/// above a result that has already happened.
///
/// Both fall back to a static icon if the asset cannot be decoded. A dialog
/// that fails to render because of a decorative file would be a bad trade, and
/// every one of these still works without it.
class AppDeleteAnimation extends StatelessWidget {
  const AppDeleteAnimation({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _Once(
      asset: 'assets/animations/delete.json',
      size: size,
      fallbackIcon: Icons.delete_outline_rounded,
      fallbackColor: AppColors.danger,
    );
  }
}

/// Asks the question. Sits above a confirm dialog, where the beat it takes to
/// resolve is the point: a static icon is read in the same glance as the
/// title, motion is not.
class AppAlertAnimation extends StatelessWidget {
  const AppAlertAnimation({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _Once(
      asset: 'assets/animations/alert.json',
      size: size,
      fallbackIcon: Icons.warning_amber_rounded,
      fallbackColor: AppColors.danger,
    );
  }
}

/// Plays after something finished, not while it is happening.
class AppSuccessAnimation extends StatelessWidget {
  const AppSuccessAnimation({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _Once(
      asset: 'assets/animations/success.json',
      size: size,
      fallbackIcon: Icons.check_circle_outline_rounded,
      fallbackColor: AppColors.success,
    );
  }
}

class _Once extends StatelessWidget {
  const _Once({
    required this.asset,
    required this.size,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  final String asset;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        asset,
        repeat: false,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) =>
            Icon(fallbackIcon, size: size * 0.5, color: fallbackColor),
      ),
    );
  }
}
