import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Recur's spending taxonomy. Mirrors the backend's `spending_category`
/// pgEnum one-to-one, lowercase on the wire, so this is a straight
/// `.byName()` lookup exactly like [BillingCycle] and [SubscriptionStatus].
///
/// Eleven buckets is deliberately coarse. Mono's categorisation API returns
/// around thirty and the local rule pass could emit anything; both are mapped
/// down to this list server-side before it ever reaches the app. The test for
/// this list is not accuracy, it is whether a person can hold it in their
/// head and set a budget against it.
enum SpendCategory {
  food,
  transport,
  bills,
  entertainment,
  health,
  shopping,
  transfers,
  savings,
  loans,
  education,
  other,
}

/// Where a category came from. Only [user] is protected from being
/// recomputed on the next sync, which is why the app shows it differently.
enum CategorySource { rule, mono, user }

extension SpendCategoryMeta on SpendCategory {
  String get label => switch (this) {
        SpendCategory.food => 'Food & groceries',
        SpendCategory.transport => 'Transport',
        SpendCategory.bills => 'Bills & utilities',
        SpendCategory.entertainment => 'Entertainment',
        SpendCategory.health => 'Health',
        SpendCategory.shopping => 'Shopping',
        SpendCategory.transfers => 'Transfers & cash',
        SpendCategory.savings => 'Savings & investments',
        SpendCategory.loans => 'Loans',
        SpendCategory.education => 'Education',
        SpendCategory.other => 'Other',
      };

  /// Short form for chips and the compact dashboard row, where the full
  /// label would wrap or truncate.
  String get shortLabel => switch (this) {
        SpendCategory.food => 'Food',
        SpendCategory.transport => 'Transport',
        SpendCategory.bills => 'Bills',
        SpendCategory.entertainment => 'Fun',
        SpendCategory.health => 'Health',
        SpendCategory.shopping => 'Shopping',
        SpendCategory.transfers => 'Transfers',
        SpendCategory.savings => 'Savings',
        SpendCategory.loans => 'Loans',
        SpendCategory.education => 'Education',
        SpendCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        SpendCategory.food => Icons.restaurant_rounded,
        SpendCategory.transport => Icons.directions_car_filled_rounded,
        SpendCategory.bills => Icons.bolt_rounded,
        SpendCategory.entertainment => Icons.play_circle_outline_rounded,
        SpendCategory.health => Icons.favorite_border_rounded,
        SpendCategory.shopping => Icons.shopping_bag_outlined,
        SpendCategory.transfers => Icons.swap_horiz_rounded,
        SpendCategory.savings => Icons.savings_outlined,
        SpendCategory.loans => Icons.account_balance_outlined,
        SpendCategory.education => Icons.school_outlined,
        SpendCategory.other => Icons.more_horiz_rounded,
      };

  /// Light-theme hue for this category.
  ///
  /// These sit in the palette's warm, muted family rather than reaching for
  /// saturated chart primaries, so a breakdown never shouts louder than the
  /// number beside it. Every one clears 4.5:1 against the light surfaces they
  /// render on; the dark variants below are lifted for the same reason
  /// [AppColors.muted] is.
  Color get _light => switch (this) {
        SpendCategory.food => const Color(0xFFB4552F),
        SpendCategory.transport => const Color(0xFF276E70),
        SpendCategory.bills => const Color(0xFF5C7A38),
        SpendCategory.entertainment => const Color(0xFF7A4670),
        SpendCategory.health => const Color(0xFF1F7A57),
        SpendCategory.shopping => const Color(0xFF9A6B15),
        SpendCategory.transfers => const Color(0xFF52606E),
        SpendCategory.savings => AppColors.primary,
        SpendCategory.loans => const Color(0xFF9A3025),
        SpendCategory.education => const Color(0xFF3B558A),
        SpendCategory.other => AppColors.neutral500,
      };

  Color get _dark => switch (this) {
        SpendCategory.food => const Color(0xFFE8916B),
        SpendCategory.transport => const Color(0xFF5FB8B9),
        SpendCategory.bills => const Color(0xFF9CC163),
        SpendCategory.entertainment => const Color(0xFFC48ABA),
        SpendCategory.health => const Color(0xFF4FC795),
        SpendCategory.shopping => const Color(0xFFD9A441),
        SpendCategory.transfers => const Color(0xFF9AA8B6),
        SpendCategory.savings => const Color(0xFF3DBE8B),
        SpendCategory.loans => const Color(0xFFE8897B),
        SpendCategory.education => const Color(0xFF8AA3DB),
        SpendCategory.other => AppColors.neutral400,
      };

