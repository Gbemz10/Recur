import 'package:flutter/material.dart';

import '../data/merchants.dart';

/// How often a detected charge repeats.
///
/// `biweekly` and `irregular` mirror the backend's detection engine (see
/// `NamedCycle`/`Cycle` in recur-backend's detection/service.ts):
/// `biweekly` is a real ~14-day billing cadence that used to fall in the
/// gap between weekly and monthly and get silently dropped; `irregular` is
/// a repeating charge whose interval doesn't match any named cadence at
/// all, surfaced instead of discarded once the pattern is well-established.
enum BillingCycle { weekly, biweekly, monthly, quarterly, yearly, irregular }

extension BillingCycleLabel on BillingCycle {
  String get label => switch (this) {
        BillingCycle.weekly => 'Weekly',
        BillingCycle.biweekly => 'Biweekly',
        BillingCycle.monthly => 'Monthly',
        BillingCycle.quarterly => 'Quarterly',
        BillingCycle.yearly => 'Yearly',
        BillingCycle.irregular => 'Irregular',
      };

  /// Rough number of charges per year — used to normalise spend so a yearly
  /// plan and a monthly plan can be compared on the same axis. `irregular`
  /// has no fixed cadence by definition, so this is just a fallback;
  /// `Subscription.yearlyCost` prefers estimating a real interval from the
  /// subscription's own charge history when there's enough of it.
  int get chargesPerYear => switch (this) {
        BillingCycle.weekly => 52,
        BillingCycle.biweekly => 26,
        BillingCycle.monthly => 12,
        BillingCycle.quarterly => 4,
        BillingCycle.yearly => 1,
        BillingCycle.irregular => 12,
      };
}

/// Where a detected charge currently sits in the user's review flow.
enum SubscriptionStatus {
  /// Detected by the engine, user hasn't confirmed or dismissed it yet.
  unreviewed,

  /// User confirmed this really is a subscription.
  active,

  /// User marked it cancelled (or we detected it stopped charging).
  cancelled,

  /// The detector was wrong: this never was a subscription.
  ///
  /// Distinct from [cancelled], which claims the user ended something they had
  /// signed up for. Filing a false positive there overstated what they had
  /// saved by cancelling, with money they had never committed to spend.
  dismissed,
}

enum SubscriptionCategory {
  streaming,
  telecom,
  software,
  fitness,
  finance,
  other,
}

extension SubscriptionCategoryMeta on SubscriptionCategory {
  String get label => switch (this) {
        SubscriptionCategory.streaming => 'Streaming',
        SubscriptionCategory.telecom => 'Airtime & data',
        SubscriptionCategory.software => 'Apps & software',
        SubscriptionCategory.fitness => 'Fitness',
        SubscriptionCategory.finance => 'Finance',
        SubscriptionCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        SubscriptionCategory.streaming => Icons.play_circle_outline_rounded,
        SubscriptionCategory.telecom => Icons.signal_cellular_alt_rounded,
        SubscriptionCategory.software => Icons.grid_view_rounded,
        SubscriptionCategory.fitness => Icons.fitness_center_rounded,
        SubscriptionCategory.finance => Icons.account_balance_wallet_outlined,
        SubscriptionCategory.other => Icons.receipt_long_outlined,
      };
}

/// A single historical charge that fed the detection engine.
class ChargeRecord {
  const ChargeRecord({
    required this.date,
    required this.amount,
    required this.narration,
  });

  final DateTime date;
  final double amount;

  /// Raw bank narration — deliberately kept, because Nigerian bank
  /// narrations are messy and users recognise their own statements by them.
  final String narration;

  factory ChargeRecord.fromJson(Map<String, dynamic> json) => ChargeRecord(
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        narration: json['narration'] as String? ?? '',
      );
}

class Subscription {
  const Subscription({
    required this.id,
    required this.brand,
    required this.displayName,
    required this.amount,
    required this.cycle,
    required this.nextChargeDate,
    required this.category,
    required this.status,
    required this.confidence,
    required this.charges,
    this.cancellationSteps = const [],
    this.previousAmount,
  });

  final String id;

  /// The brand behind the charge — carries the logo and brand colour.
  final Merchant brand;

  /// What we show the user. Often more specific than the brand name,
  /// e.g. brand "DStv" but plan "DStv Compact".
  final String displayName;

  final double amount;

  /// What this subscription was charging before its most recent price
  /// change, e.g. a Spotify Individual→Family upgrade. Null for the
  /// overwhelming majority of subscriptions, which have never changed
  /// price since Recur started tracking them.
  final double? previousAmount;

