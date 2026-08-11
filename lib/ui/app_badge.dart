import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppBadgeVariant { neutral, primary, success, warning, danger, info }

/// Small status pill for tags, statuses, and counts.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.variant = AppBadgeVariant.neutral, this.dot = false});

  final String label;
  final AppBadgeVariant variant;
  final bool dot;

  ({Color bg, Color fg}) get _colors => switch (variant) {
        AppBadgeVariant.neutral => (bg: AppColors.neutral100, fg: AppColors.neutral700),
        AppBadgeVariant.primary => (bg: AppColors.primaryLight, fg: AppColors.primaryDark),
        AppBadgeVariant.success => (bg: AppColors.successBg, fg: AppColors.success),
        AppBadgeVariant.warning => (bg: AppColors.warningBg, fg: AppColors.warning),
        AppBadgeVariant.danger => (bg: AppColors.dangerBg, fg: AppColors.danger),
        AppBadgeVariant.info => (bg: AppColors.infoBg, fg: AppColors.info),
      };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.fg, height: 1.4)),
        ],
      ),
    );
  }
}
