import 'package:flutter/material.dart';

import '../models/subscription.dart';

/// Stand-in data for UI work. Swap for the real detection API response
/// once the backend is wired up — the shape here mirrors what the
/// recurring-charge engine is expected to return.
class MockData {
  MockData._();

  static DateTime _inDays(int days) =>
      DateTime.now().add(Duration(days: days));

  static List<ChargeRecord> _history({
    required double amount,
    required String narration,
    int months = 5,
  }) {
    final now = DateTime.now();
    return List.generate(months, (i) {
      final d = DateTime(now.year, now.month - i, 14);
      return ChargeRecord(date: d, amount: amount, narration: narration);
    });
  }

  static final List<Subscription> subscriptions = [
    Subscription(
      id: 'netflix',
      merchant: 'Netflix',
      amount: 7000,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(3),
      category: SubscriptionCategory.streaming,
      status: SubscriptionStatus.active,
      confidence: 0.98,
      accentColor: const Color(0xFFE50914),
      charges: _history(amount: 7000, narration: 'NETFLIX.COM NGN CARD DEBIT'),
      cancellationSteps: [
        'Open the Netflix app or netflix.com and sign in.',
        'Go to Account, then Membership & Billing.',
        'Tap Cancel Membership and confirm.',
        'You keep access until the end of the current billing period.',
      ],
    ),
    Subscription(
      id: 'dstv',
      merchant: 'DStv Compact',
      amount: 19000,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(6),
      category: SubscriptionCategory.streaming,
      status: SubscriptionStatus.active,
      confidence: 0.96,
      accentColor: const Color(0xFF0072CE),
      charges: _history(amount: 19000, narration: 'MULTICHOICE NIG DSTV SUB'),
      cancellationSteps: [
        'Dial *288# from the phone number linked to your DStv account.',
        'Select Manage Subscription, then Cancel Auto-renew.',
        'Alternatively use the MyDStv app under Manage Account.',
      ],
    ),
    Subscription(
      id: 'spotify',
      merchant: 'Spotify Premium',
      amount: 1300,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(11),
      category: SubscriptionCategory.streaming,
      status: SubscriptionStatus.active,
      confidence: 0.94,
      accentColor: const Color(0xFF1DB954),
      charges: _history(amount: 1300, narration: 'SPOTIFY P17A9C NGN'),
      cancellationSteps: [
        'Go to spotify.com/account in a browser (not the app).',
        'Select Manage your plan, then Change plan.',
        'Scroll to Spotify Free and choose Cancel Premium.',
      ],
    ),
    Subscription(
      id: 'mtn-data',
      merchant: 'MTN Data Plan',
      amount: 10000,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(1),
      category: SubscriptionCategory.telecom,
      status: SubscriptionStatus.active,
      confidence: 0.91,
      accentColor: const Color(0xFFFFCB05),
      charges: _history(amount: 10000, narration: 'MTNNG DATA AUTORENEW'),
      cancellationSteps: [
        'Dial *312# and select Manage Auto-renewal.',
        'Choose the active data plan and select Turn off auto-renew.',
        'You can also do this in the MyMTN app under Data.',
      ],
    ),
    Subscription(
      id: 'chatgpt',
      merchant: 'OpenAI ChatGPT',
      amount: 32000,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(9),
      category: SubscriptionCategory.software,
      status: SubscriptionStatus.active,
      confidence: 0.89,
      accentColor: const Color(0xFF10A37F),
      charges: _history(amount: 32000, narration: 'OPENAI *CHATGPT USD'),
      cancellationSteps: [
        'Open ChatGPT and click your profile, then Settings.',
        'Go to Subscription, then Manage my subscription.',
        'Select Cancel plan and confirm.',
      ],
    ),
    Subscription(
      id: 'canva',
      merchant: 'Canva Pro',
      amount: 64000,
      cycle: BillingCycle.yearly,
      nextChargeDate: _inDays(41),
      category: SubscriptionCategory.software,
      status: SubscriptionStatus.active,
      confidence: 0.87,
      accentColor: const Color(0xFF7D2AE8),
      charges: _history(
        amount: 64000,
        narration: 'CANVA* I05LM2 SYDNEY AU',
        months: 2,
      ),
      cancellationSteps: [
        'Open Canva and go to Account settings, then Billing & plans.',
        'Select your Canva Pro plan, then Cancel subscription.',
      ],
    ),
    Subscription(
      id: 'gym',
      merchant: 'i-Fitness Gym',
      amount: 25000,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(17),
      category: SubscriptionCategory.fitness,
      status: SubscriptionStatus.unreviewed,
      confidence: 0.72,
      accentColor: const Color(0xFFEF6C00),
      charges: _history(amount: 25000, narration: 'IFITNESS LEKKI POS'),
      cancellationSteps: [
        'Visit your registered branch, or email support@ifitness.com.ng.',
        'Request cancellation at least 7 days before your renewal date.',
      ],
    ),
    Subscription(
      id: 'showmax',
      merchant: 'Showmax',
      amount: 3500,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(22),
      category: SubscriptionCategory.streaming,
      status: SubscriptionStatus.unreviewed,
      confidence: 0.66,
      accentColor: const Color(0xFFE10098),
      charges: _history(
        amount: 3500,
        narration: 'SHOWMAX NG RECURRING',
        months: 3,
      ),
      cancellationSteps: [
        'Sign in at showmax.com and open My account.',
        'Select Manage subscription, then Cancel.',
      ],
    ),
    Subscription(
      id: 'apple-icloud',
      merchant: 'Apple iCloud',
      amount: 1100,
      cycle: BillingCycle.monthly,
      nextChargeDate: _inDays(14),
      category: SubscriptionCategory.software,
      status: SubscriptionStatus.cancelled,
      confidence: 0.93,
      accentColor: const Color(0xFF555555),
      charges: _history(amount: 1100, narration: 'APPLE.COM/BILL ITUNES'),
      cancellationSteps: [
        'Open Settings, tap your name, then Subscriptions.',
        'Select iCloud+ and tap Cancel subscription.',
      ],
    ),
  ];

