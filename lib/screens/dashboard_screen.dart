import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart' show formatNaira;
import '../data/profile_store.dart';
import '../data/subscription_store.dart';
import '../data/trial_store.dart';
import '../models/subscription.dart';
import '../models/trial.dart';
import '../ui/ui.dart';
import '../widgets/subscription_tile.dart';
import 'profile_screen.dart';
import 'subscription_detail_screen.dart';

/// The home screen.
///
/// Built around the three questions a financial dashboard has to answer in
/// about three seconds, without the user reading carefully:
///
///   1. **How much?**      → the hero total, the largest thing on screen.
///   2. **Is anything wrong?** → the attention strip, shown only when
///      something is actually imminent. A permanent banner is wallpaper.
///   3. **What's coming?**  → the list, grouped by *when it hits* rather
///      than presented flat, because "this week" and "next month" are
///      different kinds of problem.
///
/// The list is also sorted by cost within each group, and each row carries a
/// share-of-spend bar, so the expensive things are findable. A flat
/// alphabetical list of equal-weight rows hides exactly the information
/// someone opened the app to find.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.trialStore,
    required this.profileStore,
    required this.onOpenTrials,
  });

  /// Shared across every tab in [AppShell], so a status change here is
  /// immediately visible on Calendar and Settings too.
  final SubscriptionStore store;

  /// Manually-entered trial reminders — see [TrialStore].
  final TrialStore trialStore;

  /// Shared with every other tab — see [ProfileStore].
  final ProfileStore profileStore;

  /// Switches [AppShell] to the Trials tab — the strip below surfaces a
  /// due-soon trial inline, but managing it happens on its own tab, not a
  /// screen pushed on top of Home.
  final VoidCallback onOpenTrials;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  /// +1 when the new tab is to the right of the old one, -1 otherwise.
  /// Drives which way the content transition slides, so the motion agrees
  /// with the direction the sliding pill indicator just moved.
  int _tabDirection = 1;

  static const _tabs = ['Active', 'Review', 'Cancelled'];

  /// Subscription ids with a status change currently in flight — checked
  /// before starting another one, and used to disable a tile's own
  /// Confirm/Dismiss buttons while it's mid-request. Without this, a fast
  /// double-tap fires two overlapping PATCH requests for the same id
  /// before the first one's response even removes the row from Review.
  final Set<String> _pendingIds = {};

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_handleStoreChange);
    widget.trialStore.addListener(_handleStoreChange);
    widget.profileStore.addListener(_handleStoreChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_handleStoreChange);
    widget.trialStore.removeListener(_handleStoreChange);
    widget.profileStore.removeListener(_handleStoreChange);
    super.dispose();
  }

  void _handleStoreChange() {
    if (mounted) setState(() {});
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tabDirection = i > _tab ? 1 : -1;
      _tab = i;
    });
  }

  List<Subscription> get _active => widget.store.byStatus(SubscriptionStatus.active);
  List<Subscription> get _review => widget.store.byStatus(SubscriptionStatus.unreviewed);
  List<Subscription> get _cancelled => widget.store.byStatus(SubscriptionStatus.cancelled);

  double get _monthlyTotal =>
      _active.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

  double get _savedMonthly =>
      _cancelled.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

  /// Soonest first; ties on the same day break toward the larger charge —
  /// the more consequential one to flag. `List.sort` isn't stable in Dart,
  /// so without an explicit second key here, two same-day subscriptions
  /// would order arbitrarily (and could flip between runs with no change
  /// to the underlying data).
  int _byUrgency(Subscription a, Subscription b) {
    final byDay = a.daysUntilCharge.compareTo(b.daysUntilCharge);
    return byDay != 0 ? byDay : b.amount.compareTo(a.amount);
  }

  /// Closest upcoming charge among confirmed subscriptions, regardless of
  /// whether it lands within the "this week" window. Surfaced on the hero
  /// card so "what's next" doesn't require switching tabs to find out.
  Subscription? get _nextUp {
    final upcoming = _active.where((s) => s.daysUntilCharge >= 0).toList()
      ..sort(_byUrgency);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Everything landing within a week, soonest first.
  List<Subscription> get _thisWeek {
    final list = _active.where((s) => s.isDueSoon).toList()..sort(_byUrgency);
    return list;
  }

  double get _thisWeekTotal =>
      _thisWeek.fold(0.0, (sum, s) => sum + s.amount);

  /// Trial reminders converting soon enough to be worth interrupting the
  /// dashboard for — same "only when genuinely imminent" bar as
  /// [_thisWeek] above.
  List<TrialReminder> get _trialsDueSoon {
    final list = widget.trialStore.upcoming.where((t) => t.isDueSoon || t.isOverdue).toList();
    return list;
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
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailScreen(subscription: sub),
      ),
    );
    if (result != null) _updateStatus(sub, result);
  }

  @override
  Widget build(BuildContext context) {
    // Only takes over the whole screen for the very first load — once
    // there's data on hand, a failed background refresh shouldn't rip the
    // dashboard out from under someone who was already looking at it.
    if (widget.store.isLoading && widget.store.all.isEmpty) {
      return const SafeArea(bottom: false, child: _DashboardSkeleton());
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
                Text("Couldn't load your subscriptions", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                AppButton(label: 'Try again', onPressed: widget.store.load),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => Future.wait([
          widget.store.load(),
          widget.trialStore.load(),
          widget.profileStore.load(),
        ]),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Greeting(store: widget.store, profileStore: widget.profileStore),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  0,
                ),
                child: _HeroTotal(
                  monthly: _monthlyTotal,
                  count: _active.length,
                  savedMonthly: _savedMonthly,
                  nextUp: _nextUp,
                ),
              ),
            ),

            // Only appears when something is genuinely imminent.
            if (_thisWeek.isNotEmpty && _tab == 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    0,
                  ),
                  child: _AttentionStrip(
                    total: _thisWeekTotal,
                    subs: _thisWeek,
                  ),
                ),
              ),

            // A trial converting soon is the same kind of tension as a
            // charge landing soon — it just hasn't happened yet, so it gets
            // its own strip rather than being folded into the one above.
            if (_trialsDueSoon.isNotEmpty && _tab == 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    _thisWeek.isEmpty ? AppSpacing.lg : AppSpacing.md,
                    AppSpacing.xl,
                    0,
                  ),
                  child: _TrialStrip(
                    trials: _trialsDueSoon,
                    onTap: widget.onOpenTrials,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: AppTabs(
                  labels: _tabs,
                  selectedIndex: _tab,
                  onSelect: _selectTab,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: Offset(0.06 * _tabDirection, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return SlideTransition(
                      position: offset,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() => switch (_tab) {
        0 => _activeContent(),
        1 => _reviewContent(),
        _ => _cancelledContent(),
      };

  // ------------------------------------------------------------------ active

  Widget _activeContent() {
    if (_active.isEmpty) {
      return const AppEmptyState(
        icon: Icons.autorenew_rounded,
        title: 'No active subscriptions',
        message: 'Once we detect a repeating charge it will show up here.',
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
          _sectionHeader('Next 7 days', '${week.length}'),
          _list(week),
        ],
        if (later.isNotEmpty) ...[
          _sectionHeader('Later', '${later.length}'),
          _list(later),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------ review

  Widget _reviewContent() {
    if (_review.isEmpty) {
      return const AppEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Nothing to review',
        message: 'Every detected charge has been confirmed or dismissed.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Text(
            'These repeat, but not regularly enough for us to be certain. '
            'Confirming teaches the detection what to look for.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.neutral500, height: 1.5),
          ),
        ),
        _list(_review, review: true),
      ],
    );
  }

  // --------------------------------------------------------------- cancelled

  Widget _cancelledContent() {
    if (_cancelled.isEmpty) {
      return const AppEmptyState(
        icon: Icons.do_not_disturb_on_outlined,
        title: 'Nothing cancelled yet',
        message: 'When you cancel something it moves here, so you can see '
            'what you stopped paying for.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: _SavedBanner(monthly: _savedMonthly),
        ),
        _list(_cancelled),
      ],
    );
  }

  // ------------------------------------------------------------------ pieces

  Widget _sectionHeader(String label, String count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: AppRadius.fullBR,
            ),
            child: Text(
              count,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.neutral500,
              ),
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
              shareOfSpend: total > 0 && !review
                  ? items[i].monthlyEquivalent / total
                  : null,
              showConfidence: review,
              busy: _pendingIds.contains(items[i].id),
              onTap: () => _openDetail(items[i]),
              onConfirm: review
                  ? () => _updateStatus(items[i], SubscriptionStatus.active)
                  : null,
              onDismiss: review
                  ? () =>
                      _updateStatus(items[i], SubscriptionStatus.cancelled)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Reads [ProfileStore] directly rather than fetching its own copy — the
/// parent `DashboardScreen` already listens to it and rebuilds this on
/// every change, so there's exactly one load for the whole tab, not one
/// per widget that happens to show an avatar. During that one load this
/// shows a plain skeleton circle instead of a placeholder name/initial —
/// "A" for "Account" flashing before the real initial arrives read as a
/// glitch, not a loading state.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.store, required this.profileStore});

  final SubscriptionStore store;
  final ProfileStore profileStore;

  String get _timeOfDay {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final profile = profileStore.profile;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timeOfDay,
                  style: text.bodySmall?.copyWith(color: AppColors.neutral500),
                ),
                Text(
                  'Your repeats',
                  style: text.headlineSmall?.copyWith(letterSpacing: -0.4),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(store: store, profileStore: profileStore),
              ),
            ),
            child: profileStore.isInitialLoad
                ? const ClipOval(child: AppSkeleton(width: 40, height: 40))
                : AppAvatar(name: profile?.displayLabel ?? 'Account', imageUrl: profile?.avatarUrl),
          ),
        ],
      ),
    );
  }
}

