import 'package:flutter/material.dart';

import '../data/mock_data.dart' show formatNaira, formatNairaCompact;
import '../data/profile_store.dart';
import '../data/spending_store.dart';
import '../data/subscription_store.dart';
import '../data/trial_store.dart';
import '../models/spending.dart';
import '../models/subscription.dart';
import '../models/trial.dart';
import '../theme/recur_brand.dart';
import '../ui/ui.dart';
import 'app_shell.dart' show AppTab;
import 'profile_screen.dart';
import 'subscription_detail_screen.dart';

/// Home: a digest of the whole app rather than a screen of its own.
///
/// It used to be the subscriptions screen wearing a total, carrying the
/// Active/Review/Cancelled lists that now live on Recurring. That made Home
/// and Recurring the same screen twice, and left spending and trials as
/// places you had to remember to visit.
///
/// Every block here is a summary that hands off to the tab that owns it. The
/// rule for what earns a place: it has to be something you would want to know
/// without asking. A total, anything imminent, where the rest of the money
/// went, and anything about to convert. Nothing here is a full list, because
/// a full list is what the other tabs are for.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.trialStore,
    required this.profileStore,
    required this.spendingStore,
    required this.onOpenTab,
  });

  final SubscriptionStore store;
  final TrialStore trialStore;
  final ProfileStore profileStore;
  final SpendingStore spendingStore;

  /// Switches the shell to another destination. Home is a set of doorways, so
  /// almost every card takes one.
  final void Function(AppTab tab, {int? section}) onOpenTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    for (final store in _stores) {
      store.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    for (final store in _stores) {
      store.removeListener(_onChange);
    }
    super.dispose();
  }

  List<Listenable> get _stores =>
      [widget.store, widget.trialStore, widget.profileStore, widget.spendingStore];

  void _onChange() {
    if (mounted) setState(() {});
  }

  List<Subscription> get _active => widget.store.byStatus(SubscriptionStatus.active);
  List<Subscription> get _review => widget.store.byStatus(SubscriptionStatus.unreviewed);

  double get _monthlyTotal => _active.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

  int _byUrgency(Subscription a, Subscription b) {
    final byDay = a.daysUntilCharge.compareTo(b.daysUntilCharge);
    return byDay != 0 ? byDay : b.amount.compareTo(a.amount);
  }

  /// The next few charges, whether or not they land inside a week. Home always
  /// answers "what is coming", even in a quiet month.
  ///
  /// Overdue rows are included rather than filtered out. An earlier version
  /// took only `daysUntilCharge >= 0`, which meant a charge whose date had
  /// just passed vanished from Home completely, taking the most urgent item on
  /// the screen with it. `_byUrgency` already sorts negatives first, so they
  /// land at the top where they belong.
  List<Subscription> get _upNext {
    final list = [..._active]..sort(_byUrgency);
    return list.take(3).toList();
  }

  List<Subscription> get _thisWeek {
    final list = _active.where((s) => s.isDueSoon).toList()..sort(_byUrgency);
    return list;
  }

  double get _thisWeekTotal => _thisWeek.fold(0.0, (sum, s) => sum + s.amount);

  List<Subscription> get _priceChanges =>
      _active.where((s) => s.hasPriceChange && s.priceIncreased).toList();

  List<TrialReminder> get _trialsDueSoon =>
      widget.trialStore.upcoming.where((t) => t.isDueSoon || t.isOverdue).toList();

  Future<void> _openDetail(Subscription sub) async {
    await Navigator.of(context).push<SubscriptionStatus>(
      MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(subscription: sub)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.isLoading && widget.store.all.isEmpty) {
      return const SafeArea(bottom: false, child: _HomeSkeleton());
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
                Text("Couldn't load your subscriptions",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                AppButton(label: 'Try again', onPressed: widget.store.load),
              ],
            ),
          ),
        ),
      );
    }

    const gap = SizedBox(height: AppSpacing.lg);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => Future.wait([
          widget.store.load(),
          widget.trialStore.load(),
          widget.profileStore.load(),
          widget.spendingStore.load(),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge),
          children: [
            _Greeting(profileStore: widget.profileStore, store: widget.store),
            const SizedBox(height: AppSpacing.lg),

            _HeroTotal(
              monthly: _monthlyTotal,
              count: _active.length,
              onTap: () => widget.onOpenTab(AppTab.recurring),
            ),

            // Only ever appears when something is genuinely imminent. A
            // permanent banner is wallpaper.
            if (_thisWeek.isNotEmpty) ...[
              gap,
              _AttentionStrip(
                total: _thisWeekTotal,
                subs: _thisWeek,
                onTap: () => widget.onOpenTab(AppTab.recurring),
              ),
            ],

            if (_priceChanges.isNotEmpty) ...[
              gap,
              _PriceChangeStrip(
                subs: _priceChanges,
                onTap: () => _openDetail(_priceChanges.first),
              ),
            ],

            if (_trialsDueSoon.isNotEmpty) ...[
              gap,
              _TrialStrip(
                trials: _trialsDueSoon,
                onTap: () => widget.onOpenTab(AppTab.trials),
              ),
            ],

            gap,
            _SpendingCard(
              store: widget.spendingStore,
              onTap: () => widget.onOpenTab(AppTab.spending),
            ),

            if (_review.isNotEmpty) ...[
              gap,
              _ReviewNudge(
                count: _review.length,
                onTap: () => widget.onOpenTab(AppTab.recurring, section: 1),
              ),
            ],

            if (_upNext.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              _SectionHeader(
                label: 'Up next',
                actionLabel: 'See all',
                onAction: () => widget.onOpenTab(AppTab.recurring),
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < _upNext.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _UpNextRow(subscription: _upNext[i], onTap: () => _openDetail(_upNext[i])),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Greeting plus avatar. Reads [ProfileStore] through the parent, which
/// already listens to it, so there is one load for the tab rather than one
/// per widget that happens to show a face.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.profileStore, required this.store});

  final ProfileStore profileStore;

  /// ProfileScreen shows subscription stats alongside the account, so it
  /// needs the same shared list every other tab reads.
  final SubscriptionStore store;

  String get _partOfDay {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final profile = profileStore.profile;
    final name = profile?.displayName?.split(' ').first;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Good morning, Gbemiga" rather than a greeting stacked over
                // "Your money". They know whose money it is; the only thing
                // worth saying here is their name. With no name on file yet
                // the greeting stands alone rather than inventing a
                // placeholder to sit under it.
                Text(
                  name == null ? _partOfDay : '$_partOfDay,',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted(context)),
                ),
                if (name != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: -0.5),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(store: store, profileStore: profileStore),
              ),
            ),
            child: AppAvatar(
              imageUrl: profile?.avatarUrl,
              name: profile?.displayName ?? profile?.email ?? '',
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

/// The number the whole app exists to produce.
///
/// On the brand gradient rather than a plain surface, which is the one place
/// in the app that treatment is spent. It is the single most important figure
/// here, it is the same object the onboarding preview shows, and giving it
/// real weight is most of what stops Home reading as a settings list.
class _HeroTotal extends StatelessWidget {
  const _HeroTotal({required this.monthly, required this.count, required this.onTap});

  final double monthly;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: RecurBrand.brandGradient,
          borderRadius: AppRadius.xlBR,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No icon. The label is already explicit, and a glyph beside it
            // only competed with the figure underneath, which is the one
            // thing on this card meant to be looked at.
            Text(
              'TOTAL MONTHLY SUBSCRIPTIONS',
              style: AppTypography.mono(
                size: 10.5,
                weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Counts up on first paint. The figure is the point of the screen,
            // and watching it assemble is what makes it feel calculated rather
            // than merely printed.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: monthly),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                formatNaira(value),
                style: AppTypography.money(size: 38, color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              count == 1 ? '1 active subscription' : '$count active subscriptions',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  '${formatNaira(monthly * 12)} a year',
                  style: AppTypography.money(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                Text(
                  'View all',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 17, color: Colors.white.withValues(alpha: 0.9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title with an optional action on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.actionLabel, this.onAction});

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    actionLabel!,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A coloured strip for something imminent. One shape, three meanings,
/// separated only by colour and copy, so the page has a consistent way of
/// saying "look at this".
class _AlertStrip extends StatelessWidget {
  const _AlertStrip({
    required this.color,
    required this.icon,
    required this.title,
    this.detail,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;

  /// Optional. A strip whose title already says the whole thing does not need
  /// a second line explaining it.
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: AppRadius.lgBR,
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: AppRadius.mdBR),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.ink(context)),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted(context)),
          ],
        ),
      ),
    );
  }
}

class _AttentionStrip extends StatelessWidget {
  const _AttentionStrip({required this.total, required this.subs, required this.onTap});

  final double total;
  final List<Subscription> subs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = subs.first;
    return _AlertStrip(
      color: AppColors.warning,
      icon: Icons.schedule_rounded,
      title: '${formatNaira(total)} hits this week',
      detail: '${first.displayName} first, ${first.nextChargeLabel.toLowerCase()}',
      onTap: onTap,
    );
  }
}

class _PriceChangeStrip extends StatelessWidget {
  const _PriceChangeStrip({required this.subs, required this.onTap});

  final List<Subscription> subs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = subs.first;
    return _AlertStrip(
      color: AppColors.danger,
      icon: Icons.trending_up_rounded,
      title: subs.length == 1 ? '${first.displayName} went up' : '${subs.length} prices went up',
      detail: subs.length == 1
          ? 'Now ${formatNaira(first.amount)}, was ${formatNaira(first.previousAmount!)}'
          : 'Tap to see what changed and by how much',
      onTap: onTap,
    );
  }
}

