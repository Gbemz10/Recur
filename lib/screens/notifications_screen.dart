import 'package:flutter/material.dart';

import '../data/notice_read_store.dart';
import '../data/notices.dart';
import '../data/subscription_store.dart';
import '../data/trial_store.dart';
import '../ui/ui.dart';
import '../widgets/insight_strips.dart';
import 'app_shell.dart' show AppTab;
import 'subscription_detail_screen.dart';

/// Everything that needs attention, in one place.
///
/// These alerts used to sit on Home, stacked between the monthly total and
/// the spending card. That made Home longer every time something needed
/// saying, and pushed the number the app exists to produce further up the
/// screen — the quieter your month, the better Home looked, which is exactly
/// backwards.
///
/// A page behind the bell keeps Home fixed in length and gives the alerts
/// somewhere to accumulate. Each one still hands off to the tab that owns it:
/// this is a list of doorways, same as Home was.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.store,
    required this.trialStore,
    required this.readStore,
    required this.onOpenTab,
  });

  final SubscriptionStore store;
  final TrialStore trialStore;
  final NoticeReadStore readStore;

  /// Switches the shell to another destination. Called after this page pops,
  /// since arriving on a tab with a notifications page still over it would
  /// leave the user tapping back to reach what they just asked for.
  final void Function(AppTab tab, {int? section}) onOpenTab;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
    widget.trialStore.addListener(_onChange);
    widget.readStore.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChange);
    widget.trialStore.removeListener(_onChange);
    widget.readStore.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// Reading a notice is tapping it, not arriving on this page.
  ///
  /// Clearing the badge on open would mean the count vanishes for anyone who
  /// glances at the page and backs out, which is exactly the person the badge
  /// was for. Acting on the row is the moment you have actually dealt with it.
  void _openTab(Notice notice, AppTab tab, {int? section}) {
    widget.readStore.markRead(notice.id);
    Navigator.of(context).pop();
    widget.onOpenTab(tab, section: section);
  }

  void _openSubscription(Notice notice) {
    widget.readStore.markRead(notice.id);
    final subscription = notice.subscriptions.first;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(subscription: subscription)),
    );
  }

  Widget _strip(Notice notice) {
    return switch (notice.kind) {
      NoticeKind.dueThisWeek => AttentionStrip(
          total: notice.total,
          subs: notice.subscriptions,
          onTap: () => _openTab(notice, AppTab.recurring),
        ),
      // One card per subscription now, each opening the only screen that
      // shows the old price beside the new one. Grouped, the card said "3
      // prices went up" and then opened one of them.
      NoticeKind.priceRise => PriceChangeStrip(
          subs: notice.subscriptions,
          onTap: () => _openSubscription(notice),
        ),
      NoticeKind.trialsEnding => TrialStrip(
          trials: notice.trials,
          onTap: () => _openTab(notice, AppTab.trials),
        ),
      // Review, not Trials: the reminder has left that tab, and Review is
      // where the charge will surface if the detector finds it.
      NoticeKind.trialMayHaveConverted => TrialWatchStrip(
          trial: notice.trials.first,
          onTap: () => _openTab(notice, AppTab.recurring, section: 1),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final notices = Notices.from(widget.store, widget.trialStore);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: AppEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Nothing needs you',
                  message: 'Charges landing soon, price rises and trials about to '
                      'convert will show up here.',
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.huge,
              ),
              children: [
                for (var i = 0; i < notices.items.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _MaybeRead(
                    read: widget.readStore.isRead(notices.items[i].id),
                    child: _strip(notices.items[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

/// A notice you have already acted on stays on the page — it is still true,
/// and a charge you have seen coming is still coming — but it stops asking for
/// attention. Dimming rather than removing, because a list that empties as you
/// touch it leaves you unsure whether you dealt with something or lost it.
class _MaybeRead extends StatelessWidget {
  const _MaybeRead({required this.read, required this.child});

  final bool read;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: read ? 0.45 : 1,
      child: child,
    );
  }
}

/// The bell, with a count when there is something behind it.
///
/// A dot would say "something happened"; the number says how much, which is
/// the difference between a badge you check and a badge you learn to ignore.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Transparent rather than none, so the padding around the icon is part
      // of the target instead of a dead ring around it.
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              count == 0 ? Icons.notifications_none_rounded : Icons.notifications_rounded,
              size: 23,
              color: AppColors.ink(context),
            ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                    // Against the page, not against the bell it overlaps —
                    // without this the badge and the icon merge into one shape
                    // at a glance.
                    border: Border.all(color: AppColors.background(context), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
