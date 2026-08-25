import 'package:flutter/material.dart';

import '../data/mock_data.dart' show formatNaira;
import '../models/subscription.dart';
import '../models/trial.dart';
import '../ui/ui.dart';

/// The banner rows that say something needs attention.
///
/// They were private to Home, which was fine while Home was the only place
/// that had anything to announce. The bell moved them to their own page, and
/// two screens rendering the same alert from two copies of the same widget is
/// how the two slowly stop looking alike.

class AlertStrip extends StatelessWidget {
  const AlertStrip({
    required this.color,
    required this.icon,
    required this.title,
    this.detail,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;

  /// Optional. A strip whose title already says the whole thing does not need
  /// a second line explaining it.
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: AppRadius.lgBR,
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: AppRadius.mdBR),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.ink(context)),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted(context)),
          ],
        ),
      ),
    );
  }
}

class AttentionStrip extends StatelessWidget {
  const AttentionStrip({required this.total, required this.subs, required this.onTap});

  final double total;
  final List<Subscription> subs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = subs.first;
    return AlertStrip(
      color: AppColors.warning,
      icon: Icons.schedule_rounded,
      title: '${formatNaira(total)} hits this week',
      detail: '${first.displayName} first, ${first.nextChargeLabel.toLowerCase()}',
      onTap: onTap,
    );
  }
}

class PriceChangeStrip extends StatelessWidget {
  const PriceChangeStrip({required this.subs, required this.onTap});

  final List<Subscription> subs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = subs.first;
    return AlertStrip(
      color: AppColors.danger,
      icon: Icons.trending_up_rounded,
      title: subs.length == 1 ? '${first.displayName} went up' : '${subs.length} prices went up',
      detail: subs.length == 1
          ? 'Now ${formatNaira(first.amount)}, was ${formatNaira(first.previousAmount!)}'
          : 'Tap to see what changed and by how much',
      onTap: onTap,
    );
  }
}

class TrialStrip extends StatelessWidget {
  const TrialStrip({required this.trials, required this.onTap});

  final List<TrialReminder> trials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = trials.first;
    return AlertStrip(
      color: AppColors.info,
      icon: Icons.timer_rounded,
      title: trials.length == 1
          ? '${first.label} converts soon'
          : '${trials.length} trials convert soon',
      detail: first.isOverdue
          ? 'This one has already passed its end date'
          : 'Cancel before it turns into a real charge',
      onTap: onTap,
    );
  }
}

/// A trial whose reminder has expired: quiet, grey, and saying only that the
/// app is still watching.
///
/// Deliberately not one of the coloured strips. Colour on this row would put a
/// deadline on something that no longer has one, and there is nothing here to
/// act on — the whole message is "we have not forgotten".
class TrialWatchStrip extends StatelessWidget {
  const TrialWatchStrip({super.key, required this.trial, required this.onTap});

  final TrialReminder trial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AlertStrip(
      color: AppColors.muted(context),
      icon: Icons.visibility_outlined,
      title: '${trial.label} may have converted',
      detail: 'Recur is watching your statements for the charge',
      onTap: onTap,
    );
  }
}

class ReviewNudge extends StatelessWidget {
  const ReviewNudge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AlertStrip(
      color: AppColors.primary,
      icon: Icons.fact_check_outlined,
      title: count == 1 ? '1 charge to review' : '$count charges to review',
      onTap: onTap,
    );
  }
}
