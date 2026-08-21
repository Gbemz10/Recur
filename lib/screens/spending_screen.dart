import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart' show formatNaira, formatNairaCompact;
import '../data/spending_store.dart';
import '../models/spending.dart';
import '../ui/ui.dart';
import 'category_transactions_screen.dart';

/// The full spending breakdown for a month.
///
/// The dashboard answers "how much is repeating"; this answers "where did the
/// rest of it go". Categories are ordered by spend rather than alphabetically
/// or by the taxonomy's own order, because the only reason to open this
/// screen is to find the big ones.
///
/// Budgets are presented inline on the same rows rather than on a separate
/// screen. A budget with no spend beside it is a number with no meaning, and
/// making people switch screens to compare the two is how budgeting features
/// end up unused.
class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key, required this.store});

  final SpendingStore store;

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openCategory(CategorySpend spend) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryTransactionsScreen(store: widget.store, category: spend.category),
      ),
    );
  }

  Future<void> _editBudget(CategorySpend spend) async {
    final result = await showAppSheet<_BudgetResult>(
      context,
      builder: (_) => _BudgetSheet(spend: spend),
    );
    if (result == null || !mounted) return;

    try {
      if (result.remove) {
        await widget.store.removeBudget(spend.category);
      } else {
        await widget.store.setBudget(spend.category, result.limit!);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    }
  }

  /// Index of the focused category, shared by the donut and its legend.
  ///
  /// Owned here rather than inside the donut card because "tap outside to
  /// unfocus" makes the whole tab the outside.
  int? _highlighted;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final summary = store.summary;

    // A tab now rather than a screen pushed from Home, so it owns no Scaffold
    // and no AppBar: the shell provides both, and a nested one would stack a
    // second bar under the status bar.
    //
    // The title sits outside the scroll view, so it stays put across loading,
    // error, empty and populated rather than each state drawing its own and
    // the header sliding away the moment anyone scrolls. Home is the only tab
    // that scrolls its heading, because there the greeting is content.
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
            child: Text(
              'Spending',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: -0.5),
            ),
          ),
          Expanded(
            // Tapping anywhere that is not a legend chip clears the focused
            // slice. Translucent so the scroll view and every card below still
            // get their own hits; a tap that turns into a drag is cancelled by
            // the scrollable, so this never fires mid-scroll.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_highlighted != null) setState(() => _highlighted = null);
              },
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: store.load,
                child: _buildBody(summary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SpendingSummary summary) {
    if (widget.store.isLoading && !widget.store.hasData) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: const [
          AppSkeletonHeroCard(),
          SizedBox(height: AppSpacing.xxl),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
        ],
      );
    }

    if (widget.store.error != null && !widget.store.hasData) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.huge),
          Text(
            "Couldn't load your spending",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: AppButton(label: 'Try again', onPressed: () => widget.store.load())),
        ],
      );
    }

    if (!widget.store.hasData) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: const [
          SizedBox(height: AppSpacing.huge),
          AppEmptyState(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Nothing to break down yet',
            message:
                'Once a month of transactions has synced from your bank, your spending shows up here, sorted by where it went.',
          ),
        ],
      );
    }

    final withSpend = summary.categories.where((c) => c.spent > 0 || c.hasBudget).toList();

    final top = summary.categories.where((c) => c.spent > 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge),
      children: [
        // Total first, then the chart. The figure is what someone opens this
        // tab for; the donut explains how it splits. Merged into one card
        // rather than stacked as two, because separating them meant printing
        // the same number twice, once as a headline and again in the donut's
        // centre.
        if (top.isNotEmpty)
          _DonutCard(
            summary: summary,
            slices: top,
            highlighted: _highlighted,
            onHighlight: (i) => setState(() => _highlighted = i),
          )
        else
          _TotalCard(summary: summary),

        // Only once there is more than one month with anything in it. A trend
        // drawn from a single month is one bar, which says nothing and looks
        // like a rendering failure.
        if (summary.hasTrend) ...[
          const SizedBox(height: AppSpacing.lg),
          _TrendCard(summary: summary),
        ],

        if (summary.uncategorizedCount > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          AppAlert(
            variant: AppAlertVariant.info,
            title: 'Still sorting ${summary.uncategorizedCount} transactions',
            message:
                'They are not in the totals below yet. This usually finishes within a minute of a sync.',
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),
        Text('By category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tap a category to see what is in it, or set a monthly cap.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
        ),
        const SizedBox(height: AppSpacing.lg),

        for (final spend in withSpend) ...[
          _CategoryRow(
            spend: spend,
            total: summary.total,
            onTap: () => _openCategory(spend),
            onEditBudget: () => _editBudget(spend),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// The donut, its total, and a tappable legend.
///
/// Tapping a legend row highlights its slice rather than navigating: the
/// question "which wedge is entertainment" should be answerable without
/// leaving the chart, and a donut with seven similar-weight colours is
/// unreadable without some way to point at one.
class _DonutCard extends StatefulWidget {
  const _DonutCard({
    required this.summary,
    required this.slices,
    required this.highlighted,
    required this.onHighlight,
  });

  final SpendingSummary summary;
  final List<CategorySpend> slices;

  /// Focused slice index, or null. Controlled by the screen so a tap anywhere
  /// outside the legend can clear it.
  final int? highlighted;
  final ValueChanged<int?> onHighlight;

  @override
  State<_DonutCard> createState() => _DonutCardState();
}

class _DonutCardState extends State<_DonutCard> {
  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final highlighted = widget.highlighted != null && widget.highlighted! < slices.length
        ? widget.highlighted
        : null;
    final focused = highlighted == null ? null : slices[highlighted];

    final over = widget.summary.overBudget;

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _TotalCard.periodLabel(widget.summary.period).toUpperCase(),
            style:
                AppTypography.mono(size: 10.5, color: AppColors.muted(context), letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatNaira(widget.summary.total),
            style: AppTypography.money(size: 34, color: AppColors.ink(context)),
          ),
          const SizedBox(height: 2),
          Text(
            'left your account this month',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
          ),
          if (over.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    over.length == 1
                        ? '${over.first.category.label} is over its budget'
                        : '${over.length} categories are over budget',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: AppDonut(
              size: 190,
              thickness: 23,
              highlighted: highlighted,
              slices: [
                for (final s in slices)
                  DonutSlice(
                      value: s.spent, color: s.category.color(context), label: s.category.label),
              ],
              // With the total printed above, the centre is free to answer the
              // question the chart itself raises: which slice is that, and how
              // big. Untouched it just names the split.
              center: focused == null
                  ? Text(
                      slices.length == 1 ? '1\ncategory' : '${slices.length}\ncategories',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted(context), height: 1.35),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          focused.category.shortLabel.toUpperCase(),
                          style: AppTypography.mono(
                            size: 9.5,
                            color: AppColors.muted(context),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatNairaCompact(focused.spent),
                          style: AppTypography.money(
                            size: 22,
                            weight: FontWeight.w700,
                            color: focused.category.color(context),
                          ),
                        ),
                        Text(
                          '${(focused.spent / widget.summary.total * 100).round()}%',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.muted(context)),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < slices.length; i++)
                _LegendChip(
                  spend: slices[i],
                  selected: highlighted == i,
                  onTap: () => widget.onHighlight(highlighted == i ? null : i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.spend, required this.selected, required this.onTap});

  final CategorySpend spend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = spend.category.color(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? spend.category.tint(context) : Colors.transparent,
          borderRadius: AppRadius.fullBR,
          border: Border.all(color: selected ? color : AppColors.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(
              spend.category.shortLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? AppColors.ink(context) : AppColors.inkSoft(context),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six months of totals, with this one picked out.
///
/// The breakdown answers "where did it go"; this answers "is that normal for
/// me", which is the question a single month cannot. The comparison against
/// the previous month is stated in words rather than left to the reader to
/// infer from two bar heights.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.summary});

  final SpendingSummary summary;

  @override
  Widget build(BuildContext context) {
    final trend = summary.trend;
    final current = trend.isNotEmpty ? trend.last.total : 0.0;
    final previous = trend.length > 1 ? trend[trend.length - 2].total : 0.0;
    final delta = current - previous;
    final up = delta > 0;

    // Only worth commenting on when there is a previous month to compare
    // against and it was not zero, since "up 100% from nothing" is noise.
    final comparable = previous > 0;
    final pct = comparable ? (delta.abs() / previous * 100).round() : 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Last six months', style: Theme.of(context).textTheme.titleSmall),
              ),
              if (comparable)
                Row(
                  children: [
                    Icon(
                      up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 14,
                      // Up is not automatically bad and down is not automatically
                      // good, but for spending it usually is, so this follows
                      // the money rather than a generic red/green.
                      color: up ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$pct% vs last month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: up ? AppColors.warning : AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppBarTrend(
            bars: [
              for (var i = 0; i < trend.length; i++)
                TrendBar(
                  value: trend[i].total,
                  label: trend[i].shortMonth,
                  isCurrent: i == trend.length - 1,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The month's headline figure.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});

  final SpendingSummary summary;

  /// `2026-08` -> `August 2026`. Done here rather than pulling in `intl` for
  /// one string; the rest of the app formats its own dates the same way.
  static String periodLabel(String period) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final parts = period.split('-');
    if (parts.length != 2) return 'This month';
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return 'This month';
    return '${months[month - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final overBudget = summary.overBudget;

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            periodLabel(summary.period).toUpperCase(),
            style: AppTypography.mono(
              size: 11,
              color: AppColors.muted(context),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatNaira(summary.total),
            style: AppTypography.money(size: 34, color: AppColors.ink(context)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'left your account this month',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
          ),
          if (overBudget.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const LedgerDivider(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    overBudget.length == 1
                        ? '${overBudget.first.category.label} is over its budget'
                        : '${overBudget.length} categories are over budget',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One category: icon, name, spend, and either a budget meter or a
/// share-of-total meter when no budget is set.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.spend,
    required this.total,
    required this.onTap,
    required this.onEditBudget,
  });

  final CategorySpend spend;
  final double total;
  final VoidCallback onTap;
  final VoidCallback onEditBudget;

  @override
  Widget build(BuildContext context) {
    final color = spend.category.color(context);
    // With a budget the meter means "how much of your cap"; without one it
    // falls back to "how much of this month", so the bar is never empty and
    // never means two things at once without saying which.
    final progress =
        spend.hasBudget ? spend.budgetProgress : (total > 0 ? spend.spent / total : 0.0);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: spend.category.tint(context),
                  borderRadius: AppRadius.mdBR,
                ),
                child: Icon(spend.category.icon, size: 19, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spend.category.label,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spend.transactionCount == 1
                          ? '1 transaction'
                          : '${spend.transactionCount} transactions',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatNaira(spend.spent),
                style: AppTypography.money(
                    size: 15, weight: FontWeight.w700, color: AppColors.ink(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppMeter(progress: progress, color: color),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _budgetCaption(context)),
              GestureDetector(
                onTap: onEditBudget,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  // Padding rather than a bare Text, so this reaches the 44px
                  // touch target the rest of the app's inline actions use.
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                  child: Text(
                    spend.hasBudget ? 'Edit cap' : 'Set a cap',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _budgetCaption(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted(context));

    if (!spend.hasBudget) {
      final share = total > 0 ? (spend.spent / total * 100).round() : 0;
      return Text('$share% of this month', style: muted);
    }

    if (spend.isOverBudget) {
      return Text(
        '${formatNaira(spend.spent - spend.monthlyLimit!)} over your ${formatNaira(spend.monthlyLimit!)} cap',
        style: muted?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
      );
    }

    return Text(
      '${formatNaira(spend.remaining)} left of ${formatNaira(spend.monthlyLimit!)}',
      style: spend.isNearBudget ? muted?.copyWith(fontWeight: FontWeight.w600) : muted,
    );
  }
}

// ------------------------------------------------------------------- budget

class _BudgetResult {
  const _BudgetResult({this.limit, this.remove = false});
  final double? limit;
  final bool remove;
}

/// Setting or clearing one category's monthly cap.
class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({required this.spend});

  final CategorySpend spend;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late String _digits = widget.spend.hasBudget ? widget.spend.monthlyLimit!.round().toString() : '';

  /// Suggested caps, built from what this category actually costs rather than
  /// from round numbers. Someone spending ₦121,000 on food is not helped by
  /// being offered ₦25,000, and a suggestion that is obviously wrong for you
  /// makes the whole row something to scroll past.
  List<double> get _presets {
    final spent = widget.spend.spent;
    if (spent <= 0) return const [10000, 25000, 50000, 100000];

    // Round to a step that reads as a decision rather than a measurement.
    double round(double v) {
      final step = v >= 100000
          ? 10000.0
          : v >= 20000
              ? 5000.0
              : 1000.0;
      return (v / step).round() * step;
    }

    final seen = <double>{};
    for (final multiplier in const [0.8, 1.0, 1.25, 1.6]) {
      final candidate = round(spent * multiplier);
      if (candidate > 0) seen.add(candidate);
    }
    final list = seen.toList()..sort();
    return list.take(4).toList();
  }

  String get _helper {
    final spent = widget.spend.spent;
    if (spent <= 0) return 'Nothing spent here yet this month';
    return '${formatNaira(spent)} spent so far this month';
  }

  void _submit() {
    final value = double.tryParse(_digits);
    if (value == null || value <= 0) return;
    Navigator.of(context).pop(_BudgetResult(limit: value));
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.spend.category;
    final valid = (double.tryParse(_digits) ?? 0) > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The category names itself. "Monthly cap for loans" spends a whole
        // line restating the screen you tapped to get here.
        Row(
          children: [
            Icon(category.icon, size: 22, color: category.color(context)),
            const SizedBox(width: AppSpacing.md),
            Text(
              category.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Recur emails you at 80% and again if you go over.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
                height: 1.5,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: AppColors.border(context)),
        const SizedBox(height: AppSpacing.xl),

        AppAmountEntry(
          value: _digits,
          helper: _helper,
          presets: _presets,
          onChanged: (v) => setState(() => _digits = v),
        ),

        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            if (widget.spend.hasBudget) ...[
              Expanded(
                child: AppButton(
                  label: 'Remove',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.lg,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(const _BudgetResult(remove: true)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: AppButton(
                label: widget.spend.hasBudget ? 'Save cap' : 'Set cap',
                size: AppButtonSize.lg,
                expand: true,
                onPressed: valid ? _submit : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
