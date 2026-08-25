import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/trial_store.dart';
import 'package:recur/models/trial.dart';

import 'support/fake_api.dart';

/// A reminder should stop being a row you have to clear by hand.
///
/// The Trials tab used to keep an ended trial in "Ending soon" for the life of
/// the install — red, and unanswerable, because the app cannot know whether
/// you cancelled or let it convert. Three days of grace, then it leaves the
/// tab. It is not deleted: the server keeps the row and the detector keeps
/// watching the statements, which is what the quiet notice under the bell
/// says.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubSecureStorage();
    fakeWriteDelay = Duration.zero;
  });

  TrialReminder at(int daysUntilEnd) => TrialReminder(
        id: 'trial$daysUntilEnd',
        label: 'Showmax',
        trialEndsAt: DateTime.now().add(Duration(days: daysUntilEnd)),
      );

  Map<String, dynamic> json(int daysUntilEnd) => {
        'id': 'trial$daysUntilEnd',
        'label': 'Showmax',
        'trialEndsAt': DateTime.now().add(Duration(days: daysUntilEnd)).toIso8601String(),
      };

  test('grace runs for three days past the end date', () {
    expect(at(0).isExpired, isFalse, reason: 'ends today');
    expect(at(-1).isExpired, isFalse);
    expect(at(-3).isExpired, isFalse, reason: 'the third day is still grace');
    expect(at(-4).isExpired, isTrue);
  });

  group('the date line', () {
    test('says the word for the three days that change what you would do', () {
      expect(at(0).dateLabel, 'Expires today');
      expect(at(1).dateLabel, 'Expires tomorrow');
      expect(at(-1).dateLabel, 'Expired yesterday');
    });

    test('keeps the date further out, in the right tense', () {
      final soon = DateTime.now().add(const Duration(days: 9));
      final past = DateTime.now().subtract(const Duration(days: 3));

      expect(
        TrialReminder(id: 'a', label: 'Canva', trialEndsAt: soon).dateLabel,
        'Ends ${soon.day} ${_month(soon)}',
      );
      // A trial that has already ended expired; it does not end.
      expect(
        TrialReminder(id: 'b', label: 'Canva', trialEndsAt: past).dateLabel,
        'Expired ${past.day} ${_month(past)}',
      );
    });
  });

  test('an expired reminder leaves the tab but not the store', () async {
    await HttpOverrides.runZoned(
      () async {
        final store = TrialStore();
        // Let the load settle: the constructor starts it.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // The tab shows what you are still waiting on, soonest first.
        expect(store.upcoming.map((t) => t.id).toList(), ['trial-1', 'trial2']);

        // The row is still there for the notices behind the bell to read.
        expect(store.all, hasLength(3));
      },
      createHttpClient: (_) => FakeHttpClient({
        '/trials': {
          'trialReminders': [json(2), json(-1), json(-9)],
        },
      }),
    );
  });
}


String _month(DateTime d) => const [
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
    ][d.month - 1];
