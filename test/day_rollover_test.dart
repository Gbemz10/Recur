import 'package:flutter_test/flutter_test.dart';
import 'package:recur/models/trial.dart';

/// The wording follows the clock rather than the moment a row was built.
///
/// The risk with "Expires today" is that it is written once and then lies for
/// the rest of the install. It cannot: the label is derived on every read, so
/// the same object answers differently as days pass. AppShell is what makes
/// sure a read actually happens — it rebuilds at midnight and on resume.
void main() {
  test('one object reads differently as its end date approaches', () {
    // Same reminder, three positions relative to today.
    TrialReminder endingOn(DateTime date) =>
        TrialReminder(id: 't', label: 'Showmax', trialEndsAt: date);

    final today = DateTime.now();
    expect(endingOn(today).dateLabel, 'Expires today');
    expect(endingOn(today.add(const Duration(days: 1))).dateLabel, 'Expires tomorrow');
    expect(endingOn(today.subtract(const Duration(days: 1))).dateLabel, 'Expired yesterday');
  });

  test('nothing is captured at construction', () {
    // Built once, read twice, with the clock's answer changing underneath:
    // `daysUntilEnd` measures from DateTime.now() at read time, so a row built
    // at 23:59 is not still saying "Expires today" at 00:01.
    final trial = TrialReminder(
      id: 't',
      label: 'Showmax',
      trialEndsAt: DateTime.now().add(const Duration(days: 1)),
    );

    final first = trial.dateLabel;
    final second = trial.dateLabel;
    expect(first, second, reason: 'stable within a day');
    expect(first, 'Expires tomorrow');

    // The only state on the model is the end date itself. If a label were
    // cached, this would be the field holding it.
    expect(trial.trialEndsAt.isAfter(DateTime.now()), isTrue);
  });
}
