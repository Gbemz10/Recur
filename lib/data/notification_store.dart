import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// What the user has asked to be told about.
///
/// Backed by `GET /notifications/preferences` and `PATCH` of the same path.
/// Owned by [SettingsScreen] rather than the shell, because Settings is the
/// only screen that reads these and there is nothing to keep warm elsewhere.
class NotificationStore extends ChangeNotifier {
  NotificationStore() {
    load();
  }

  bool renewalReminders = true;
  bool weeklyDigest = true;
  int reminderLeadDays = 3;

  bool isLoading = true;
  String? error;

  /// True until the first response lands, so Settings can show its rows
  /// disabled rather than briefly showing defaults as if they were the
  /// user's own settings and then snapping to the real ones.
  bool get isInitialLoad => isLoading && error == null && !_loadedOnce;
  bool _loadedOnce = false;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await apiClient.get('/notifications/preferences');
      _apply(response['preferences'] as Map<String, dynamic>?);
      _loadedOnce = true;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load your notification settings';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _apply(Map<String, dynamic>? json) {
    if (json == null) return;
    renewalReminders = json['renewalReminders'] as bool? ?? renewalReminders;
    weeklyDigest = json['weeklyDigest'] as bool? ?? weeklyDigest;
    reminderLeadDays = (json['reminderLeadDays'] as num?)?.toInt() ?? reminderLeadDays;
  }

  /// Applies the change locally first, then persists.
  ///
  /// A switch that waits for a round trip before moving feels broken, and a
  /// preference is cheap to be wrong about for 200ms. If the write fails the
  /// previous values go back exactly as they were and the caller is told, so
  /// the control never ends up showing something the server does not agree
  /// with.
  Future<void> update({
    bool? renewalReminders,
    bool? weeklyDigest,
    int? reminderLeadDays,
  }) async {
    final previous = (
      renewal: this.renewalReminders,
      digest: this.weeklyDigest,
      lead: this.reminderLeadDays,
    );

    if (renewalReminders != null) this.renewalReminders = renewalReminders;
    if (weeklyDigest != null) this.weeklyDigest = weeklyDigest;
    if (reminderLeadDays != null) this.reminderLeadDays = reminderLeadDays;
    error = null;
    notifyListeners();

    try {
      final response = await apiClient.patch(
        '/notifications/preferences',
        body: {
          if (renewalReminders != null) 'renewalReminders': renewalReminders,
          if (weeklyDigest != null) 'weeklyDigest': weeklyDigest,
          if (reminderLeadDays != null) 'reminderLeadDays': reminderLeadDays,
        },
      );
      // Take the server's version rather than assuming ours stuck: the lead
      // is clamped server-side, so what came back may not be what went out.
      _apply(response['preferences'] as Map<String, dynamic>?);
      notifyListeners();
    } catch (e) {
      this.renewalReminders = previous.renewal;
      this.weeklyDigest = previous.digest;
      this.reminderLeadDays = previous.lead;
      notifyListeners();
      rethrow;
    }
  }
}
