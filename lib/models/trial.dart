/// A manually-entered "remind me before this trial converts" note — the
/// user logs it right after signing up somewhere, before any charge has
/// happened, which is exactly the window the automatic detection engine
/// can't see into (there's no transaction yet for it to match against).
///
/// Backed by `GET /trials` / `POST /trials` / `PATCH /trials/:id/dismiss`
/// on the Node backend (see recur-backend's trials module).
class TrialReminder {
  const TrialReminder({
    required this.id,
    required this.label,
    required this.trialEndsAt,
    this.merchantSlug,
    this.remindedAt,
    this.dismissedAt,
  });

  final String id;

  /// What the user typed, e.g. "Netflix Premium" — shown verbatim since
  /// [merchantSlug] may be null (the merchant isn't in Recur's curated
  /// table yet).
  final String label;

  final String? merchantSlug;
  final DateTime trialEndsAt;
  final DateTime? remindedAt;
  final DateTime? dismissedAt;

  factory TrialReminder.fromJson(Map<String, dynamic> json) => TrialReminder(
        id: json['id'] as String,
        label: json['label'] as String,
        merchantSlug: json['merchantSlug'] as String?,
        trialEndsAt: DateTime.parse(json['trialEndsAt'] as String),
        remindedAt: json['remindedAt'] != null ? DateTime.parse(json['remindedAt'] as String) : null,
        dismissedAt: json['dismissedAt'] != null ? DateTime.parse(json['dismissedAt'] as String) : null,
      );

  int get daysUntilEnd {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(trialEndsAt.year, trialEndsAt.month, trialEndsAt.day);
    return end.difference(today).inDays;
  }

  bool get isDueSoon => daysUntilEnd >= 0 && daysUntilEnd <= 3;
  bool get isOverdue => daysUntilEnd < 0;

  /// Human-readable countdown, e.g. "Ends tomorrow".
  String get endsLabel {
    final d = daysUntilEnd;
    if (d < 0) return 'Trial may have converted';
    if (d == 0) return 'Ends today';
    if (d == 1) return 'Ends tomorrow';
    return 'Ends in $d days';
  }
}