  Color color(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  /// Tinted fill for the icon chip behind [icon]. Derived from [color] rather
  /// than hand-picked, so adding a category never means inventing two colours.
  Color tint(BuildContext context) => color(context).withValues(alpha: 0.12);
}

/// One category's spend for a period, and the budget it is measured against.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.spent,
    required this.transactionCount,
    this.monthlyLimit,
  });

  final SpendCategory category;
  final double spent;
  final int transactionCount;

  /// Null when the user has not capped this category. A category with no
  /// budget still shows its spend; it just has nothing to be measured against.
  final double? monthlyLimit;

  bool get hasBudget => monthlyLimit != null && monthlyLimit! > 0;

  /// 0..1+ — deliberately not clamped, because a caller rendering a meter
  /// needs to know it overflowed, not just that it is full.
  double get budgetProgress => hasBudget ? spent / monthlyLimit! : 0;

  bool get isOverBudget => hasBudget && spent > monthlyLimit!;

  /// Matches the 80% threshold the backend warns at, so the app and the
  /// email agree on what "nearly there" means.
  bool get isNearBudget => hasBudget && !isOverBudget && budgetProgress >= 0.8;

  double get remaining => hasBudget ? (monthlyLimit! - spent) : 0;

  factory CategorySpend.fromJson(Map<String, dynamic> json) => CategorySpend(
        category: SpendCategory.values.byName(json['category'] as String),
        spent: (json['spent'] as num?)?.toDouble() ?? 0,
        transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
        monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble(),
      );
}

/// A period's spending, as the breakdown screen and the dashboard row read it.
class SpendingSummary {
  const SpendingSummary({
    required this.period,
    required this.total,
    required this.uncategorizedCount,
    required this.categories,
  });

  /// `YYYY-MM`, in WAT — see the backend's `periodRange` for why the month
  /// boundary is not UTC.
  final String period;
  final double total;

  /// Transactions the categorizer has not reached yet. Reported separately
  /// rather than folded into `other`, so the app can say "still sorting
  /// these" instead of quietly calling them miscellaneous.
  final int uncategorizedCount;

  /// Already sorted by spend, descending, by the backend.
  final List<CategorySpend> categories;

  bool get isEmpty => total == 0 && categories.isEmpty;

  /// The handful the dashboard leads with.
  List<CategorySpend> topCategories([int count = 3]) =>
      categories.where((c) => c.spent > 0).take(count).toList();

  List<CategorySpend> get overBudget => categories.where((c) => c.isOverBudget).toList();

  static const empty = SpendingSummary(
    period: '',
    total: 0,
    uncategorizedCount: 0,
    categories: [],
  );

  factory SpendingSummary.fromJson(Map<String, dynamic> json) => SpendingSummary(
        period: json['period'] as String? ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        uncategorizedCount: (json['uncategorizedCount'] as num?)?.toInt() ?? 0,
        categories: (json['categories'] as List<dynamic>? ?? const [])
            .map((c) => CategorySpend.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// One debit, as shown in the list behind a category.
class SpendTransaction {
  const SpendTransaction({
    required this.id,
    required this.narration,
    required this.amount,
    required this.date,
    this.payee,
    this.category,
    this.source,
  });

  final String id;

  /// The raw bank narration, kept verbatim. Same reasoning as
  /// [ChargeRecord.narration]: it is the string a user recognises their own
  /// statement by, however unreadable it looks.
  final String narration;
  final double amount;
  final DateTime date;

  /// Cleaned-up counterparty, e.g. "Netflix". Null if the backend could not
  /// derive one, in which case the UI falls back to [narration].
  final String? payee;

  /// Null while the categorizer has not reached this row yet.
  final SpendCategory? category;
  final CategorySource? source;

  String get displayName => (payee != null && payee!.isNotEmpty) ? payee! : narration;

  /// True when the user set this category by hand, which the UI marks so a
  /// correction visibly stuck.
  bool get isUserCategorized => source == CategorySource.user;

  factory SpendTransaction.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'] as String?;
    final rawSource = json['categorySource'] as String?;
    return SpendTransaction(
      id: json['id'] as String,
      narration: json['narration'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.parse(json['date'] as String),
      payee: json['payee'] as String?,
      category: rawCategory == null ? null : SpendCategory.values.byName(rawCategory),
      source: rawSource == null ? null : CategorySource.values.byName(rawSource),
    );
  }
}

/// A standing monthly cap on one category.
class Budget {
  const Budget({required this.category, required this.monthlyLimit});

  final SpendCategory category;
  final double monthlyLimit;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        category: SpendCategory.values.byName(json['category'] as String),
        monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble() ?? 0,
      );
}
