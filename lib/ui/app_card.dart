import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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
        borderRadius: AppRadius.lgBR,
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
      borderRadius: AppRadius.lgBR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBR,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  // Two lines beats a truncated "Monthly equi…" — a label
                  // wrapping cleanly still reads fine at this size; losing
                  // the second half of the word doesn't.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, size: 18, color: AppColors.neutral400),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // A big naira figure in a narrow card is the one thing here that
          // must never wrap or truncate — losing digits off a money amount
          // is actively misleading, not just untidy. Scaling the whole line
          // down to fit keeps every digit visible instead.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.mono(size: 26, weight: FontWeight.w600, color: AppColors.ink(context)),
            ),
          ),
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
