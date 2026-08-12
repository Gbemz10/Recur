import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
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
            decoration: const BoxDecoration(color: AppColors.neutral100, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: AppColors.neutral400),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink(context))),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral500, height: 1.5)),
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
              colors: const [AppColors.neutral100, AppColors.neutral200, AppColors.neutral100],
            ),
          ),
        );
      },
    );
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