  final BillingCycle cycle;
  final DateTime nextChargeDate;
  final SubscriptionCategory category;
  final SubscriptionStatus status;

  /// 0–1 detection confidence. Anything below ~0.6 shouldn't be surfaced
  /// as a firm result — it goes into the "review these" bucket instead.
  final double confidence;

  final List<ChargeRecord> charges;

  Color get accentColor => brand.brandColor;

  /// Backend wire format uses lowercase enum strings (`"monthly"`,
  /// `"streaming"`, `"active"`) that match these Dart enums' member names
  /// one-to-one (see `serializeSubscription` in recur-backend), so this is
  /// a straight `.byName()` lookup rather than a translation table.
  factory Subscription.fromJson(Map<String, dynamic> json) {
    final merchantJson = json['merchant'] as Map<String, dynamic>?;
    final displayName = json['displayName'] as String? ?? 'Unknown charge';
    final charges = json['charges'] as List<dynamic>? ?? const [];

    return Subscription(
      id: json['id'] as String,
      brand:
          merchantJson != null ? Merchant.fromJson(merchantJson) : Merchants.unknown(displayName),
      displayName: displayName,
      amount: (json['amount'] as num).toDouble(),
      previousAmount: (json['previousAmount'] as num?)?.toDouble(),
      cycle: BillingCycle.values.byName(json['cycle'] as String),
      nextChargeDate: DateTime.parse(json['nextChargeDate'] as String),
      category: SubscriptionCategory.values.byName(json['category'] as String),
      status: SubscriptionStatus.values.byName(json['status'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      charges: charges.map((c) => ChargeRecord.fromJson(c as Map<String, dynamic>)).toList(),
      // Never parsed before this, so every API-sourced subscription fell back
      // to the const [] default and the "How to cancel" section silently did
      // not render. It looked like a merchant with no guidance rather than a
      // field that was never wired up.
      cancellationSteps: (json['cancellationSteps'] as List<dynamic>? ?? const [])
          .map((step) => step as String)
          .toList(),
    );
  }

  /// Plain-language steps for cancelling with this merchant in Nigeria.
  final List<String> cancellationSteps;

  double get yearlyCost {
    // An irregular cadence's real interval can be anywhere from a few
    // weeks to over a year — the enum-level fallback (12/yr) is too rough
    // to trust once there's actual charge history to measure from instead.
    if (cycle == BillingCycle.irregular && charges.length >= 2) {
      final sorted = [...charges]..sort((a, b) => a.date.compareTo(b.date));
      final totalDays = sorted.last.date.difference(sorted.first.date).inDays;
      final gaps = sorted.length - 1;
      if (totalDays > 0 && gaps > 0) {
        final avgIntervalDays = totalDays / gaps;
        return amount * (365 / avgIntervalDays);
      }
    }
    return amount * cycle.chargesPerYear;
  }

  /// Average days between charges, measured from real history where there is
  /// enough of it and falling back to the cycle's nominal length otherwise.
  double get intervalDays {
    if (charges.length >= 2) {
      final sorted = [...charges]..sort((a, b) => a.date.compareTo(b.date));
      final totalDays = sorted.last.date.difference(sorted.first.date).inDays;
      final gaps = sorted.length - 1;
      if (totalDays > 0 && gaps > 0) return totalDays / gaps;
    }
    return 365 / cycle.chargesPerYear;
  }

  /// The most recent charge actually observed on the bank statement.
  ///
  /// Computed rather than trusting position: the API sorts these newest-first
  /// today, but a list whose meaning depends on someone else's ORDER BY is a
  /// silent breakage waiting to happen.
  DateTime? get lastChargeDate {
    if (charges.isEmpty) return null;
    return charges.map((c) => c.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Full cycles that have elapsed since the last observed charge, beyond the
  /// one that was due. 0 means nothing has been missed.
  int get missedCycles {
    final last = lastChargeDate;
    if (last == null) return 0;
    final elapsed = DateTime.now().difference(last).inDays;
    final missed = (elapsed / intervalDays).floor() - 1;
    return missed < 0 ? 0 : missed;
  }

  /// True when this has not charged for well over a full cycle.
  ///
  /// This is the one thing the projected [nextChargeDate] cannot tell you.
  /// The backend's `projectNextChargeDate` walks forward from the last charge
  /// in whole cycles *until it lands in the future*, so a subscription that
  /// stopped charging a year ago still reports a date next week, and keeps
  /// counting toward the monthly total, forever. Measuring from the charges
  /// themselves is the only honest read, and the app already has them.
  ///
  /// The 1.5x threshold absorbs ordinary billing jitter — weekend settlement,
  /// a failed retry that lands a few days late — without flagging a healthy
  /// subscription. Yearly plans are excluded: one missed cycle takes a year to
  /// establish, by which time the number is far too stale to assert anything.
  bool get hasStopped {
    if (cycle == BillingCycle.yearly) return false;
    final last = lastChargeDate;
    if (last == null) return false;
    return DateTime.now().difference(last).inDays > intervalDays * 1.5;
  }

  /// Normalised monthly figure so totals are comparable across cycles.
  double get monthlyEquivalent => yearlyCost / 12;

  int get daysUntilCharge {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      nextChargeDate.year,
      nextChargeDate.month,
      nextChargeDate.day,
    );
    return due.difference(today).inDays;
  }

  /// Out of the running: either the user ended it, or it never was one.
  ///
  /// Exists so call sites stop writing `status != cancelled` and silently
  /// meaning "is live". Adding `dismissed` broke exactly that assumption in
  /// two places, including the calendar, which would have projected charges
  /// for something the user had just told us was not a subscription.
  bool get isArchived =>
      status == SubscriptionStatus.cancelled || status == SubscriptionStatus.dismissed;

  bool get isDueSoon => daysUntilCharge >= 0 && daysUntilCharge <= 7;

  /// True when the projected charge date has passed and nothing has replaced
  /// it. This is **not** a missed payment, and nothing here is owed.
  ///
  /// `nextChargeDate` is a projection the detector writes during a sync, and
  /// `projectNextChargeDate` advances by whole cycles until it lands in the
  /// future — so the date is always ahead of now at the moment it is stored.
  /// A date in the past therefore has exactly one cause: no sync has run since
  /// we predicted it. Two opposite things produce that. Either the charge went
  /// through normally and we have not pulled transactions yet, or it never
  /// happened at all (card declined, subscription quietly ended). The app
  /// cannot tell which, so it must not imply either.
  bool get isAwaitingCharge => daysUntilCharge < 0;

  /// True when Recur has actually observed this subscription's price
  /// change — as opposed to `previousAmount` just being null because no
  /// change has ever happened.
  bool get hasPriceChange => previousAmount != null && previousAmount != amount;

  bool get priceIncreased => hasPriceChange && amount > previousAmount!;

  /// e.g. "+₦600/mo" — the sign carries the meaning, formatting the naira
  /// figure is left to the caller (keeps this model free of a
  /// currency-formatting dependency).
  double get priceDelta => hasPriceChange ? amount - previousAmount! : 0;

  /// Human-readable countdown, e.g. "Charges tomorrow".
  ///
  /// A passed date reads as "Expected 4 Aug" rather than "Overdue". See
  /// [isAwaitingCharge]: the word Overdue asserted a missed bill that the data
  /// cannot support, and did it in alert red on a screen about someone's money.
  String get nextChargeLabel {
    // A stopped subscription outranks any projection, because the projection
    // is the thing that is wrong about it. Said plainly, in the ordinary
    // colour: nothing is going wrong right now, there is just a question
    // worth answering.
    if (hasStopped) return 'No charge since ${_monthYear(lastChargeDate!)}';
    final d = daysUntilCharge;
    if (d < 0) return 'Expected ${_shortDate(nextChargeDate)}';
    if (d == 0) return 'Charges today';
    if (d == 1) return 'Charges tomorrow';
    return 'In $d days';
  }

  static const _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDate(DateTime d) => '${d.day} ${_shortMonths[d.month - 1]}';

  static String _monthYear(DateTime d) => '${_shortMonths[d.month - 1]} ${d.year}';

  /// "Jul 2026" for the most recent observed charge, or null when there is no
  /// history. Exposed so callers can say when it last charged without doing
  /// string surgery on [nextChargeLabel], which is display copy and free to
  /// change wording.
  String? get lastChargeLabel {
    final last = lastChargeDate;
    return last == null ? null : _monthYear(last);
  }

  Subscription copyWith({SubscriptionStatus? status}) => Subscription(
        id: id,
        brand: brand,
        displayName: displayName,
        amount: amount,
        previousAmount: previousAmount,
        cycle: cycle,
        nextChargeDate: nextChargeDate,
        category: category,
        status: status ?? this.status,
        confidence: confidence,
        charges: charges,
        cancellationSteps: cancellationSteps,
      );
}
