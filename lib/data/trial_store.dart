import 'package:flutter/foundation.dart';

import '../models/trial.dart';
import 'api_client.dart';

/// Shared, listenable store for manually-entered trial reminders — mirrors
/// [SubscriptionStore]'s shape so screens that already know that pattern
/// don't have to learn a new one for this feature.
///
/// Backed by `GET /trials` / `POST /trials` / `PATCH /trials/:id/dismiss`
/// on the Node backend.
class TrialStore extends ChangeNotifier {
  TrialStore() : _trialReminders = [] {
    load();
  }

  List<TrialReminder> _trialReminders;

  bool isLoading = true;
  String? error;

  List<TrialReminder> get all => List.unmodifiable(_trialReminders);

  /// Sorted soonest-first — the dashboard only ever wants to lead with
  /// whichever trial is closest to converting.
  List<TrialReminder> get upcoming {
    final list = [..._trialReminders]..sort((a, b) => a.trialEndsAt.compareTo(b.trialEndsAt));
    return list;
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await apiClient.get('/trials');
      final rows = response['trialReminders'] as List<dynamic>? ?? const [];
      _trialReminders =
          rows.map((row) => TrialReminder.fromJson(row as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      // See SubscriptionStore.load()'s equivalent catch for why a plain
      // parse failure needs its own message — otherwise it's a spinner
      // that never resolves into either data or a visible error.
      error = "Couldn't load your trial reminders — try again.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a reminder optimistically with a temporary local id, then swaps
  /// it for the real server row once the request completes. Rethrows on
  /// failure (after rolling the optimistic entry back) so the calling form
  /// can show its own error rather than silently losing the entry.
  Future<void> addTrialReminder({
    required String label,
    required DateTime trialEndsAt,
    String? merchantSlug,
  }) async {
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = TrialReminder(
      id: tempId,
      label: label,
      trialEndsAt: trialEndsAt,
      merchantSlug: merchantSlug,
    );
    _trialReminders = [..._trialReminders, optimistic];
    notifyListeners();

    try {
      final response = await apiClient.post(
        '/trials',
        body: {
          'label': label,
          'trialEndsAt': trialEndsAt.toUtc().toIso8601String(),
          if (merchantSlug != null) 'merchantSlug': merchantSlug,
        },
      );
      final created = TrialReminder.fromJson(response['trialReminder'] as Map<String, dynamic>);
      final i = _trialReminders.indexWhere((t) => t.id == tempId);
      if (i != -1) _trialReminders[i] = created;
      notifyListeners();
    } catch (e) {
      _trialReminders = _trialReminders.where((t) => t.id != tempId).toList();
      notifyListeners();
      if (e is ApiException) rethrow;
      throw ApiException("Couldn't add that reminder — try again.", code: 'CLIENT_ERROR');
    }
  }

  /// Removes a reminder from view immediately and reverts if the backend
  /// rejects the dismiss — same optimistic-then-revert shape as
  /// [SubscriptionStore.updateStatus].
  Future<void> dismiss(TrialReminder trial) async {
    final previous = [..._trialReminders];
    _trialReminders = _trialReminders.where((t) => t.id != trial.id).toList();
    notifyListeners();

    try {
      await apiClient.patch('/trials/${trial.id}/dismiss');
    } catch (e) {
      _trialReminders = previous;
      notifyListeners();
      if (e is ApiException) rethrow;
      throw ApiException("Couldn't dismiss that reminder — try again.", code: 'CLIENT_ERROR');
    }
  }
}
