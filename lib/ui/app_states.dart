import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_dots_loader.dart';

/// Empty state for lists/tables with no data, or zero search results.
/// Always pair with a next action when one exists — an empty state that
/// dead-ends the user is a small but real source of churn.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.massive, horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.track(context), shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: AppColors.muted(context)),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink(context))),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted(context), height: 1.5)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Shimmering skeleton block for loading states. Compose several of these
/// to build a skeleton screen that mirrors the real layout — this reads
/// as faster than a spinner because the user sees content structure
/// appear immediately.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width = double.infinity, this.height = 16, this.radius = 8});

  final double width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Was hardcoded AppColors.neutral100/200 — both near-white, so in dark
    // mode this rendered as a barely-visible pale smear on a near-black
    // background instead of a shimmer. surfaceContainerHighest/border
    // already resolve to the right tone for whichever theme is active,
    // the same pair used for track backgrounds elsewhere (AppTabs, the
    // date picker's round icon buttons).
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = AppColors.border(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 3, 0),
              end: Alignment(0 + t * 3, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

/// A skeleton row mirroring [SubscriptionTile]'s shape — circular mark,
/// two lines of text, a right-aligned amount block — generic enough to
/// stand in for any list of that shape (subscriptions, linked banks,
/// trial reminders) while real data loads.
class AppSkeletonListTile extends StatelessWidget {
  const AppSkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const ClipOval(child: AppSkeleton(width: 42, height: 42, radius: 21)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeleton(width: 120, height: 14),
                SizedBox(height: 8),
                AppSkeleton(width: 80, height: 11),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppSkeleton(width: 56, height: 14),
              SizedBox(height: 6),
              AppSkeleton(width: 40, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// A skeleton mirroring the dashboard's hero total card — a label bar, a
/// large number, and a subtitle line, inside the same bordered surface.
class AppSkeletonHeroCard extends StatelessWidget {
  const AppSkeletonHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.xlBR,
        border: Border.all(color: AppColors.border(context)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 140, height: 11),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(width: 180, height: 34, radius: 6),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(width: 100, height: 12),
        ],
      ),
    );
  }
}

/// A large skeleton block for an irregularly-shaped area (a calendar grid,
/// a chart) where mirroring the exact structure isn't worth the effort —
/// just communicates "content is coming, roughly here."
class AppSkeletonBlock extends StatelessWidget {
  const AppSkeletonBlock({super.key, this.height = 280, this.radius = 16, this.width});

  final double height;
  final double radius;

  /// Null fills the available width. A value is for the cases where the real
  /// element does not, like a screen title, where a full-width bar would
  /// promise a much larger heading than actually arrives.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final block = AppSkeleton(height: height, radius: radius);
    return width == null ? block : SizedBox(width: width, child: block);
  }
}

/// Centered loading indicator for full-page or section loading.
///
/// Three dots, no label. See [AppDotsLoader] for why.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.size = 9, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(child: AppDotsLoader(size: size, color: color));
  }
}
