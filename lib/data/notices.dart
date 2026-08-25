import '../models/subscription.dart';
import '../models/trial.dart';
import 'subscription_store.dart';
import 'trial_store.dart';

enum NoticeKind {
  /// Charges landing inside the week, grouped into one line. Tapping goes to
  /// Recurring, which lists them.
  dueThisWeek,

  /// One subscription whose price went up. One notice each rather than a
  /// group: the only screen that shows an old price against a new one is that
  /// subscription's own detail page, so a grouped card would promise a list it
  /// cannot open.
  priceRise,

  /// Trials about to convert, grouped. Tapping goes to Trials, which lists
  /// them — so unlike a price rise, the group can deliver what it promises.
  trialsEnding,

  /// A trial whose reminder has expired off the Trials tab.
  ///
  /// Secondary, and rendered quietly: there is nothing to do about it and no
  /// deadline left to miss. It is here because the reminder disappearing
  /// should not read as Recur having forgotten — the detector is still
  /// watching the statements for the charge, and this says so.
  trialMayHaveConverted,
}

/// One thing the app has to tell you.
class Notice {
  const Notice({
    required this.id,
    required this.kind,
    this.subscriptions = const [],
    this.trials = const [],
    this.total = 0,
  });

  /// Stable across restarts, and deliberately derived from *what the notice is
  /// about* rather than its position in the list.
  ///
  /// It changes when the underlying facts change, which is what makes read
  /// state behave: a new charge entering the week, or a second price rise on
  /// the same subscription, produces a new id and so a notice you have not
  /// seen. Marking one read can never silence the next one.
  final String id;

  final NoticeKind kind;
  final List<Subscription> subscriptions;
  final List<TrialReminder> trials;

  /// Only meaningful for [NoticeKind.dueThisWeek].
  final double total;
}

/// Everything the app currently has to tell you, derived from what it already
/// knows rather than stored anywhere.
///
/// These used to be computed inside Home's build and rendered as banners
/// stacked under the total. Home was answering two questions at once — what am
/// I spending, and what needs attention — and the second one kept pushing the
/// first down the screen. They live behind the bell now, and this is the one
/// place that decides what counts as a notice, so the badge and the page can
/// never disagree about how many there are.
///
/// The notices themselves are not persisted: one exists exactly as long as the
/// thing it describes is true, so a charge landing this week stops being a
/// notice when it lands. Only whether you have *read* one is stored, and that
/// lives in NoticeReadStore.
class Notices {
  const Notices(this.items);

  /// From the app's shared stores, which is how every screen builds it.
  factory Notices.from(SubscriptionStore subscriptions, TrialStore trials) =>
      Notices.of(subscriptions: subscriptions.all, trials: trials.all);

  /// From plain lists. The rules live here rather than in the store-shaped
  /// constructor above so they can be exercised without a network in the way.
  factory Notices.of({
    required List<Subscription> subscriptions,
    required List<TrialReminder> trials,
  }) {
    final active = subscriptions.where((s) => s.status == SubscriptionStatus.active).toList();

    // Soonest first, and a tie on the same day breaks toward the larger
    // charge — the same order Home used, since the first row is what the
    // summary line quotes.
    int byUrgency(Subscription a, Subscription b) {
      final byDay = a.daysUntilCharge.compareTo(b.daysUntilCharge);
      return byDay != 0 ? byDay : b.amount.compareTo(a.amount);
    }

    final notices = <Notice>[];

    // Ordered by how soon it costs you money: a charge already on its way,
    // then a price that changed under you, then a trial you still have days
    // to stop.
    final due = active.where((s) => s.isDueSoon).toList()..sort(byUrgency);
    if (due.isNotEmpty) {
      notices.add(Notice(
        id: 'due:${(due.map((s) => s.id).toList()..sort()).join(',')}',
        kind: NoticeKind.dueThisWeek,
        subscriptions: due,
        total: due.fold(0.0, (sum, s) => sum + s.amount),
      ));
    }

    // Only increases. A subscription that got cheaper is not news you need.
    for (final sub in active.where((s) => s.hasPriceChange && s.priceIncreased)) {
      notices.add(Notice(
        // The amount is part of the id, so a second rise on the same
        // subscription is a second notice rather than one you already read.
        id: 'price:${sub.id}:${sub.amount}',
        kind: NoticeKind.priceRise,
        subscriptions: [sub],
      ));
    }

    final ending = trials.where((t) => (t.isDueSoon || t.isOverdue) && !t.isExpired).toList()
      ..sort((a, b) => a.trialEndsAt.compareTo(b.trialEndsAt));
    if (ending.isNotEmpty) {
      notices.add(Notice(
        id: 'trials:${(ending.map((t) => t.id).toList()..sort()).join(',')}',
        kind: NoticeKind.trialsEnding,
        trials: ending,
      ));
    }

    // Last, and after every live notice. A trial that already ended is the
    // least urgent thing on the page by definition.
    //
    // Bounded rather than forever: after a month the detector has had a full
    // billing cycle to find the charge, and a reminder still being mentioned
    // past that is clutter rather than information.
    for (final trial in trials.where((t) => t.isExpired && t.daysUntilEnd >= -_mentionForDays)) {
      notices.add(Notice(
        id: 'converted:${trial.id}',
        kind: NoticeKind.trialMayHaveConverted,
        trials: [trial],
      ));
    }

    return Notices(notices);
  }

  /// How long after a trial ends the quiet mention stays under the bell.
  static const _mentionForDays = 30;

  final List<Notice> items;

  bool get isEmpty => items.isEmpty;

  /// What the badge shows. Read notices stay on the page — they are still
  /// true, and a charge you have seen coming is still coming — but they stop
  /// asking for attention.
  int unreadCount(Set<String> read) => items.where((n) => !read.contains(n.id)).length;
}
