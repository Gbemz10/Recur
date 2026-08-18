import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Horizontal progress meter for spend against a budget.
///
/// Distinct from the thin unlabelled `_ShareBar` inside `subscription_tile`:
/// that one shows a proportion of a total that cannot be exceeded, so it only
/// ever needs to be a relative length. A budget can be blown, and the moment
/// it is, that is the single most important thing on the row. So this one
/// carries an over-budget state, and clamps the fill while recolouring it
/// rather than letting the bar silently sit at 100% whether someone is a
/// naira over or double.
class AppMeter extends StatelessWidget {
  const AppMeter({
    super.key,
    required this.progress,
    required this.color,
    this.height = 6,
    this.overColor,
    this.showOverflowNotch = true,
  });

  /// 0..1 under budget, above 1 over. Deliberately unclamped by the caller so
  /// this widget can tell the two apart.
  final double progress;

  /// Fill colour while under budget. Usually the category's own hue, so the
  /// meter agrees with the icon beside it.
  final Color color;

  /// Fill colour once over. Defaults to the palette's single loud colour,
  /// which is reserved for exactly this kind of "money is going somewhere you
  /// said you did not want it to" moment.
  final Color? overColor;

  final double height;

  /// Draws a hairline at the point the budget was crossed, so an over-budget
  /// bar still reads as "the limit was here" rather than just a full red bar.
  final bool showOverflowNotch;

  @override
  Widget build(BuildContext context) {
    final isOver = progress > 1;
    final fill = isOver ? (overColor ?? AppColors.warning) : color;
    final track = AppColors.track(context);

    // Over budget, the bar is full and the notch carries the information. The
    // alternative (scaling everything down so the overflow fits) shrinks the
    // meter the further over you go, which reads backwards.
    final fillFraction = progress.clamp(0.0, 1.0).toDouble();
    final notchFraction = isOver ? (1 / progress).clamp(0.0, 1.0).toDouble() : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: track),
                  child: SizedBox(width: width, height: height),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fillFraction),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Container(
                    // A floor, so a category with a token amount of spend
                    // still shows something rather than reading as zero.
                    width: v == 0 ? 0 : (width * v).clamp(height, width),
                    height: height,
                    decoration: BoxDecoration(color: fill),
                  ),
                ),
                if (isOver && showOverflowNotch && notchFraction > 0.04)
                  Positioned(
                    left: width * notchFraction,
                    child: Container(
                      width: 1.5,
                      height: height,
                      color: AppColors.surface(context).withValues(alpha: 0.85),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A meter with its label and figures above it, which is how every budget row
/// in the app presents one. Split from [AppMeter] so the bare bar stays
/// reusable somewhere that already has its own header.
class AppMeterRow extends StatelessWidget {
  const AppMeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    this.caption,
    this.leading,
    this.trailing,
  });

  final Widget label;
  final Widget value;
  final double progress;
  final Color color;
  final Widget? caption;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
            Expanded(child: label),
            const SizedBox(width: AppSpacing.sm),
            value,
            if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        AppMeter(progress: progress, color: color),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.sm),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.muted(context)),
            child: caption!,
          ),
        ],
      ],
    );
  }
}
