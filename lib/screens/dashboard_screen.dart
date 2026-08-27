import 'package:flutter/material.dart';

import '../data/mock_data.dart' show formatNaira, formatNairaCompact;
import '../data/notice_read_store.dart';
import '../data/bank_store.dart';
import '../data/notices.dart';
import '../data/profile_store.dart';
import '../data/spending_store.dart';
import '../data/subscription_store.dart';
import '../data/trial_store.dart';
import '../models/spending.dart';
import '../models/subscription.dart';
import '../theme/recur_brand.dart';
import '../ui/ui.dart';
import '../widgets/insight_strips.dart';
import 'app_shell.dart' show AppTab;
import 'link_bank_screen.dart';
import 'notifications_screen.dart';
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
    required this.readStore,
    required this.bankStore,
    required this.onOpenTab,
  });

  final SubscriptionStore store;
  final TrialStore trialStore;
  final ProfileStore profileStore;
  final SpendingStore spendingStore;
  final NoticeReadStore readStore;

  /// Home is the one screen that can be reached with nothing on it, so it is
  /// the one that has to know whether a bank was ever linked.
  final BankStore bankStore;

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

  List<Listenable> get _stores => [
        widget.store,
        widget.trialStore,
        widget.profileStore,
        widget.spendingStore,
        // So the badge drops the moment a notice is read on the page pushed
        // over this one.
        widget.readStore,
        // And so the empty state stops being empty the moment a bank lands.
        widget.bankStore,
      ];

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
  /// Nothing detected, in any state — not active, not waiting in Review, not
  /// cancelled. A row in any of those means the app has something to say.
  bool get _hasNothingYet => widget.store.all.isEmpty && !widget.store.isLoading;

  List<Subscription> get _upNext {
    final list = [..._active]..sort(_byUrgency);
    return list.take(3).toList();
  }

  /// Pushed rather than made a stage: someone who skipped linking at signup
  /// and came back to it later is mid-session, not mid-setup, and should end
  /// up back on Home with their subscriptions rather than walked through the
  /// rest of onboarding again.
  Future<void> _openLinkBank() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LinkBankScreen(onDone: () => Navigator.of(context).pop()),
      ),
    );
    if (!mounted) return;
    // Whatever happened in there, the two things Home reads may both have
    // changed: the bank list, and what the detector found from its first sync.
    await Future.wait([widget.bankStore.load(), widget.store.load()]);
  }

  Widget _greeting() => _Greeting(
        profileStore: widget.profileStore,
        store: widget.store,
        noticeCount:
            Notices.from(widget.store, widget.trialStore).unreadCount(widget.readStore.read),
        onOpenNotifications: _openNotifications,
      );

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          store: widget.store,
          trialStore: widget.trialStore,
          readStore: widget.readStore,
          onOpenTab: widget.onOpenTab,
        ),
      ),
    );
  }

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

    if (_hasNothingYet) {
      return SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => Future.wait([widget.store.load(), widget.bankStore.load()]),
          // A CustomScrollView rather than a Column, so pull-to-refresh still
          // works on a screen with nothing to scroll — SliverFillRemaining is
          // what lets the prompt sit in the middle of whatever space is left
          // rather than tight under the card.
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _greeting(),
                      const SizedBox(height: AppSpacing.lg),
                      _HeroTotal(
                        monthly: _monthlyTotal,
                        count: _active.length,
                        onTap: () => widget.onOpenTab(AppTab.recurring),
                      ),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.huge,
                  ),
                  // Column with a centred main axis rather than Center: the
                  // sliver hands down a bounded height, and this is the
                  // arrangement that actually uses all of it.
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NothingYet(
                        bankLinked: widget.bankStore.hasActiveBank,
                        onLinkBank: _openLinkBank,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
          widget.spendingStore.load(),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge),
          children: [
            _greeting(),
            const SizedBox(height: AppSpacing.lg),

            _HeroTotal(
              monthly: _monthlyTotal,
              count: _active.length,
              onTap: () => widget.onOpenTab(AppTab.recurring),
            ),

            // The imminent-charge, price-rise and trial alerts used to sit
            // here. They are behind the bell now: they made Home longer the
            // more there was to say, pushing the total — the thing this
            // screen exists for — down the page exactly when the month was
            // busiest.
            gap,
            _SpendingCard(
              store: widget.spendingStore,
              onTap: () => widget.onOpenTab(AppTab.spending),
            ),

            if (_review.isNotEmpty) ...[
              gap,
              ReviewNudge(
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
  const _Greeting({
    required this.profileStore,
    required this.store,
    required this.noticeCount,
    required this.onOpenNotifications,
  });

  final ProfileStore profileStore;

  /// ProfileScreen shows subscription stats alongside the account, so it
  /// needs the same shared list every other tab reads.
  final SubscriptionStore store;

  final int noticeCount;
  final VoidCallback onOpenNotifications;

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
          // Bell first, then the face. The alerts are the thing you might
          // have arrived to check; the account is where you go on purpose.
          NotificationBell(count: noticeCount, onTap: onOpenNotifications),
          const SizedBox(width: AppSpacing.xs),
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

/// What Home offers before it has anything to count.
///
/// Two situations, and telling them apart is the whole point. With no bank
/// linked there is an action to offer, and it is the one action the app is
/// asking for. With a bank linked and still nothing found, there is nothing to
/// do but wait — a button there would be a lie, since the next sync is not
/// something the user can hurry.
///
/// No card around it and no icon above it. A card would put a second bordered
/// box directly under the one carrying the total, and the two would read as a
/// pair of equals; this is a line of text and the thing to press.
class _NothingYet extends StatelessWidget {
  const _NothingYet({required this.bankLinked, required this.onLinkBank});

  final bool bankLinked;
  final VoidCallback onLinkBank;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          bankLinked ? 'Nothing repeating yet' : 'Connect a bank to begin',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
            color: AppColors.ink(context),
          ),
        ),
        if (!bankLinked) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Link my bank',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: onLinkBank,
          ),
        ],
      ],
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
