import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart' show formatNaira;
import '../data/subscription_store.dart';
import '../models/subscription.dart';
import '../ui/ui.dart';
import '../widgets/subscription_tile.dart';
import 'calendar_screen.dart';
import 'subscription_detail_screen.dart';

/// Everything that repeats, in one place.
///
/// This used to be split across two destinations that answered the same
/// question from different angles: Home carried the Active/Review/Cancelled
/// lists, and Calendar carried the month grid. Neither was a whole idea on
/// its own, and Home was doing two jobs at once. They are one tab now, with
/// the calendar as a *view* of this data rather than a separate place, which
/// is what it always was.
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key, required this.store});

  final SubscriptionStore store;

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

enum _View { list, calendar }

class _RecurringScreenState extends State<RecurringScreen> {
  int _tab = 0;
  int _tabDirection = 1;
  _View _view = _View.list;

  static const _tabs = ['Active', 'Review', 'Cancelled'];

  /// Ids with a status change in flight, checked before starting another and
  /// used to disable a tile's own buttons. Without it a fast double tap fires
  /// two overlapping PATCHes for the same id.
  final Set<String> _pendingIds = {};

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

  List<Subscription> get _active => widget.store.byStatus(SubscriptionStatus.active);
  List<Subscription> get _review => widget.store.byStatus(SubscriptionStatus.unreviewed);
  List<Subscription> get _cancelled => widget.store.byStatus(SubscriptionStatus.cancelled);

