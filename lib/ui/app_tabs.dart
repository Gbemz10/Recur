import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Segmented tab switcher with an indicator that physically slides between
/// options.
///
/// The previous version swapped a white background from one tab to another,
/// which reads as two unrelated states rather than one thing moving. A
/// sliding indicator carries the eye across, so the user tracks *where they
/// went* instead of re-finding the selection.
///
/// Tabs are equal width by design — it keeps the slide distance uniform and
/// stops the indicator from stretching mid-flight, which looks like a bug.
class AppTabs extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const Duration _duration = Duration(milliseconds: 280);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 4.0;
        final trackWidth = constraints.maxWidth - padding * 2;
        final tabWidth = trackWidth / labels.length;

        return Container(
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            // Track and indicator were hardcoded neutral100/white — always
            // light, so this control stayed a bright light-mode pill
            // sitting on an otherwise dark screen. surfaceContainerHighest
            // and surface already carry the right tones per theme (see
            // AppColors.lightScheme/darkScheme).
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // The travelling indicator.
              AnimatedPositioned(
                duration: _duration,
                curve: _curve,
                left: tabWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    SizedBox(
                      width: tabWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: AnimatedDefaultTextStyle(
                            duration: _duration,
                            curve: _curve,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: i == selectedIndex
                                  ? AppColors.ink(context)
                                  : AppColors.muted(context),
                            ),
                            child: Text(
                              labels[i],
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
