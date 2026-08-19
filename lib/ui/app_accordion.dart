import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppAccordionItem {
  const AppAccordionItem({required this.title, required this.content});
  final String title;
  final Widget content;
}

/// Expand/collapse list — FAQ sections, settings groups. Only one panel
/// open at a time by default (typical FAQ pattern); pass [allowMultiple]
/// to let several stay open, which suits settings screens better.
class AppAccordion extends StatefulWidget {
  const AppAccordion({super.key, required this.items, this.allowMultiple = false});

  final List<AppAccordionItem> items;
  final bool allowMultiple;

  @override
  State<AppAccordion> createState() => _AppAccordionState();
}

class _AppAccordionState extends State<AppAccordion> {
  final Set<int> _openIndices = {};

  void _toggle(int index) {
    setState(() {
      if (_openIndices.contains(index)) {
        _openIndices.remove(index);
      } else {
        if (!widget.allowMultiple) _openIndices.clear();
        _openIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (int i = 0; i < widget.items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: () => _toggle(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(widget.items[i].title,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink(context))),
                        ),
                        AnimatedRotation(
                          turns: _openIndices.contains(i) ? 0.5 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted(context)),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    child: widget.items[i].content,
                  ),
                  crossFadeState: _openIndices.contains(i) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 150),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