class _TrialStrip extends StatelessWidget {
  const _TrialStrip({required this.trials, required this.onTap});

  final List<TrialReminder> trials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = trials.first;
    return _AlertStrip(
      color: AppColors.info,
      icon: Icons.timer_rounded,
      title: trials.length == 1
          ? '${first.label} converts soon'
          : '${trials.length} trials convert soon',
      detail: first.isOverdue
          ? 'This one has already passed its end date'
          : 'Cancel before it turns into a real charge',
      onTap: onTap,
    );
  }
}

class _ReviewNudge extends StatelessWidget {
  const _ReviewNudge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AlertStrip(
      color: AppColors.primary,
      icon: Icons.fact_check_outlined,
      title: count == 1 ? '1 charge to review' : '$count charges to review',
      onTap: onTap,
    );
  }
}

/// Home's window into spending: the month's total, the split, and the top few
/// categories. Everything else lives on the Spending tab.
class _SpendingCard extends StatelessWidget {
  const _SpendingCard({required this.store, required this.onTap});

  final SpendingStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (store.isLoading && !store.hasData) return const AppSkeletonHeroCard();
    // A spending failure should not break Home, whose actual subject loaded.
    if (store.error != null || !store.hasData) return const SizedBox.shrink();

    final summary = store.summary;
    final top = summary.topCategories(4);
    if (top.isEmpty) return const SizedBox.shrink();

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EVERYTHING ELSE THIS MONTH',
                      style: AppTypography.mono(
                        size: 10.5,
                        color: AppColors.muted(context),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formatNaira(summary.total),
                      style: AppTypography.money(
                        size: 26,
                        color: AppColors.ink(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.muted(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSplitBar(
            slices: [
              for (final c in summary.categories.where((c) => c.spent > 0))
                DonutSlice(value: c.spent, color: c.category.color(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in top)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: c.category.color(context), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.category.shortLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.inkSoft(context)),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      formatNairaCompact(c.spent),
                      style: AppTypography.money(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: AppColors.ink(context),
                      ),
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

/// One upcoming charge. Deliberately lighter than [SubscriptionTile]: this is
/// a preview of the Recurring tab, not a second copy of it.
class _UpNextRow extends StatelessWidget {
  const _UpNextRow({required this.subscription, required this.onTap});

  final Subscription subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final due = subscription.isDueSoon;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: subscription.accentColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdBR,
            ),
            child: Center(
              child: Text(
                subscription.displayName.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: subscription.accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subscription.nextChargeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: due ? AppColors.warning : AppColors.muted(context),
                        fontWeight: due ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          Text(
            formatNaira(subscription.amount),
            style: AppTypography.money(
                size: 15, weight: FontWeight.w700, color: AppColors.ink(context)),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
      children: const [
        AppSkeletonBlock(height: 22, width: 110),
        SizedBox(height: AppSpacing.lg),
        AppSkeletonBlock(height: 186, radius: 16),
        SizedBox(height: AppSpacing.lg),
        AppSkeletonBlock(height: 74, radius: 12),
        SizedBox(height: AppSpacing.lg),
        AppSkeletonHeroCard(),
        SizedBox(height: AppSpacing.xxl),
        AppSkeletonListTile(),
        AppSkeletonListTile(),
      ],
    );
  }
}
