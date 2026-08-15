import 'package:flutter/foundation.dart';

import '../models/subscription.dart';
import 'api_client.dart';

/// Single in-memory source of truth for subscription state, shared across
/// every screen that reads or changes it.
///
/// Before this existed, the dashboard held its own private copy of the
/// subscription list and mutated it locally. Confirming something out of
/// Review only ever updated what the Home tab showed — Calendar and
/// Settings kept reading straight from the static mock data, so a
/// subscription could be "Active" on one tab and stuck on "Review" on
/// another. One shared, listenable store fixes that at the root: every
/// screen reads and writes the same list, and rebuilds when it changes.
///
/// Backed by `GET /subscriptions` / `PATCH /subscriptions/:id/status` on
/// the Node backend — every screen depends on this interface, not on the
/// network calls directly, so the API is the only thing that changed here.
class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore() : _subscriptions = [] {
    load();
  }

  List<Subscription> _subscriptions;

  /// True while the initial (or a manually triggered) load is in flight.
  /// Screens can show a spinner/empty-state distinction instead of reading
  /// an empty list as "no subscriptions" while it's actually just loading.
  bool isLoading = true;

  /// Set when [load] fails — e.g. no network, or an expired session.
  /// Cleared on the next successful load.
  String? error;

  List<Subscription> get all => List.unmodifiable(_subscriptions);

  List<Subscription> byStatus(SubscriptionStatus status) =>
      _subscriptions.where((s) => s.status == status).toList();

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await apiClient.get('/subscriptions');
      final rows = response['subscriptions'] as List<dynamic>? ?? const [];
      _subscriptions = rows.map((row) => Subscription.fromJson(row as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      // A malformed response (e.g. an enum value the client doesn't know
      // about yet) throws a plain TypeError from Subscription.fromJson, not
      // an ApiException. Without this, that left `error` null forever — a
      // spinner that spins forever with no path to retry, worse than a
      // network failure that at least surfaces a message.
      error = "Couldn't load your subscriptions — try again.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Updates optimistically (screens feel instant) and reverts if the
  /// backend rejects the change. Rethrows an [ApiException] on failure so a
  /// caller can show its own error message — the revert already happened
  /// either way.
  Future<void> updateStatus(Subscription sub, SubscriptionStatus status) async {
    final i = _subscriptions.indexWhere((s) => s.id == sub.id);
    if (i == -1) return;

    final previous = _subscriptions[i];
    _subscriptions[i] = previous.copyWith(status: status);
    notifyListeners();

    try {
      await apiClient.patch('/subscriptions/${sub.id}/status', body: {'status': status.name});
    } catch (e) {
      // Re-find by id rather than reusing `i` — `load()` can legitimately
      // replace `_subscriptions` wholesale while this request is still in
      // flight (e.g. a pull-to-refresh started right after a status tap),
      // and writing back to a stale numeric index into a since-replaced
      // list would either silently corrupt the wrong row or throw a
      // RangeError if the new list is shorter.
      final current = _subscriptions.indexWhere((s) => s.id == sub.id);
      if (current != -1) _subscriptions[current] = previous;
      notifyListeners();
      if (e is ApiException) rethrow;
      throw ApiException("Couldn't save that change — try again.", code: 'CLIENT_ERROR');
    }
  }
}
