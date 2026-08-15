import 'package:flutter/material.dart';

import '../data/merchants.dart';

/// How often a detected charge repeats.
enum BillingCycle { weekly, monthly, quarterly, yearly }

extension BillingCycleLabel on BillingCycle {
  String get label => switch (this) {
        BillingCycle.weekly => 'Weekly',
        BillingCycle.monthly => 'Monthly',
        BillingCycle.quarterly => 'Quarterly',
        BillingCycle.yearly => 'Yearly',
      };

  /// Rough number of charges per year — used to normalise spend so a yearly
  /// plan and a monthly plan can be compared on the same axis.
  int get chargesPerYear => switch (this) {
        BillingCycle.weekly => 52,
        BillingCycle.monthly => 12,
        BillingCycle.quarterly => 4,
        BillingCycle.yearly => 1,
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
      brand: merchantJson != null ? Merchant.fromJson(merchantJson) : Merchants.unknown(displayName),
      displayName: displayName,
      amount: (json['amount'] as num).toDouble(),
      previousAmount: (json['previousAmount'] as num?)?.toDouble(),
      cycle: BillingCycle.values.byName(json['cycle'] as String),
      nextChargeDate: DateTime.parse(json['nextChargeDate'] as String),
      category: SubscriptionCategory.values.byName(json['category'] as String),
      status: SubscriptionStatus.values.byName(json['status'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      charges: charges.map((c) => ChargeRecord.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  /// Plain-language steps for cancelling with this merchant in Nigeria.
  final List<String> cancellationSteps;

  double get yearlyCost => amount * cycle.chargesPerYear;

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

  bool get isDueSoon => daysUntilCharge >= 0 && daysUntilCharge <= 7;

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
  String get nextChargeLabel {
    final d = daysUntilCharge;
    if (d < 0) return 'Overdue';
    if (d == 0) return 'Charges today';
    if (d == 1) return 'Charges tomorrow';
    return 'In $d days';
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
