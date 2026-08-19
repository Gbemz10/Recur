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
    this.icons,
    this.itemWidth,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// When set, each segment renders its icon instead of its label and the
  /// label becomes the accessibility name. The Recurring list/calendar switch
  /// is this control with two icons, so the two segmented controls on that
  /// screen are the same widget rather than two lookalikes that drift.
  final List<IconData>? icons;

  /// Fixed width per segment. Null means fill the parent and divide evenly
  /// (Active/Review/Cancelled); a value makes the control size to its own
  /// content, which is what a switch sitting in a header row needs.
  final double? itemWidth;

  static const Duration _duration = Duration(milliseconds: 280);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    const padding = 4.0;

    if (itemWidth != null) {
      return SizedBox(
        width: itemWidth! * labels.length + padding * 2,
        child: _control(context, itemWidth!, padding),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => _control(
        context,
        (constraints.maxWidth - padding * 2) / labels.length,
        padding,
      ),
    );
  }

  Widget _control(BuildContext context, double tabWidth, double padding) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconMode = icons != null;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        // Track and indicator were hardcoded neutral100/white — always
        // light, so this control stayed a bright light-mode pill sitting on
        // an otherwise dark screen. surfaceContainerHighest and surface
        // already carry the right tones per theme.
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(iconMode ? 999 : 12),
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
                borderRadius: BorderRadius.circular(iconMode ? 999 : 9),
                // No shadow in dark. A drop shadow reads as depth only when
                // it is darker than the surface behind it; on a dark track it
                // is just a dark smear that appears out of nowhere as the
                // indicator arrives.
                boxShadow: isDark
                    ? null
                    : [
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
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: labels[i],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: iconMode
                          ? SizedBox(
                              height: 30,
                              child: Icon(
                                icons![i],
                                size: 17,
                                color: i == selectedIndex
                                    ? AppColors.ink(context)
                                    : AppColors.muted(context),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: AnimatedDefaultTextStyle(
                                duration: _duration,
                                curve: _curve,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      i == selectedIndex ? FontWeight.w700 : FontWeight.w600,
                                  color: i == selectedIndex
                                      ? AppColors.ink(context)
                                      : AppColors.muted(context),
                                ),
                                child: Text(labels[i], textAlign: TextAlign.center),
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
  }
}
