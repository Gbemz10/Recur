import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppBadgeVariant { neutral, primary, success, warning, danger, info }

/// Small status pill for tags, statuses, and counts.
class AppBadge extends StatelessWidget {
  const AppBadge(
      {super.key, required this.label, this.variant = AppBadgeVariant.neutral, this.dot = false});

  final String label;
  final AppBadgeVariant variant;
  final bool dot;

  /// Every variant's light fill is a pale tint chosen to sit on white. Painted
  /// unchanged on a dark screen they all read as bright pills, which is what
  /// made a "Connected" badge the loudest thing in dark Settings. In dark we
  /// derive the pair instead: lift the ink until it is legible, then tint the
  /// surface with that same ink so the pill stays a whisper of the fill colour
  /// rather than a block of it.
  ({Color bg, Color fg}) _colors(BuildContext context) {
    final ink = switch (variant) {
      AppBadgeVariant.neutral => AppColors.neutral700,
      AppBadgeVariant.primary => AppColors.primaryDark,
      AppBadgeVariant.success => AppColors.success,
      AppBadgeVariant.warning => AppColors.warning,
      AppBadgeVariant.danger => AppColors.danger,
      AppBadgeVariant.info => AppColors.info,
    };

    if (Theme.of(context).brightness != Brightness.dark) {
      return (
        bg: switch (variant) {
          AppBadgeVariant.neutral => AppColors.neutral100,
          AppBadgeVariant.primary => AppColors.primaryLight,
          AppBadgeVariant.success => AppColors.successBg,
          AppBadgeVariant.warning => AppColors.warningBg,
          AppBadgeVariant.danger => AppColors.dangerBg,
          AppBadgeVariant.info => AppColors.infoBg,
        },
        fg: ink,
      );
    }

    final hsl = HSLColor.fromColor(ink);
    final fg = hsl.withLightness(hsl.lightness.clamp(0.62, 0.90)).toColor();
    return (
      bg: Color.alphaBlend(fg.withValues(alpha: 0.18), AppColors.surface(context)),
      fg: fg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.fg, height: 1.4)),
        ],
      ),
    );
  }
}
