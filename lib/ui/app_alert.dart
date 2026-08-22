import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppAlertVariant { info, success, warning, danger }

/// Inline banner for form errors, page-level notices, empty-state hints.
/// Use `showAppSnackbar` (below) instead for transient/toast-style messages.
class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.message,
    this.title,
    this.variant = AppAlertVariant.info,
    this.onDismiss,
  });

  final String message;
  final String? title;
  final AppAlertVariant variant;
  final VoidCallback? onDismiss;

  /// Derived per theme for the same reason [AppBadge] is: the four light
  /// fills are tints mixed toward white, and an alert is a *large* block, so
  /// painting one unchanged on a dark screen is the single worst case of it.
  ({Color bg, Color fg, IconData icon}) _style(BuildContext context) {
    final (Color ink, Color tint, IconData icon) = switch (variant) {
      AppAlertVariant.info => (AppColors.info, AppColors.infoBg, Icons.info_rounded),
      AppAlertVariant.success => (
          AppColors.success,
          AppColors.successBg,
          Icons.check_circle_rounded
        ),
      AppAlertVariant.warning => (AppColors.warning, AppColors.warningBg, Icons.warning_rounded),
      AppAlertVariant.danger => (AppColors.danger, AppColors.dangerBg, Icons.error_rounded),
    };

    if (Theme.of(context).brightness != Brightness.dark) {
      return (bg: tint, fg: ink, icon: icon);
    }

    final hsl = HSLColor.fromColor(ink);
    final fg = hsl.withLightness(hsl.lightness.clamp(0.62, 0.90)).toColor();
    return (
      bg: Color.alphaBlend(fg.withValues(alpha: 0.16), AppColors.surface(context)),
      fg: fg,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _style(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, size: 20, color: s.fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: s.fg)),
                if (title != null) const SizedBox(height: 2),
                Text(message,
                    style:
                        TextStyle(fontSize: 13, color: s.fg.withValues(alpha: 0.9), height: 1.4)),
              ],
            ),
          ),
          if (onDismiss != null)
            InkWell(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 18, color: s.fg.withValues(alpha: 0.6)),
            ),
        ],
      ),
    );
  }
}

/// Toast-style transient message. Call `showAppSnackbar(context, ...)`.
///
/// Every change a user makes should say so. Most of this app's actions move a
/// row somewhere else or make it disappear, and a list that silently reshuffles
/// leaves people wondering whether they tapped the thing they meant to.
///
/// [actionLabel] and [onAction] add a trailing button, which is what makes an
/// undo possible: reversing a status change is one call, and offering it for a
/// few seconds is cheaper for everyone than a confirmation dialog in front of
/// every tap.
void showAppSnackbar(
  BuildContext context, {
  required String message,
  AppAlertVariant variant = AppAlertVariant.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final s = switch (variant) {
    // Grey rather than near-black. Black reads as an error banner on a light
    // screen, and neutral900 on the dark background is 1.1:1 against it, which
    // is a message you cannot see at all. Lifted in dark so the toast is a
    // surface rather than a shadow; white text clears 9.4:1 on one and 6.3:1
    // on the other.
    AppAlertVariant.info => isDark ? AppColors.neutral600 : AppColors.neutral700,
    AppAlertVariant.success => AppColors.success,
    AppAlertVariant.warning => AppColors.warning,
    AppAlertVariant.danger => AppColors.danger,
  };
  final messenger = ScaffoldMessenger.of(context);
  final duration = Duration(seconds: onAction != null ? 6 : 3);

  // One at a time. Confirming three rows in a row should leave the third
  // message on screen, not queue three and make the user wait them out.
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content:
          Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: s,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(AppSpacing.lg),
      // Long enough to read and reach, without parking over the tab bar.
      duration: duration,
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
    ),
  );

  // Close it ourselves rather than trusting SnackBar.duration.
  //
  // ScaffoldMessenger only arms its dismissal timer from inside its own build,
  // and only once the entrance animation has completed. Hiding the previous
  // snackbar immediately before showing this one interleaves those two
  // animations in a way that can leave the timer unarmed, and then the message
  // sits there forever. Observed: a toast still on screen nine seconds after a
  // six second duration, surviving a tab change.
  //
  // The controller closes exactly this snackbar, so a later one replacing it
  // is unaffected, and the closed future stops us touching one that has
  // already gone.
  var closed = false;
  unawaited(controller.closed.then((_) => closed = true));
  Timer(duration + const Duration(milliseconds: 250), () {
    if (!closed) controller.close();
  });
}
