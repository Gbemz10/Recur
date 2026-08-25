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
        remindedAt:
            json['remindedAt'] != null ? DateTime.parse(json['remindedAt'] as String) : null,
        dismissedAt:
            json['dismissedAt'] != null ? DateTime.parse(json['dismissedAt'] as String) : null,
      );

  int get daysUntilEnd {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(trialEndsAt.year, trialEndsAt.month, trialEndsAt.day);
    return end.difference(today).inDays;
  }

  bool get isDueSoon => daysUntilEnd >= 0 && daysUntilEnd <= 3;
  bool get isOverdue => daysUntilEnd < 0;

  /// How long a passed reminder stays on the Trials tab.
  ///
  /// Three days of grace, then the reminder has done its job and stops being a
  /// row you have to clear by hand. It used to sit in "Ending soon" for the
  /// life of the install, red and unanswerable, because the app cannot know
  /// whether you cancelled or let it convert.
  static const graceDays = 3;

  /// Past its end date by more than the grace period: off the Trials tab.
  ///
  /// Not deleted. The row stays on the server and Recur keeps watching the
  /// statements for the charge — it just moves from something you are tracking
  /// to something the app mentions quietly under the bell.
  bool get isExpired => daysUntilEnd < -graceDays;

  /// Human-readable countdown, e.g. "Ends tomorrow".
  String get endsLabel {
    final d = daysUntilEnd;
    if (d < 0) return 'Trial may have converted';
    if (d == 0) return 'Ends today';
    if (d == 1) return 'Ends tomorrow';
    return 'Ends in $d days';
  }

  /// The date line on a trial row.
  ///
  /// The three days either side of now get words instead of a date, because
  /// "Expires today" is read at a glance and "Ends 24 Aug" has to be compared
  /// against a calendar first — and those three are the only days where the
  /// answer changes what you would do. Everything further out keeps the date,
  /// which is the more useful form once the answer is "not yet".
  ///
  /// The tense follows the date rather than staying fixed: a trial that has
  /// already ended expired, it does not end.
  String get dateLabel {
    final d = daysUntilEnd;
    if (d == 0) return 'Expires today';
    if (d == 1) return 'Expires tomorrow';
    if (d == -1) return 'Expired yesterday';
    return d < 0 ? 'Expired ${_shortDate(trialEndsAt)}' : 'Ends ${_shortDate(trialEndsAt)}';
  }

  static String _shortDate(DateTime d) {
    const months = [
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
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
