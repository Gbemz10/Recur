import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/subscription.dart';
import '../ui/ui.dart';
import 'brand_mark.dart';

/// One row in the subscriptions list.
///
/// Design intent: a financial list fails when every row carries the same
/// visual weight, because the user can't tell what's actually costing them
/// money. So each row shows its share of monthly spend as a thin bar under
/// the amount — ₦32,000 and ₦1,300 stop looking equivalent at a glance.
class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    super.key,
    required this.subscription,
    required this.onTap,
    this.shareOfSpend,
    this.showConfidence = false,
    this.onConfirm,
    this.onDismiss,
  });

  final Subscription subscription;
  final VoidCallback onTap;

  /// 0–1, this subscription's portion of total monthly spend. Null hides
  /// the bar — correct for cancelled items, which cost nothing.
  final double? shareOfSpend;

  /// In the review tab we show how sure the engine is, plus quick actions.
  final bool showConfidence;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cancelled = subscription.status == SubscriptionStatus.cancelled;
    final urgent = subscription.isDueSoon && !cancelled;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: cancelled ? 0.45 : 1,
                child: BrandMark(
                  slug: subscription.brand.slug,
                  fallbackLabel: subscription.brand.name,
                  brandColor: subscription.brand.brandColor,
                  networkUrl: subscription.brand.logoUrl,
                  size: 42,
                  radius: 12,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        decoration:
                            cancelled ? TextDecoration.lineThrough : null,
                        color: cancelled ? AppColors.neutral400 : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          subscription.cycle.label,
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.neutral500),
                        ),
                        const _Dot(),
                        Flexible(
                          child: Text(
                            cancelled
                                ? 'Cancelled'
                                : subscription.nextChargeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: urgent
                                  ? AppColors.warning
                                  : AppColors.neutral500,
                              fontWeight: urgent ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatNaira(subscription.amount),
                    style: AppTypography.mono(
                      size: 14,
                      weight: FontWeight.w600,
                      color: cancelled ? AppColors.neutral400 : AppColors.ink(context),
                    ),
                  ),
                  if (subscription.cycle != BillingCycle.monthly &&
                      !cancelled) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${formatNaira(subscription.monthlyEquivalent)}/mo',
                      style: AppTypography.mono(size: 11, weight: FontWeight.w500, color: AppColors.neutral400),
                    ),
                  ],
                  if (shareOfSpend != null && !cancelled) ...[
                    const SizedBox(height: 6),
                    _ShareBar(
                      share: shareOfSpend!,
                      color: subscription.accentColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (showConfidence) ...[
            const SizedBox(height: AppSpacing.lg),
            _ConfidenceRow(value: subscription.confidence),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Not a subscription',
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.sm,
                    expand: true,
                    onPressed: onDismiss,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Yes, it is',
                    size: AppButtonSize.sm,
                    expand: true,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin proportional bar. Deliberately unlabelled — the point is the
/// relative length, and a percentage next to every row would be noise.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share, required this.color});

  final double share;
  final Color color;

  static const double _width = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: 3,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const SizedBox(width: _width, height: 3),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              // Floor so a small subscription still registers visually.
              width: (_width * v).clamp(4.0, _width),
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    final color = value >= 0.8
        ? AppColors.success
        : value >= 0.65
            ? AppColors.warning
            : AppColors.neutral400;

    return Row(
      children: [
        Text(
          'Confidence',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.neutral500),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.fullBR,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: AppColors.neutral200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text('$pct%', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.neutral300,
        shape: BoxShape.circle,
      ),
    );
  }
}
