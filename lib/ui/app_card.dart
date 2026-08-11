import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Generic surface container. Prefer this over raw `Card` so every
/// surface in the app shares the same radius/border/shadow language.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
        boxShadow: elevated
            ? [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

/// Small metric card for dashboards: label, big number, optional trend.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendUp = true,
    this.icon,
  });

  final String label;
  final String value;
  final String? trend;
  final bool trendUp;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: textTheme.bodyMedium?.copyWith(color: AppColors.neutral500)),
              if (icon != null) Icon(icon, size: 18, color: AppColors.neutral400),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: textTheme.headlineMedium),
          if (trend != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14, color: trendUp ? AppColors.success : AppColors.danger),
                const SizedBox(width: 2),
                Text(trend!,
                    style: textTheme.bodySmall?.copyWith(
                      color: trendUp ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
