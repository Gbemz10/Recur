import 'package:flutter/foundation.dart';

import '../models/spending.dart';
import 'api_client.dart';

/// Shared, listenable store for the spending breakdown and the budgets it is
/// measured against.
///
/// Summary and budgets live in one store rather than two because they are
/// never useful apart: every budget edit changes what the breakdown renders,
/// and splitting them would mean two stores that have to be kept in step by
/// hand. [CategorySpend] already carries its own `monthlyLimit`, so the
/// summary the server returns is the single shape the UI reads.
///
/// Backed by `GET /spending/summary`, `GET /spending/transactions`,
/// `PATCH /spending/transactions/:id/category`, and `GET|PUT|DELETE /budgets`.
class SpendingStore extends ChangeNotifier {
  SpendingStore() {
    load();
  }

  SpendingSummary _summary = SpendingSummary.empty;

  /// `YYYY-MM`, or null for "whatever the server considers this month".
  /// Kept so a reload after an edit stays on the month being looked at
  /// rather than snapping back to the current one.
  String? _period;

  bool isLoading = true;
  String? error;

  SpendingSummary get summary => _summary;
  String? get period => _period;

  /// True once there is anything at all to show. Distinct from `isLoading`:
  /// a linked bank with no debits this month is a legitimate empty state,
  /// not a failure and not a spinner.
  bool get hasData => _summary.total > 0 || _summary.categories.isNotEmpty;

  Future<void> load({String? period}) async {
    isLoading = true;
    error = null;
    _period = period ?? _period;
    notifyListeners();

    try {
      final query = _period == null ? '' : '?period=$_period';
      final response = await apiClient.get('/spending/summary$query');
      _summary = SpendingSummary.fromJson(response);
      _period = _summary.period.isEmpty ? _period : _summary.period;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      // Same reasoning as SubscriptionStore.load()'s catch: a parse failure
      // (an enum member the server knows and this build does not) throws a
      // plain TypeError, and without this the screen spins forever with no
      // message and no way to retry.
      error = "Couldn't load your spending — try again.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// The transactions behind one category. Deliberately not cached in the
  /// store: this is a drill-down the user opens, reads, and leaves, and
  /// holding every category's list in memory to save one fast request would
  /// mean inventing invalidation rules for data that changes under it.
  Future<List<SpendTransaction>> transactionsFor(SpendCategory? category) async {
    final params = <String>[
      if (_period != null) 'period=$_period',
      if (category != null) 'category=${category.name}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await apiClient.get('/spending/transactions$query');
    final rows = response['transactions'] as List<dynamic>? ?? const [];
    return rows.map((r) => SpendTransaction.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Moves one transaction to a different category, optionally teaching the
  /// backend to do the same for every future charge from that merchant.
  ///
  /// Reloads rather than patching the summary in place: `applyToFuture` can
  /// move an unknown number of historical transactions between categories in
  /// one call, so the server's recount is the only trustworthy answer.
  /// Returns how many rows moved, for the confirmation message.
  Future<int> recategorize(
    SpendTransaction transaction,
    SpendCategory category, {
    bool applyToFuture = false,
  }) async {
    try {
      final response = await apiClient.patch(
        '/spending/transactions/${transaction.id}/category',
        body: {'category': category.name, 'applyToFuture': applyToFuture},
      );
      await load();
      return (response['appliedTo'] as num?)?.toInt() ?? 1;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException("Couldn't change that category — try again.", code: 'CLIENT_ERROR');
    }
  }

  /// Sets or updates a category's monthly cap.
  ///
  /// Optimistic, in the same shape as SubscriptionStore.updateStatus: the
  /// meter moves under the user's thumb, and a rejected write puts the old
  /// limit back and rethrows so the sheet can say why.
  Future<void> setBudget(SpendCategory category, double monthlyLimit) async {
    final previous = _summary;
    _summary = _withLimit(category, monthlyLimit);
    notifyListeners();

    try {
      await apiClient.put('/budgets', body: {
        'category': category.name,
        'monthlyLimit': monthlyLimit,
      });
    } catch (e) {
      _summary = previous;
      notifyListeners();
      if (e is ApiException) rethrow;
      throw ApiException("Couldn't save that budget — try again.", code: 'CLIENT_ERROR');
    }
  }

  Future<void> removeBudget(SpendCategory category) async {
    final previous = _summary;
    _summary = _withLimit(category, null);
    notifyListeners();

    try {
      await apiClient.delete('/budgets/${category.name}');
    } catch (e) {
      _summary = previous;
      notifyListeners();
      if (e is ApiException) rethrow;
      throw ApiException("Couldn't remove that budget — try again.", code: 'CLIENT_ERROR');
    }
  }

  /// Rebuilds the summary with one category's limit swapped, preserving the
  /// server's spend figures. A category the user is budgeting for the first
  /// time has no row yet, so one is synthesised at zero spend rather than
  /// dropping the edit until the next load.
  SpendingSummary _withLimit(SpendCategory category, double? limit) {
    final existing = _summary.categories.where((c) => c.category == category).firstOrNull;
    final updated = CategorySpend(
      category: category,
      spent: existing?.spent ?? 0,
      transactionCount: existing?.transactionCount ?? 0,
      monthlyLimit: limit,
    );

    final categories = [
      for (final c in _summary.categories)
        if (c.category == category) updated else c,
      if (existing == null) updated,
    ]..sort((a, b) => b.spent.compareTo(a.spent));

    return SpendingSummary(
      period: _summary.period,
      total: _summary.total,
      uncategorizedCount: _summary.uncategorizedCount,
      categories: categories,
    );
  }
}
