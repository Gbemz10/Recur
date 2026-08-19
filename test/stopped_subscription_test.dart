import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/merchants.dart';
import 'package:recur/models/subscription.dart';

/// The backend's `projectNextChargeDate` walks forward from the last observed
/// charge in whole cycles *until the result is in the future*, and detection
/// re-runs after every sync. So `nextChargeDate` is always ahead of now, which
/// means a subscription that stopped charging a year ago still reports a date
/// next week and keeps counting toward the monthly total.
///
/// These cover the read that catches it, which measures from the charges
/// themselves rather than from the projection.
void main() {
  const brand = Merchant(
    slug: 'netflix',
    name: 'Netflix',
    domain: 'netflix.com',
    brandColor: Color(0xFFE50914),
  );

  Subscription build({
    required BillingCycle cycle,
    required List<int> chargeDaysAgo,
    int nextChargeInDays = 7,
  }) {
    final now = DateTime.now();
    return Subscription(
      id: 'test',
      brand: brand,
      displayName: 'Netflix',
      amount: 7000,
      cycle: cycle,
      // Always in the future, exactly as the backend would have written it.
      nextChargeDate: now.add(Duration(days: nextChargeInDays)),
      category: SubscriptionCategory.streaming,
      status: SubscriptionStatus.active,
      confidence: 0.95,
      charges: [
        for (final d in chargeDaysAgo)
          ChargeRecord(
            date: now.subtract(Duration(days: d)),
            amount: 7000,
            narration: 'NETFLIX.COM NGN CARD DEBIT',
          ),
      ],
    );
  }

  group('hasStopped', () {
    test('is false for a monthly plan charging on schedule', () {
      final sub = build(cycle: BillingCycle.monthly, chargeDaysAgo: [3, 33, 63]);
      expect(sub.hasStopped, isFalse);
      expect(sub.missedCycles, 0);
    });

    test('tolerates ordinary billing jitter a few days past the cycle', () {
      // 34 days on a ~30 day cycle: a weekend settlement, not a dead plan.
      final sub = build(cycle: BillingCycle.monthly, chargeDaysAgo: [34, 64, 94]);
      expect(sub.hasStopped, isFalse);
    });

    test('catches a plan that has not charged in a year, despite a future date', () {
      final sub = build(
        cycle: BillingCycle.monthly,
        chargeDaysAgo: [365, 395, 425],
        nextChargeInDays: 12,
      );
      // The projection still claims a charge next week...
      expect(sub.daysUntilCharge, greaterThan(0));
      expect(sub.isAwaitingCharge, isFalse);
      // ...but no money has actually moved in a year.
      expect(sub.hasStopped, isTrue);
      expect(sub.missedCycles, greaterThanOrEqualTo(11));
    });

    test('catches a weekly plan silent for two months', () {
      final sub = build(cycle: BillingCycle.weekly, chargeDaysAgo: [60, 67, 74]);
      expect(sub.hasStopped, isTrue);
    });

    test('never fires for yearly, where one missed cycle takes a year to prove', () {
      final sub = build(cycle: BillingCycle.yearly, chargeDaysAgo: [800, 1165]);
      expect(sub.hasStopped, isFalse);
    });

    test('stays quiet when there is no charge history to measure', () {
      final sub = build(cycle: BillingCycle.monthly, chargeDaysAgo: []);
      expect(sub.hasStopped, isFalse);
      expect(sub.missedCycles, 0);
    });

    test('measures irregular cadence from its own history, not the 12/yr fallback', () {
      // Roughly quarterly in practice. Two extra weeks is not a stoppage.
      final sub = build(cycle: BillingCycle.irregular, chargeDaysAgo: [104, 194, 284]);
      expect(sub.hasStopped, isFalse);

      final dead = build(cycle: BillingCycle.irregular, chargeDaysAgo: [400, 490, 580]);
      expect(dead.hasStopped, isTrue);
    });

    test('does not depend on charges arriving newest-first', () {
      final ascending = build(cycle: BillingCycle.monthly, chargeDaysAgo: [63, 33, 3]);
      expect(ascending.lastChargeDate, isNotNull);
      expect(ascending.hasStopped, isFalse);
    });
  });
}
