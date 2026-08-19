import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppNavItem {
  const AppNavItem({required this.label, required this.icon, this.selectedIcon});
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// Bottom nav bar for mobile layouts (<=4 destinations recommended).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.items, required this.selectedIndex, required this.onSelect});

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          i == selectedIndex ? (items[i].selectedIcon ?? items[i].icon) : items[i].icon,
                          color: i == selectedIndex ? AppColors.primary : AppColors.neutral400,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == selectedIndex ? AppColors.primary : AppColors.neutral400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible sidebar for desktop/tablet/dashboard layouts.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.header,
    this.width = 240,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget? header;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: header),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
              child: Material(
                color: i == selectedIndex ? AppColors.primaryTint(context) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          i == selectedIndex ? (items[i].selectedIcon ?? items[i].icon) : items[i].icon,
                          size: 20,
                          color: i == selectedIndex ? AppColors.primaryDark : AppColors.muted(context),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          items[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: i == selectedIndex ? AppColors.primaryDark : AppColors.neutral700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