  double get _monthlyTotal => _active.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);
  double get _savedMonthly => _cancelled.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

  /// Soonest first; a tie on the same day breaks toward the larger charge,
  /// which is the more consequential one to flag. Dart's sort is not stable,
  /// so without the second key two same-day rows could swap between builds.
  int _byUrgency(Subscription a, Subscription b) {
    final byDay = a.daysUntilCharge.compareTo(b.daysUntilCharge);
    return byDay != 0 ? byDay : b.amount.compareTo(a.amount);
  }

  /// Due within the week, plus anything already past its date.
  ///
  /// `isDueSoon` is false once a charge date passes, so filtering on it alone
  /// dropped overdue rows into the "Later" group underneath, which is the
  /// opposite of where they belong. `_byUrgency` sorts negatives first, so
  /// they land at the top of the urgent group.
  List<Subscription> get _thisWeek {
    final list = _active.where((s) => s.isDueSoon || s.daysUntilCharge < 0).toList()
      ..sort(_byUrgency);
    return list;
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tabDirection = i > _tab ? 1 : -1;
      _tab = i;
    });
  }

  Future<void> _updateStatus(Subscription sub, SubscriptionStatus status) async {
    if (_pendingIds.contains(sub.id)) return;
    setState(() => _pendingIds.add(sub.id));
    try {
      await widget.store.updateStatus(sub, status);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    } finally {
      if (mounted) setState(() => _pendingIds.remove(sub.id));
    }
  }

  Future<void> _openDetail(Subscription sub) async {
    final result = await Navigator.of(context).push<SubscriptionStatus>(
      MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(subscription: sub)),
    );
    if (result != null) _updateStatus(sub, result);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final firstLoad = store.isLoading && store.all.isEmpty;
    final failed = store.error != null && store.all.isEmpty;

    // Fixed header, same as every other tab except Home: the title and the
    // list/calendar switch stay put rather than scrolling away, so the control
    // that changes what you are looking at is always reachable. It sits above
    // the state branch rather than inside each one, so loading, error and
    // content all render under the same header instead of the title appearing
    // only once data arrives.
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, showSwitch: !firstLoad && !failed),
          Expanded(
            child: firstLoad
                ? const _RecurringSkeleton()
                : failed
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Couldn't load your subscriptions",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppButton(label: 'Try again', onPressed: store.load),
                            ],
                          ),
                        ),
                      )
                    : _scrollBody(store),
          ),
        ],
      ),
    );
  }

  Widget _scrollBody(SubscriptionStore store) {
    // The two views cross-fade and slide past each other rather than swapping
    // instantly. They are two readings of the same subscriptions, so the
    // transition should feel like turning the data around rather than
    // arriving somewhere new: calendar comes in from the right, the list from
    // the left, matching the order of the buttons that trigger them.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(_view);
        final dir = _view == _View.calendar ? 1.0 : -1.0;
        return SlideTransition(
          position: Tween<Offset>(
            // The outgoing view leaves the way the incoming one arrives from,
            // so they travel together instead of crossing in opposite
            // directions and reading as two unrelated animations.
            begin: Offset(incoming ? 0.10 * dir : -0.10 * dir, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      child: KeyedSubtree(key: ValueKey(_view), child: _viewBody(store)),
    );
  }

  Widget _viewBody(SubscriptionStore store) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: store.load,
      child: CustomScrollView(
        slivers: [
          if (_view == _View.list) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
                child: AppTabs(labels: _tabs, selectedIndex: _tab, onSelect: _selectTab),
              ),
            ),
            SliverToBoxAdapter(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0.06 * _tabDirection, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, if (currentChild != null) currentChild],
                  ),
                  child: KeyedSubtree(key: ValueKey(_tab), child: _listBody()),
                ),
              ),
            ),
          ] else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: CalendarScreen(store: store, embedded: true),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ header

  Widget _header(BuildContext context, {bool showSwitch = true}) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recurring', style: text.headlineSmall?.copyWith(letterSpacing: -0.5)),
                  ],
                ),
              ),
              // The calendar is a lens on this same list, so it belongs on a
              // switch here rather than behind its own tab in the bottom bar.
              if (showSwitch)
                AppTabs(
                  labels: const ['List view', 'Calendar view'],
                  icons: const [Icons.view_agenda_outlined, Icons.calendar_today_rounded],
                  itemWidth: 44,
                  selectedIndex: _view == _View.list ? 0 : 1,
                  onSelect: (i) => setState(
                    () => _view = i == 0 ? _View.list : _View.calendar,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- lists

  Widget _listBody() => switch (_tab) {
        0 => _activeContent(),
        1 => _reviewContent(),
        _ => _cancelledContent(),
      };

  Widget _activeContent() {
    if (_active.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppEmptyState(
          icon: Icons.autorenew_rounded,
          title: 'No active subscriptions',
          message: 'Once Recur detects a repeating charge it shows up here.',
        ),
      );
    }

    final week = _thisWeek;
    final weekIds = week.map((s) => s.id).toSet();
    final later = _active.where((s) => !weekIds.contains(s.id)).toList()
      ..sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (week.isNotEmpty) ...[
          _sectionHeader('Needs attention', week.length, accent: true),
          _list(week),
        ],
        if (later.isNotEmpty) ...[
          _sectionHeader('Later', later.length),
          _list(later),
        ],
      ],
    );
  }

  Widget _reviewContent() {
    if (_review.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppEmptyState(
          icon: Icons.fact_check_outlined,
          title: 'Nothing to review',
          message: 'Every detected charge has been confirmed or dismissed.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
          child: const AppAlert(
            variant: AppAlertVariant.info,
            message: 'These repeat, but not regularly enough to be certain. '
                'Confirming teaches the detection what to look for.',
          ),
        ),
        _list(_review, review: true),
      ],
    );
  }

  Widget _cancelledContent() {
    if (_cancelled.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppEmptyState(
          icon: Icons.do_not_disturb_on_outlined,
          title: 'Nothing cancelled yet',
          message: 'When you cancel something it moves here, so you can see '
              'what you stopped paying for.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
          child: _SavedCard(monthly: _savedMonthly),
        ),
        _list(_cancelled),
      ],
    );
  }

  Widget _sectionHeader(String label, int count, {bool accent = false}) {
    final color = accent ? AppColors.warning : AppColors.muted(context);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.mono(
                size: 10.5, weight: FontWeight.w700, color: color, letterSpacing: 1.2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: accent ? AppColors.warning.withValues(alpha: 0.12) : AppColors.track(context),
              borderRadius: AppRadius.fullBR,
            ),
            child: Text(
              '$count',
              style: AppTypography.mono(size: 10, weight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(color: AppColors.border(context))),
        ],
      ),
    );
  }

  Widget _list(List<Subscription> items, {bool review = false}) {
    final total = _monthlyTotal;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: SubscriptionTile(
              subscription: items[i],
              shareOfSpend: total > 0 && !review ? items[i].monthlyEquivalent / total : null,
              showConfidence: review,
              busy: _pendingIds.contains(items[i].id),
              onTap: () => _openDetail(items[i]),
              onConfirm: review ? () => _updateStatus(items[i], SubscriptionStatus.active) : null,
              onDismiss:
                  review ? () => _updateStatus(items[i], SubscriptionStatus.cancelled) : null,
            ),
          ),
        ],
      ],
    );
  }
}

/// Segmented list/calendar toggle.
class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.monthly});

  final double monthly;

  @override
  Widget build(BuildContext context) {
    if (monthly <= 0) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdBR,
            ),
            child: const Icon(Icons.trending_down_rounded, size: 20, color: AppColors.success),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cut from your monthly bill', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${formatNaira(monthly * 12)} a year',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
          Text(
            formatNaira(monthly),
            style: AppTypography.money(size: 17, weight: FontWeight.w700, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

class _RecurringSkeleton extends StatelessWidget {
  const _RecurringSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      children: const [
        AppSkeletonBlock(height: 42),
        SizedBox(height: AppSpacing.xl),
        AppSkeletonListTile(),
        AppSkeletonListTile(),
        AppSkeletonListTile(),
      ],
    );
  }
}
