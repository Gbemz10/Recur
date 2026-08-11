import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Segmented-style tab switcher (not the underline-per-page kind — use
/// Flutter's built-in `TabBar` for that). Good for filtering views within
/// a single page: "All / Active / Archived".
class AppTabs extends StatelessWidget {
  const AppTabs({super.key, required this.labels, required this.selectedIndex, required this.onSelect});

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.neutral100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: i == selectedIndex ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: i == selectedIndex
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: i == selectedIndex ? AppColors.neutral900 : AppColors.neutral500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