  static List<Subscription> get active => subscriptions
      .where((s) => s.status == SubscriptionStatus.active)
      .toList();

  static List<Subscription> get unreviewed => subscriptions
      .where((s) => s.status == SubscriptionStatus.unreviewed)
      .toList();

  static List<Subscription> get cancelled => subscriptions
      .where((s) => s.status == SubscriptionStatus.cancelled)
      .toList();

  /// Total normalised monthly spend across confirmed subscriptions.
  static double get monthlyTotal =>
      active.fold(0, (sum, s) => sum + s.monthlyEquivalent);

  static double get yearlyTotal =>
      active.fold(0, (sum, s) => sum + s.yearlyCost);

  /// What the user has already stopped paying — the "we caught this" number.
  static double get monthlySaved =>
      cancelled.fold(0, (sum, s) => sum + s.monthlyEquivalent);

  static List<Subscription> get dueSoon {
    final list = active.where((s) => s.isDueSoon).toList()
      ..sort((a, b) => a.daysUntilCharge.compareTo(b.daysUntilCharge));
    return list;
  }

  static const List<String> supportedBanks = [
    'Access Bank',
    'GTBank',
    'Zenith Bank',
    'First Bank',
    'UBA',
    'Kuda',
    'Opay',
    'Moniepoint',
    'Sterling Bank',
    'Fidelity Bank',
    'Union Bank',
    'Wema / ALAT',
  ];
}

/// Formats a naira amount the way Nigerian users expect to read it.
String formatNaira(double amount, {bool decimals = false}) {
  final rounded = decimals ? amount : amount.roundToDouble();
  final parts = rounded.toStringAsFixed(decimals ? 2 : 0).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final formatted = buffer.toString();
  return decimals ? '₦$formatted.${parts.last}' : '₦$formatted';
}
