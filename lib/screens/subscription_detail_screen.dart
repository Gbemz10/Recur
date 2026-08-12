import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/subscription.dart';
import '../ui/ui.dart';
import '../widgets/brand_mark.dart';

/// Detail view for a single detected subscription.
///
/// Pops with a [SubscriptionStatus] when the user changes the state of the
/// subscription, so the dashboard can update without a shared store — fine
/// at v1 size, replace with real state management when the backend lands.
class SubscriptionDetailScreen extends StatelessWidget {
  const SubscriptionDetailScreen({super.key, required this.subscription});

  final Subscription subscription;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cancelled = subscription.status == SubscriptionStatus.cancelled;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: Text(subscription.displayName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ---- header ----
            AppCard(
              child: Column(
                children: [
                  BrandMark(
                    slug: subscription.brand.slug,
                    fallbackLabel: subscription.brand.name,
                    brandColor: subscription.brand.brandColor,
                    networkUrl: subscription.brand.logoUrl,
                    size: 64,
                    radius: 18,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatNaira(subscription.amount),
                      maxLines: 1,
                      style: AppTypography.mono(
                        size: 32,
                        weight: FontWeight.w600,
                        color: AppColors.ink(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${subscription.cycle.label} · ${subscription.category.label}',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.neutral500),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (cancelled)
                    const AppBadge(
                      label: 'Cancelled',
                      variant: AppBadgeVariant.neutral,
                      dot: true,
                    )
                  else if (subscription.status ==
                      SubscriptionStatus.unreviewed)
                    const AppBadge(
                      label: 'Needs review',
                      variant: AppBadgeVariant.warning,
                      dot: true,
                    )
                  else
                    AppBadge(
                      label: subscription.isDueSoon
                          ? 'Charges in ${subscription.daysUntilCharge} days'
                          : 'Active',
                      variant: subscription.isDueSoon
                          ? AppBadgeVariant.warning
                          : AppBadgeVariant.success,
                      dot: true,
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---- cost breakdown ----
            Row(
              children: [
                Expanded(
                  child: AppStatCard(
                    label: 'Per year',
                    value: formatNaira(subscription.yearlyCost),
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppStatCard(
                    label: 'Per month',
                    value: formatNaira(subscription.monthlyEquivalent),
                    icon: Icons.autorenew_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---- why we flagged it ----
            Text('Why we flagged this', style: text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We found ${subscription.charges.length} charges of about '
                    '${formatNaira(subscription.amount)} arriving roughly '
                    '${subscription.cycle.label.toLowerCase()} from the same '
                    'merchant.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.neutral600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: AppRadius.smBR,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 16,
                          color: AppColors.neutral500,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            subscription.charges.first.narration,
                            style: AppTypography.mono(size: 12, weight: FontWeight.w500, color: AppColors.neutral600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---- charge history ----
            Text('Charge history', style: text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  for (var i = 0; i < subscription.charges.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.neutral200),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? subscription.accentColor
                                  : AppColors.neutral300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              _formatDate(subscription.charges[i].date),
                              style: text.bodyMedium,
                            ),
                          ),
                          Text(
                            formatNaira(subscription.charges[i].amount),
                            style: AppTypography.mono(size: 13, weight: FontWeight.w600, color: AppColors.ink(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---- how to cancel ----
            if (subscription.cancellationSteps.isNotEmpty && !cancelled) ...[
              Text('How to cancel', style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Recur cannot cancel on your behalf yet, so here are the '
                'exact steps.',
                style: text.bodySmall?.copyWith(color: AppColors.neutral500),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0;
                        i < subscription.cancellationSteps.length;
                        i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == subscription.cancellationSteps.length - 1
                              ? 0
                              : AppSpacing.lg,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                subscription.cancellationSteps[i],
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.neutral700,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // ---- actions ----
            if (cancelled)
              AppButton(
                label: 'Mark as active again',
                variant: AppButtonVariant.outline,
                size: AppButtonSize.lg,
                expand: true,
                onPressed: () =>
                    Navigator.of(context).pop(SubscriptionStatus.active),
              )
            else
              AppButton(
                label: 'I cancelled this',
                variant: AppButtonVariant.destructive,
                size: AppButtonSize.lg,
                expand: true,
                icon: Icons.do_not_disturb_on_outlined,
                onPressed: () async {
                  final confirmed = await showAppConfirmDialog(
                    context,
                    title: 'Mark as cancelled?',
                    message:
                        'We will stop counting ${subscription.displayName} in '
                        'your monthly total and let you know if it charges '
                        'you again.',
                    confirmLabel: 'Mark cancelled',
                  );
                  if (confirmed && context.mounted) {
                    Navigator.of(context).pop(SubscriptionStatus.cancelled);
                  }
                },
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
