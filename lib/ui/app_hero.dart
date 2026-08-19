import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Full-width marketing hero: eyebrow tag, display headline, subhead,
/// primary/secondary CTA row. Center-aligned by default for landing pages.
class AppHeroSection extends StatelessWidget {
  const AppHeroSection({
    super.key,
    required this.headline,
    required this.subhead,
    this.eyebrow,
    this.primaryCtaLabel,
    this.onPrimaryCta,
    this.secondaryCtaLabel,
    this.onSecondaryCta,
  });

  final String headline;
  final String subhead;
  final String? eyebrow;
  final String? primaryCtaLabel;
  final VoidCallback? onPrimaryCta;
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.massive, horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          if (eyebrow != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primaryTint(context), borderRadius: BorderRadius.circular(999)),
              child: Text(eyebrow!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryInk(context))),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text(
            headline,
            textAlign: TextAlign.center,
            style: textTheme.displaySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              subhead,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.muted(context)),
            ),
          ),
          if (primaryCtaLabel != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(label: primaryCtaLabel!, size: AppButtonSize.lg, onPressed: onPrimaryCta),
                if (secondaryCtaLabel != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: secondaryCtaLabel!,
                    size: AppButtonSize.lg,
                    variant: AppButtonVariant.outline,
                    onPressed: onSecondaryCta,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
