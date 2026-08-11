import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/subscription.dart';
import '../ui/ui.dart';

/// One row in the subscriptions list.
///
/// Staggers itself in on first build — a list that assembles rather than
/// snaps in makes the detection feel like it just happened.
class SubscriptionTile extends StatefulWidget {
  const SubscriptionTile({
    super.key,
    required this.subscription,
    required this.index,
    required this.onTap,
    this.showConfidence = false,
    this.onConfirm,
    this.onDismiss,
  });

  final Subscription subscription;
  final int index;
  final VoidCallback onTap;

  /// In the review tab we show how sure the engine is, plus quick actions.
  final bool showConfidence;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;

  @override
  State<SubscriptionTile> createState() => _SubscriptionTileState();
}

class _SubscriptionTileState extends State<SubscriptionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: 40 * widget.index),
      () {
        if (mounted) _c.forward();
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final text = Theme.of(context).textTheme;
    final cancelled = sub.status == SubscriptionStatus.cancelled;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: widget.onTap,
        child: Column(
          children: [
            Row(
              children: [
                _MerchantMark(subscription: sub, faded: cancelled),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.merchant,
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
                            sub.cycle.label,
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.neutral500),
                          ),
                          const _Dot(),
                          Flexible(
                            child: Text(
                              cancelled
                                  ? 'Cancelled'
                                  : _nextChargeLabel(sub),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: sub.isDueSoon && !cancelled
                                    ? AppColors.warning
                                    : AppColors.neutral500,
                                fontWeight: sub.isDueSoon && !cancelled
                                    ? FontWeight.w600
                                    : null,
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
                      formatNaira(sub.amount),
                      style: text.titleSmall?.copyWith(
                        color: cancelled ? AppColors.neutral400 : null,
                      ),
                    ),
                    if (sub.cycle != BillingCycle.monthly) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${formatNaira(sub.monthlyEquivalent)}/mo',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.neutral400),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (widget.showConfidence) ...[
              const SizedBox(height: AppSpacing.lg),
              _ConfidenceBar(value: sub.confidence),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Not a subscription',
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.sm,
                      expand: true,
                      onPressed: widget.onDismiss,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Yes, it is',
                      size: AppButtonSize.sm,
                      expand: true,
                      onPressed: widget.onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _nextChargeLabel(Subscription sub) {
    final d = sub.daysUntilCharge;
    if (d < 0) return 'Overdue';
    if (d == 0) return 'Charges today';
    if (d == 1) return 'Charges tomorrow';
    if (d <= 7) return 'In $d days';
    return 'In $d days';
  }
}

class _MerchantMark extends StatelessWidget {
  const _MerchantMark({required this.subscription, this.faded = false});

  final Subscription subscription;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final color = faded ? AppColors.neutral400 : subscription.accentColor;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdBR,
      ),
      alignment: Alignment.center,
      child: Text(
        subscription.initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: color,
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  value >= 0.8
                      ? AppColors.success
                      : value >= 0.65
                          ? AppColors.warning
                          : AppColors.neutral400,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '$pct%',
          style: Theme.of(context).textTheme.labelSmall,
        ),
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
