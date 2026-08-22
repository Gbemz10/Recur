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
  const RecurringScreen({super.key, required this.store, this.section});

  final SubscriptionStore store;

  /// Set by the shell when another screen wants a specific list — 0 Active,
  /// 1 Review, 2 Cancelled.
  final ValueNotifier<int>? section;

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

enum _View { list, calendar }

class _RecurringScreenState extends State<RecurringScreen> {
  int _tab = 0;
  int _tabDirection = 1;
  _View _view = _View.list;
  bool _showDismissed = false;

  static const _tabs = ['Active', 'Review', 'Cancelled'];

  /// Ids with a status change in flight, checked before starting another and
  /// used to disable a tile's own buttons. Without it a fast double tap fires
  /// two overlapping PATCHes for the same id.
  final Set<String> _pendingIds = {};

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
    widget.section?.addListener(_onSectionRequest);
  }

  void _onSectionRequest() {
    final requested = widget.section?.value ?? 0;
    if (!mounted || requested == _tab) return;
    setState(() {
      _tabDirection = requested > _tab ? 1 : -1;
      _tab = requested;
    });
  }

  @override
  void dispose() {
    widget.section?.removeListener(_onSectionRequest);
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  List<Subscription> get _active => widget.store.byStatus(SubscriptionStatus.active);

  /// Surest first.
  ///
  /// The detector already computes a confidence for every candidate
  /// (`computeConfidence` in the backend's detection service, from how many
  /// charges it saw, how regular their spacing is, whether the narration
  /// matched a known merchant, and whether the cycle is a named one). That
  /// number used to be printed on each row as a progress bar, which asked the
  /// user to do arithmetic on our uncertainty before answering a question
  /// about their own bank statement.
  ///
  /// It is still the right signal, just not the right thing to *show*. Spent
  /// on ordering instead, it makes the list answer itself from the top: the
  /// obvious ones go first and clear quickly, and the genuinely ambiguous ones
  /// arrive last, once the user has already built up a rhythm of answering.
  /// A tie breaks toward the larger charge, which is the more consequential
  /// one to get right.
  List<Subscription> get _review {
    final list = widget.store.byStatus(SubscriptionStatus.unreviewed).toList();
    list.sort((a, b) {
      final byConfidence = b.confidence.compareTo(a.confidence);
      return byConfidence != 0 ? byConfidence : b.amount.compareTo(a.amount);
    });
    return list;
  }

  List<Subscription> get _cancelled => widget.store.byStatus(SubscriptionStatus.cancelled);

  /// False positives the user has waved off. They get no tab of their own:
  /// nobody opens an app to browse things that were never subscriptions. They
  /// live behind a toggle on Cancelled, which is where someone would go
  /// looking if they thought they had answered one by mistake.
  List<Subscription> get _dismissed => widget.store.byStatus(SubscriptionStatus.dismissed);

  double get _monthlyTotal => _active.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);
  double get _savedMonthly => _cancelled.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

  /// Soonest first; a tie on the same day breaks toward the larger charge,
  /// which is the more consequential one to flag. Dart's sort is not stable,
  /// so without the second key two same-day rows could swap between builds.
  int _byUrgency(Subscription a, Subscription b) {
    final byDay = a.daysUntilCharge.compareTo(b.daysUntilCharge);
    return byDay != 0 ? byDay : b.amount.compareTo(a.amount);
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tabDirection = i > _tab ? 1 : -1;
      _tab = i;
    });
    // After the state change, not before. The notifier calls back
    // synchronously, so assigning first would move _tab out from under the
    // direction calculation on the line below it and every slide would run
    // backwards. Assigning the value we just adopted makes that callback a
    // no-op, while keeping the shell in sync so a later deep link into a
    // different section still registers as a change.
    widget.section?.value = i;
  }

  /// Where a row lands, said plainly.
  ///
  /// Every one of these moves the row to a different tab, so the row the user
  /// tapped vanishes from under their finger. Without a word about where it
  /// went, confirming a charge looks identical to deleting one.
  String _statusMessage(Subscription sub, SubscriptionStatus status) => switch (status) {
        SubscriptionStatus.active => '${sub.displayName} moved to Active',
        SubscriptionStatus.cancelled => '${sub.displayName} moved to Cancelled',
        SubscriptionStatus.unreviewed => '${sub.displayName} moved back to Review',
        SubscriptionStatus.dismissed => '${sub.displayName} dismissed',
      };

  Future<void> _updateStatus(Subscription sub, SubscriptionStatus status) async {
    if (_pendingIds.contains(sub.id)) return;
    // Captured before the call, because the row is what we would put back.
    final previous = sub.status;
    setState(() => _pendingIds.add(sub.id));
    try {
      await widget.store.updateStatus(sub, status);
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: _statusMessage(sub, status),
        // Green only when something was confirmed. Moving a row to Cancelled
        // or dismissing it are not wins, and colouring them as though they
        // were makes the colour meaningless everywhere else.
        variant: status == SubscriptionStatus.active
            ? AppAlertVariant.success
            : AppAlertVariant.info,
        // Undo rather than a confirmation dialog in front of every tap. This
        // is a status change, reversing it is the same call with the old
        // value, and a review list is meant to be answered quickly.
        actionLabel: 'Undo',
        onAction: () => _updateStatus(sub, previous),
      );
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
                child: AppTabs(
                  labels: _tabs,
                  // Only Review is counted. Active and Cancelled are where
                  // things live; Review is the one that is asking for
                  // something, and a number on all three would say nothing.
                  badges: [0, _review.length, 0],
                  selectedIndex: _tab,
                  onSelect: _selectTab,
                ),
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

    // Two groups. Rows whose predicted date has passed sort to the top of the
    // first one, where _byUrgency already puts them — the row's own
    // "Expected 18 Aug" says what state it is in, so it does not need a
    // heading and a paragraph above it repeating that in longer words.
    final soon = _active.where((s) => s.isDueSoon || s.isAwaitingCharge).toList()..sort(_byUrgency);
    final soonIds = soon.map((s) => s.id).toSet();
    // Soonest first, like the group above it. Sorting this by cost put a
    // yearly plan 300 days out above a monthly one charging next week, which
    // reads as a jumble on a list whose whole axis is time.
    final later = _active.where((s) => !soonIds.contains(s.id)).toList()..sort(_byUrgency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (soon.isNotEmpty) ...[
          _sectionHeader('Due soon', soon.length, accent: true),
          _list(soon),
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
        // No explainer banner. Each row already asks a question the user can
        // answer from their own memory of the charge, and how the detector
        // reached the shortlist is the backend's business.
        _list(_review, review: true),
      ],
    );
  }

  Widget _cancelledContent() {
    final dismissed = _dismissed;

    if (_cancelled.isEmpty && dismissed.isEmpty) {
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
        if (_cancelled.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
            // Counts cancellations only. A false positive was never money the
            // user was going to spend, so calling it a saving would be
            // flattering the app with someone else's number.
            child: _SavedCard(monthly: _savedMonthly),
          ),
          _list(_cancelled),
        ],
        if (dismissed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showDismissed = !_showDismissed),
              child: Row(
                children: [
                  Text(
                    'Dismissed',
                    style: AppTypography.mono(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: AppColors.muted(context),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: _showDismissed ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showDismissed) ...[
            const SizedBox(height: AppSpacing.md),
            _list(dismissed),
          ],
        ],
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
              showActions: review,
              busy: _pendingIds.contains(items[i].id),
              onTap: () => _openDetail(items[i]),
              onConfirm: review ? () => _updateStatus(items[i], SubscriptionStatus.active) : null,
              // Dismissed, not cancelled. The user is telling us the detector
              // was wrong, not that they ended something they were paying for.
              onDismiss:
                  review ? () => _updateStatus(items[i], SubscriptionStatus.dismissed) : null,
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
