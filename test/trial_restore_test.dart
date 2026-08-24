import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/trial_store.dart';
import 'package:recur/screens/trial_reminders_screen.dart';
import 'package:recur/ui/ui.dart';

import 'support/fake_api.dart';

/// Undoing a delete should put the row back, not reload the tab.
///
/// `restore` used to PATCH and then `load()`, which flipped `isLoading` and
/// refetched every reminder to return a row the app was still holding. On
/// screen that read as the app starting over: the list blinked into three
/// skeleton tiles and back, and the day-rings re-ran their animation from
/// zero, for one undo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> trialJson(String id, String label, int endsInDays) => {
        'id': id,
        'label': label,
        'trialEndsAt': DateTime.now().add(Duration(days: endsInDays)).toIso8601String(),
      };

  Map<String, Map<String, dynamic>> seed() => {
        '/trials': {
          'trialReminders': [
            trialJson('trial_1', 'Canva Pro', 9),
            trialJson('trial_2', 'Audiomack Premium', 24),
          ],
        },
      };

  setUp(() {
    stubSecureStorage();
    fakeWriteDelay = Duration.zero;
  });

  testWidgets('undoing a delete restores the row without reloading the tab',
      (tester) async {
    await HttpOverrides.runZoned(
      () async {
        // Slow writes, so anything that waits on the network to redraw is
        // caught rather than hidden by an instant response.
        fakeWriteDelay = const Duration(seconds: 2);

        final store = TrialStore();
        await tester.pumpAndSettle();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: TrialRemindersScreen(store: store)),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Audiomack Premium'), findsOneWidget);

        // The × on the second row.
        await tester.tap(find.byIcon(Icons.close_rounded).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Audiomack Premium'), findsNothing);
        expect(find.text('Undo'), findsOneWidget);

        await tester.tap(find.text('Undo'));
        await tester.pump();

        // Back on the next frame, from what the app already had — no waiting
        // on the network, and nothing else on the tab disturbed.
        expect(store.isLoading, isFalse);
        expect(find.byType(AppSkeletonListTile), findsNothing);
        expect(find.text('Audiomack Premium'), findsOneWidget);
        expect(find.text('Canva Pro'), findsOneWidget);

        // Still no reload once the request lands, and no second toast.
        await tester.pump(const Duration(seconds: 3));
        expect(store.isLoading, isFalse);
        expect(find.byType(AppSkeletonListTile), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(store.all.where((t) => t.label == 'Audiomack Premium'), hasLength(1));

        await tester.pump(const Duration(seconds: 8));
      },
      createHttpClient: (_) => FakeHttpClient(seed()),
    );
  });
}
