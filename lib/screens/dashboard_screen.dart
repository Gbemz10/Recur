import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart' show formatNaira;
import '../data/profile.dart';
import '../data/profile_service.dart';
import '../data/subscription_store.dart';
import '../models/subscription.dart';
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
  const DashboardScreen({super.key, required this.store});

  /// Shared across every tab in [AppShell], so a status change here is
  /// immediately visible on Calendar and Settings too.
  final SubscriptionStore store;

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

  Future<void> _updateStatus(Subscription sub, SubscriptionStatus status) async {
    try {
      await widget.store.updateStatus(sub, status);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
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
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 900)),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Greeting(store: widget.store)),

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
          const Expanded(child: Divider(color: AppColors.neutral200)),
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

class _Greeting extends StatefulWidget {
  const _Greeting({required this.store});

  final SubscriptionStore store;

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> {
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.getProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
    } on ApiException {
      // Header avatar just falls back to a generic mark below.
    }
  }

  String get _timeOfDay {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfileScreen(store: widget.store)),
              );
              _loadProfile();
            },
            child: AppAvatar(name: _profile?.displayLabel ?? 'Account', imageUrl: _profile?.avatarUrl),
          ),
        ],
      ),
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
        color: AppColors.white,
        borderRadius: AppRadius.xlBR,
        border: Border.all(color: AppColors.neutral200),
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
                  color: AppColors.neutral900,
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
        color: AppColors.neutral100,
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutral700),
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
