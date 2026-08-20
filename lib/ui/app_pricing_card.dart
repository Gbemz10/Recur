import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Pricing tier card. Set [highlighted] on the plan you want to sell —
/// it gets an elevated surface and a border to draw the eye without
/// resorting to a garish color.
class AppPricingCard extends StatelessWidget {
  const AppPricingCard({
    super.key,
    required this.planName,
    required this.price,
    required this.period,
    required this.features,
    required this.ctaLabel,
    this.onCta,
    this.highlighted = false,
    this.badge,
  });

  final String planName;
  final String price;
  final String period;
  final List<String> features;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool highlighted;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.neutral900 : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? AppColors.neutral900 : AppColors.neutral200),
        boxShadow: highlighted
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12))
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(planName,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: highlighted ? Colors.white : AppColors.neutral900)),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text(badge!,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price,
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: highlighted ? Colors.white : AppColors.neutral900)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(period,
                    style: TextStyle(
                        fontSize: 13,
                        color: highlighted ? AppColors.neutral400 : AppColors.muted(context))),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: highlighted ? Colors.white : AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(feature,
                        style: TextStyle(
                            fontSize: 13,
                            color: highlighted ? AppColors.neutral300 : AppColors.neutral600)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: ctaLabel,
            expand: true,
            onPressed: onCta,
            variant: highlighted ? AppButtonVariant.primary : AppButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}
