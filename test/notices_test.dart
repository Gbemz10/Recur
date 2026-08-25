import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/notices.dart';
import 'package:recur/data/merchants.dart';
import 'package:recur/models/subscription.dart';
import 'package:recur/models/trial.dart';

/// The bell's badge and the notifications page are the same list counted
/// twice. These pin the rules that decide what is on it, because a badge that
/// promises three and delivers two is worse than no badge.
void main() {
  const brand = Merchant(
    slug: 'netflix',
    name: 'Netflix',
    domain: 'netflix.com',
    brandColor: Color(0xFFE50914),
  );

  Subscription sub({
    required int dueInDays,
    SubscriptionStatus status = SubscriptionStatus.active,
    double amount = 7000,
    double? previousAmount,
  }) {
    return Subscription(
      id: 'sub-$dueInDays-$amount-${previousAmount ?? 0}-${status.name}',
      brand: brand,
      displayName: 'Netflix',
      amount: amount,
      previousAmount: previousAmount,
      cycle: BillingCycle.monthly,
      nextChargeDate: DateTime.now().add(Duration(days: dueInDays)),
      category: SubscriptionCategory.streaming,
      status: status,
      confidence: 0.95,
      charges: const [],
    );
  }

  TrialReminder trial({required int endsInDays, String label = 'Canva Pro'}) => TrialReminder(
        id: 'trial-$endsInDays',
        label: label,
        trialEndsAt: DateTime.now().add(Duration(days: endsInDays)),
      );

  test('nothing to say when nothing is imminent', () {
    final notices = Notices.of(
      subscriptions: [sub(dueInDays: 20), trialFreeSub()],
      trials: [trial(endsInDays: 40)],
    );
    expect(notices.isEmpty, isTrue);
    expect(notices.unreadCount(const {}), 0);
  });

  test('a week of charges is one notice, however many charges it is', () {
    final notices = Notices.of(
      subscriptions: [sub(dueInDays: 1), sub(dueInDays: 2, amount: 3000), sub(dueInDays: 30)],
      trials: const [],
    );

    // Two subscriptions, one card — the page groups them into a single line,
    // and the badge has to promise what the page delivers.
    expect(notices.items, hasLength(1));
    final due = notices.items.single;
    expect(due.kind, NoticeKind.dueThisWeek);
    expect(due.subscriptions, hasLength(2));
    expect(due.total, 10000);

    // Soonest first: the card quotes the first row by name.
    expect(
        due.subscriptions.first.daysUntilCharge, lessThan(due.subscriptions.last.daysUntilCharge));
  });

  test('only price rises count, and only for active rows', () {
    final notices = Notices.of(
      subscriptions: [
        sub(dueInDays: 20, amount: 9000, previousAmount: 7000),
        sub(dueInDays: 21, amount: 5000, previousAmount: 7000), // got cheaper
      ],
      trials: const [],
    );
    expect(notices.items, hasLength(1));
    expect(notices.items.single.kind, NoticeKind.priceRise);
  });

  test('cancelled rows are not news', () {
    final notices = Notices.of(
      subscriptions: [sub(dueInDays: 1, status: SubscriptionStatus.cancelled)],
      trials: const [],
    );
    expect(notices.isEmpty, isTrue);
  });

  test('a trial past its end date still counts, and sorts first', () {
    final notices = Notices.of(
      subscriptions: const [],
      trials: [trial(endsInDays: 2, label: 'Canva Pro'), trial(endsInDays: -1, label: 'Showmax')],
    );
    final ending = notices.items.single;
    expect(ending.kind, NoticeKind.trialsEnding);
    expect(ending.trials, hasLength(2));
    expect(ending.trials.first.label, 'Showmax');
  });

  test('the count is one per card, not one per row behind it', () {
    final notices = Notices.of(
      subscriptions: [
        sub(dueInDays: 1),
        sub(dueInDays: 2, amount: 100),
        sub(dueInDays: 25, amount: 9000, previousAmount: 7000),
      ],
      trials: [trial(endsInDays: 1)],
    );
    // A week of charges, one price rise, the trials: three cards, three.
    expect(notices.unreadCount(const {}), 3);
  });

  test('every price rise is its own card', () {
    // Grouped, the card said "2 prices went up" and then opened one of them.
    final notices = Notices.of(
      subscriptions: [
        sub(dueInDays: 20, amount: 9000, previousAmount: 7000),
        sub(dueInDays: 21, amount: 4000, previousAmount: 1000),
      ],
      trials: const [],
    );
    expect(notices.items, hasLength(2));
    expect(notices.items.every((n) => n.kind == NoticeKind.priceRise), isTrue);
    expect(notices.items.every((n) => n.subscriptions.length == 1), isTrue);
  });

  group('a trial that has already ended', () {
    test('still counts while it is inside the grace period', () {
      final notices = Notices.of(subscriptions: const [], trials: [trial(endsInDays: -2)]);
      expect(notices.items.single.kind, NoticeKind.trialsEnding);
    });

    test('becomes a quiet mention once the reminder expires', () {
      final notices = Notices.of(subscriptions: const [], trials: [trial(endsInDays: -5)]);
      expect(notices.items.single.kind, NoticeKind.trialMayHaveConverted);
    });

    test('sorts below everything still live', () {
      final notices = Notices.of(
        subscriptions: [sub(dueInDays: 1)],
        trials: [trial(endsInDays: -5), trial(endsInDays: 1, label: 'Canva Pro')],
      );
      expect(notices.items.map((n) => n.kind).toList(), [
        NoticeKind.dueThisWeek,
        NoticeKind.trialsEnding,
        NoticeKind.trialMayHaveConverted,
      ]);
    });

    test('stops being mentioned after a full billing cycle', () {
      final notices = Notices.of(subscriptions: const [], trials: [trial(endsInDays: -40)]);
      expect(notices.isEmpty, isTrue);
    });
  });

  group('read state', () {
    test('a read notice stops counting but stays on the page', () {
      final notices = Notices.of(
        subscriptions: [sub(dueInDays: 1)],
        trials: [trial(endsInDays: 1)],
      );
      expect(notices.unreadCount(const {}), 2);

      final read = {notices.items.first.id};
      expect(notices.unreadCount(read), 1);
      expect(notices.items, hasLength(2), reason: 'reading one should not remove it');
    });

    test('an id survives a rebuild, so reading one sticks', () {
      List<Subscription> subs() => [sub(dueInDays: 1), sub(dueInDays: 3, amount: 500)];
      expect(
        Notices.of(subscriptions: subs(), trials: const []).items.single.id,
        Notices.of(subscriptions: subs(), trials: const []).items.single.id,
      );
    });

    test('a new charge in the week is a new notice, not a read one', () {
      final before = Notices.of(subscriptions: [sub(dueInDays: 1)], trials: const []);
      final after = Notices.of(
        subscriptions: [sub(dueInDays: 1), sub(dueInDays: 2, amount: 500)],
        trials: const [],
      );
      expect(after.items.single.id, isNot(before.items.single.id));
      expect(after.unreadCount({before.items.single.id}), 1,
          reason: 'reading last week\'s group must not silence a new charge');
    });

    test('a second rise on the same subscription is a second notice', () {
      final first = Notices.of(
        subscriptions: [sub(dueInDays: 20, amount: 9000, previousAmount: 7000)],
        trials: const [],
      );
      final again = Notices.of(
        subscriptions: [sub(dueInDays: 20, amount: 11000, previousAmount: 9000)],
        trials: const [],
      );
      expect(again.items.single.id, isNot(first.items.single.id));
      expect(again.unreadCount({first.items.single.id}), 1);
    });
  });
}

/// A row that is active but far from charging — present so the empty case is
/// empty because nothing is imminent, not because there is nothing at all.
Subscription trialFreeSub() => Subscription(
      id: 'quiet',
      brand: const Merchant(
          slug: 'spotify', name: 'Spotify', domain: 'spotify.com', brandColor: Color(0xFF1DB954)),
      displayName: 'Spotify',
      amount: 1300,
      cycle: BillingCycle.monthly,
      nextChargeDate: DateTime.now().add(const Duration(days: 25)),
      category: SubscriptionCategory.streaming,
      status: SubscriptionStatus.active,
      confidence: 0.9,
      charges: const [],
    );
