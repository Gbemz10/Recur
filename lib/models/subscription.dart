import 'package:flutter/material.dart';

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
}

class Subscription {
  const Subscription({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.cycle,
    required this.nextChargeDate,
    required this.category,
    required this.status,
    required this.confidence,
    required this.accentColor,
    required this.charges,
    this.cancellationSteps = const [],
  });

  final String id;
  final String merchant;
  final double amount;
  final BillingCycle cycle;
  final DateTime nextChargeDate;
  final SubscriptionCategory category;
  final SubscriptionStatus status;

  /// 0–1 detection confidence. Anything below ~0.6 shouldn't be surfaced
  /// as a firm result — it goes into the "review these" bucket instead.
  final double confidence;

  final Color accentColor;
  final List<ChargeRecord> charges;

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

  String get initials {
    final parts =
        merchant.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final single = parts.first;
      return (single.length >= 2 ? single.substring(0, 2) : single)
          .toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Subscription copyWith({SubscriptionStatus? status}) => Subscription(
        id: id,
        merchant: merchant,
        amount: amount,
        cycle: cycle,
        nextChargeDate: nextChargeDate,
        category: category,
        status: status ?? this.status,
        confidence: confidence,
        accentColor: accentColor,
        charges: charges,
        cancellationSteps: cancellationSteps,
      );
}
