import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppPagination extends StatelessWidget {
  const AppPagination({super.key, required this.currentPage, required this.totalPages, required this.onPageChange});

  final int currentPage; // 1-indexed
  final int totalPages;
  final ValueChanged<int> onPageChange;

  @override
  Widget build(BuildContext context) {
    // Show first, last, current +/-1, with ellipses for gaps.
    final pages = <int?>[];
    for (int p = 1; p <= totalPages; p++) {
      if (p == 1 || p == totalPages || (p - currentPage).abs() <= 1) {
        pages.add(p);
      } else if (pages.isNotEmpty && pages.last != null) {
        pages.add(null); // ellipsis marker
      }
    }

    Widget pageButton(int page) {
      final selected = page == currentPage;
      return InkWell(
        onTap: () => onPageChange(page),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.neutral600,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
        ),
        for (final p in pages)
          p == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text('…', style: TextStyle(color: AppColors.neutral400)),
                )
              : Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: pageButton(p)),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          onPressed: currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
        ),
      ],
    );
  }
}
