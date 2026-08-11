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

  ({Color bg, Color fg, IconData icon}) get _style => switch (variant) {
        AppAlertVariant.info => (bg: AppColors.infoBg, fg: AppColors.info, icon: Icons.info_rounded),
        AppAlertVariant.success => (bg: AppColors.successBg, fg: AppColors.success, icon: Icons.check_circle_rounded),
        AppAlertVariant.warning => (bg: AppColors.warningBg, fg: AppColors.warning, icon: Icons.warning_rounded),
        AppAlertVariant.danger => (bg: AppColors.dangerBg, fg: AppColors.danger, icon: Icons.error_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
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
                  Text(title!, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: s.fg)),
                if (title != null) const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 13, color: s.fg.withValues(alpha: 0.9), height: 1.4)),
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
void showAppSnackbar(
  BuildContext context, {
  required String message,
  AppAlertVariant variant = AppAlertVariant.info,
}) {
  final s = switch (variant) {
    AppAlertVariant.info => AppColors.neutral900,
    AppAlertVariant.success => AppColors.success,
    AppAlertVariant.warning => AppColors.warning,
    AppAlertVariant.danger => AppColors.danger,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: s,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(AppSpacing.lg),
    ),
  );
}