/// First-load placeholder mirroring the real layout — hero card, then a
/// few list rows — so the dashboard reads as "loading this" rather than
/// a blank screen with a spinner.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
      children: const [
        AppSkeleton(width: 160, height: 20),
        SizedBox(height: 4),
        AppSkeleton(width: 220, height: 13),
        SizedBox(height: AppSpacing.xl),
        AppSkeletonHeroCard(),
        SizedBox(height: AppSpacing.xl),
        AppSkeletonListTile(),
        SizedBox(height: AppSpacing.md),
        AppSkeletonListTile(),
        SizedBox(height: AppSpacing.md),
        AppSkeletonListTile(),
      ],
    );
  }
}

/// The one number the app exists to show, styled like a statement line
/// rather than a marketing card: paper surface, ink text, the total set in
/// the ledger face with tabular figures so it never jitters sideways while
/// counting up. Everything else — the eyebrow, the yearly read, what's
/// next, what's already saved — sits quietly around it, separated by a
/// single dashed rule instead of colour blocks or icons competing for
/// attention.
class _HeroTotal extends StatelessWidget {
  const _HeroTotal({
    required this.monthly,
    required this.count,
    required this.savedMonthly,
    this.nextUp,
  });

  final double monthly;
  final int count;
  final double savedMonthly;
  final Subscription? nextUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        // Was hardcoded AppColors.white/neutral200 — the single most
        // prominent card on the whole screen stayed a bright light-mode
        // card regardless of theme, which is likely the worst offender
        // behind "no contrast in some screens." surface()/border() already
        // resolve to the right tone for whichever theme is active.
        color: AppColors.surface(context),
        borderRadius: AppRadius.xlBR,
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'LEAVING THIS MONTH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: AppColors.warning,
                  ),
                ),
              ),
              if (nextUp != null) _NextUpPill(subscription: nextUp!),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: monthly),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatNaira(value),
                maxLines: 1,
                style: AppTypography.mono(
                  size: 40,
                  weight: FontWeight.w600,
                  color: AppColors.ink(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const LedgerDivider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '${formatNaira(monthly * 12)} / yr',
                style: AppTypography.mono(
                  size: 12,
                  weight: FontWeight.w500,
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.neutral300, shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$count active',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral500),
              ),
              const Spacer(),
              if (savedMonthly > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_down_rounded, size: 13, color: AppColors.success),
                    const SizedBox(width: 3),
                    Text(
                      '${formatNaira(savedMonthly)}/mo cut',
                      style: AppTypography.mono(size: 11.5, weight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small "here's what's coming" pill in the card's top-right corner. The
/// hero card is the one place a user glances at daily — surfacing the
/// soonest charge here means they don't have to switch tabs to find it.
class _NextUpPill extends StatelessWidget {
  const _NextUpPill({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final label = switch (subscription.daysUntilCharge) {
      0 => 'today',
      1 => 'tomorrow',
      final d => 'in ${d}d',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        // Now that the hero card around this pill correctly darkens (see
        // _HeroTotal), a hardcoded light neutral100 here would read as an
        // odd bright pill inside an otherwise dark card.
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.fullBR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${subscription.brand.name} $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only when money is actually about to move. A banner that's always
/// there stops being read within a day.
class _AttentionStrip extends StatelessWidget {
  const _AttentionStrip({required this.total, required this.subs});

  final double total;
  final List<Subscription> subs;

  @override
  Widget build(BuildContext context) {
    final soonest = subs.first;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: AppRadius.lgBR,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.16),
              borderRadius: AppRadius.mdBR,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatNaira(total)} hits this week',
                  style: AppTypography.mono(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${soonest.displayName} first, '
                  '${soonest.nextChargeLabel.toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only when a manually-logged trial is close to converting — the
/// exact "only when genuinely imminent" bar as [_AttentionStrip], applied
/// to trials the detection engine can't see yet.
class _TrialStrip extends StatelessWidget {
  const _TrialStrip({required this.trials, required this.onTap});

  final List<TrialReminder> trials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soonest = trials.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgBR,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: AppRadius.lgBR,
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: AppRadius.mdBR,
                ),
                child: const Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trials.length == 1
                          ? '${soonest.label} trial ${soonest.endsLabel.toLowerCase()}'
                          : '${trials.length} trials ending soon',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Tap to review and cancel before they charge',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.warning, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.monthly});

  final double monthly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: AppRadius.lgBR,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.savings_outlined,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: AppColors.neutral800,
                ),
                children: [
                  const TextSpan(text: 'You have cut '),
                  TextSpan(
                    text: formatNaira(monthly),
                    style: AppTypography.mono(size: 13, weight: FontWeight.w600, color: AppColors.neutral900),
                  ),
                  const TextSpan(text: ' a month. That is '),
                  TextSpan(
                    text: formatNaira(monthly * 12),
                    style: AppTypography.mono(size: 13, weight: FontWeight.w600, color: AppColors.neutral900),
                  ),
                  const TextSpan(text: ' over a year.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
