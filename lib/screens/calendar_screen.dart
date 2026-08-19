import 'package:flutter/material.dart';

import '../data/mock_data.dart' show formatNaira;
import '../data/subscription_store.dart';
import '../models/subscription.dart';
import '../ui/ui.dart';
import '../widgets/brand_mark.dart';

/// A single projected charge, landing on a specific date.
///
/// The model only stores one `nextChargeDate` per subscription, so a real
/// month view means projecting the rest of a cycle's occurrences forward
/// and backward from that anchor — a weekly plan shows up four or five
/// times a month, not once.
class _Occurrence {
  const _Occurrence({required this.date, required this.subscription});
  final DateTime date;
  final Subscription subscription;
}

/// Month view of every upcoming (and recent) charge.
///
/// Built around the same question as the dashboard, from a different
/// angle: not "how much total" but "which day". Someone budgeting around
/// payday cares which week gets hit, not just the monthly sum.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store, this.embedded = false});

  /// Shared with every other tab — a status change confirmed on Home shows
  /// up here immediately, instead of the calendar reading its own stale
  /// snapshot of the subscription list.
  final SubscriptionStore store;

  /// True when this renders as a view inside the Recurring tab rather than as
  /// a destination of its own. Drops the screen title, description and safe
  /// area, all of which the host already provides, so embedding it does not
  /// produce two stacked headers.
  final bool embedded;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_handleStoreChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_handleStoreChange);
    super.dispose();
  }

  void _handleStoreChange() {
    if (mounted) setState(() {});
  }

  List<Subscription> get _subs =>
      widget.store.all.where((s) => s.status != SubscriptionStatus.cancelled).toList();

  /// Steps a date forward or backward by one full billing cycle.
  DateTime _step(DateTime d, Subscription sub, int dir) {
    switch (sub.cycle) {
      case BillingCycle.weekly:
        return d.add(Duration(days: 7 * dir));
      case BillingCycle.biweekly:
        return d.add(Duration(days: 14 * dir));
      case BillingCycle.monthly:
        return DateTime(d.year, d.month + dir, d.day);
      case BillingCycle.quarterly:
        return DateTime(d.year, d.month + 3 * dir, d.day);
      case BillingCycle.yearly:
        return DateTime(d.year + dir, d.month, d.day);
      case BillingCycle.irregular:
        return d.add(Duration(days: _irregularIntervalDays(sub) * dir));
    }
  }

  /// Irregular has no fixed cadence by definition — estimate a step from
  /// the subscription's own charge history (median gap between charges),
  /// falling back to a month if there isn't enough history to measure
  /// from yet (matches the trial-watch/first-detection default elsewhere).
  int _irregularIntervalDays(Subscription sub) {
    if (sub.charges.length < 2) return 30;
    final sorted = [...sub.charges]..sort((a, b) => a.date.compareTo(b.date));
    final deltas = <int>[
      for (var i = 1; i < sorted.length; i++) sorted[i].date.difference(sorted[i - 1].date).inDays,
    ]..sort();
    final mid = deltas.length ~/ 2;
    final medianDays = deltas.length.isOdd ? deltas[mid] : ((deltas[mid - 1] + deltas[mid]) / 2).round();
    return medianDays > 0 ? medianDays : 30;
  }

  /// Every occurrence of every tracked subscription that lands within
  /// [_month], projected out from each subscription's stored anchor date.
  List<_Occurrence> get _monthOccurrences {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 1);
    final result = <_Occurrence>[];

    for (final sub in _subs) {
      var cursor = DateTime(
        sub.nextChargeDate.year,
        sub.nextChargeDate.month,
        sub.nextChargeDate.day,
      );
      // Rewind to well before the visible month.
      var guard = 0;
      while (cursor.isAfter(start) && guard < 60) {
        cursor = _step(cursor, sub, -1);
        guard++;
      }
      // Walk forward, collecting anything inside the visible month.
      guard = 0;
      while (cursor.isBefore(end) && guard < 60) {
        if (!cursor.isBefore(start)) {
          result.add(_Occurrence(date: cursor, subscription: sub));
        }
        cursor = _step(cursor, sub, 1);
        guard++;
      }
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<_Occurrence> _onDay(DateTime day) => _monthOccurrences
      .where((o) => o.date.year == day.year && o.date.month == day.month && o.date.day == day.day)
      .toList();

  double get _monthTotal =>
      _monthOccurrences.fold(0.0, (sum, o) => sum + o.subscription.amount);

  void _changeMonth(int dir) {
    setState(() {
      _month = DateTime(_month.year, _month.month + dir);
      _selected = DateTime(_month.year, _month.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Same "only take over the screen for the very first load" rule as
    // dashboard_screen.dart — a background refresh failing shouldn't blank
    // out a calendar someone's already looking at.
    if (widget.store.isLoading && widget.store.all.isEmpty) {
      return widget.embedded
          ? const _CalendarSkeleton()
          : const SafeArea(bottom: false, child: _CalendarSkeleton());
    }

    if (widget.store.error != null && widget.store.all.isEmpty) {
      return SafeArea(
        bottom: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Couldn't load your calendar", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                AppButton(label: 'Try again', onPressed: widget.store.load),
              ],
            ),
          ),
        ),
      );
    }

    final today = DateTime.now();
    final isCurrentMonth = _month.year == today.year && _month.month == today.month;
    final selectedOccurrences = _onDay(_selected);

    final body = RefreshIndicator(
        color: AppColors.primary,
        onRefresh: widget.store.load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? 0 : AppSpacing.xl,
            AppSpacing.lg,
            widget.embedded ? 0 : AppSpacing.xl,
            AppSpacing.huge,
          ),
          children: [
          if (!widget.embedded) ...[
            Text('Calendar', style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(
              'Every charge landing this month, mapped to the day it hits.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted(context), height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ---- month switcher ----
          Row(
            children: [
              _RoundIconButton(icon: Icons.chevron_left_rounded, onTap: () => _changeMonth(-1), tooltip: 'Previous month'),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_months[_month.month - 1]} ${_month.year}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink(context)),
                    ),
                    Text(
                      '${formatNaira(_monthTotal)} tracked',
                      style: AppTypography.mono(size: 11, weight: FontWeight.w500, color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              _RoundIconButton(icon: Icons.chevron_right_rounded, onTap: () => _changeMonth(1), tooltip: 'Next month'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- weekday header ----
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted(context)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ---- grid ----
          _MonthGrid(
            month: _month,
            selected: _selected,
            today: isCurrentMonth ? today : null,
            occurrencesFor: _onDay,
            onSelect: (day) => setState(() => _selected = day),
          ),

          const SizedBox(height: AppSpacing.xl),
          const LedgerDivider(),
          const SizedBox(height: AppSpacing.xl),

          // ---- selected day list ----
          Row(
            children: [
              Text(
                _selectedDayLabel(today),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink(context)),
              ),
              if (selectedOccurrences.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.track(context), borderRadius: AppRadius.fullBR),
                  child: Text(
                    '${selectedOccurrences.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted(context)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (selectedOccurrences.isEmpty)
            const AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing charges this day',
              message: 'Pick another date on the calendar above to see what lands then.',
            )
          else
            Column(
              children: [
                for (var i = 0; i < selectedOccurrences.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _OccurrenceRow(occurrence: selectedOccurrences[i]),
                ],
              ],
            ),
          ],
        ),
      );

    return widget.embedded ? body : SafeArea(bottom: false, child: body);
  }

  String _selectedDayLabel(DateTime today) {
    final sameDay = _selected.year == today.year && _selected.month == today.month && _selected.day == today.day;
    if (sameDay) return 'Today';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[_selected.weekday - 1]} ${_selected.day} ${_months[_selected.month - 1].substring(0, 3)}';
  }
}

/// First-load placeholder — title, a block standing in for the month grid
/// (not worth mirroring every day cell), then a couple of occurrence rows.
class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
      children: const [
        AppSkeleton(width: 140, height: 20),
        SizedBox(height: 4),
        AppSkeleton(width: 240, height: 13),
        SizedBox(height: AppSpacing.xl),
        AppSkeletonBlock(height: 320),
        SizedBox(height: AppSpacing.xl),
        AppSkeletonListTile(),
        SizedBox(height: AppSpacing.md),
        AppSkeletonListTile(),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.occurrencesFor,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime? today;
  final List<_Occurrence> Function(DateTime day) occurrencesFor;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: Monday=1..Sunday=7. Grid header starts on Sunday,
    // so convert to a Sunday-first offset.
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows * 7,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (context, i) {
        final dayNum = i - leadingBlanks + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

        final day = DateTime(month.year, month.month, dayNum);
        final occurrences = occurrencesFor(day);
        final isToday = today != null && today!.day == dayNum;
        final isSelected = selected.year == day.year && selected.month == day.month && selected.day == dayNum;

        return Padding(
          padding: const EdgeInsets.all(2),
          child: GestureDetector(
            onTap: () => onSelect(day),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primaryTint(context)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primaryDark
                              : AppColors.inkSoft(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 4,
                    child: occurrences.isEmpty
                        ? null
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final o in occurrences.take(3))
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : o.subscription.brand.brandColor,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OccurrenceRow extends StatelessWidget {
  const _OccurrenceRow({required this.occurrence});

  final _Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final sub = occurrence.subscription;
    final review = sub.status == SubscriptionStatus.unreviewed;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          BrandMark(
            slug: sub.brand.slug,
            fallbackLabel: sub.brand.name,
            brandColor: sub.brand.brandColor,
            networkUrl: sub.brand.logoUrl,
            size: 36,
            radius: 10,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  sub.cycle.label,
                  style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
          if (review)
            const AppBadge(label: 'Review', variant: AppBadgeVariant.warning, dot: true)
          else
            Text(
              formatNaira(sub.amount),
              style: AppTypography.mono(size: 14, weight: FontWeight.w600, color: AppColors.ink(context)),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        // See app_date_picker.dart's twin of this widget for why this
        // isn't a hardcoded AppColors.track(context) anymore.
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: AppColors.inkSoft(context)),
          ),
        ),
      ),
    );
  }
}
