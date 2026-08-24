import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/subscription_store.dart';
import 'package:recur/models/subscription.dart';
import 'package:recur/screens/recurring_screen.dart';
import 'package:recur/widgets/subscription_tile.dart';

import 'support/fake_api.dart';

/// Undo is a correction, not an action, and it should not announce itself.
///
/// The Review row's Dismiss put up "X dismissed" with an Undo. Tapping that
/// Undo reversed the status through the same method that had just shown the
/// first message, so the app immediately said "X moved back to Review" —
/// worded and coloured exactly like a fresh action, and carrying its own
/// Undo. Two toasts for one decision, the second of them describing a state
/// the user had just restored themselves.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> subscriptionJson(String status) => {
        'id': 'sub_1',
        'displayName': 'Showmax',
        'amount': 3500,
        'cycle': 'monthly',
        'nextChargeDate': DateTime.now().add(const Duration(days: 15)).toIso8601String(),
        'category': 'streaming',
        'status': status,
        'confidence': 0.9,
        'charges': const [],
      };

  setUp(() {
    stubSecureStorage();
    fakeWriteDelay = Duration.zero;
  });

  /// Pumps the screen against a seeded, unreviewed row.
  Future<SubscriptionStore> pumpScreen(WidgetTester tester) async {
    final store = SubscriptionStore();
    await tester.pumpAndSettle();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RecurringScreen(store: store)),
    ));
    await tester.pumpAndSettle();

    // Review is where a row carries its own actions.
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('undoing a status change reverses it without a second toast',
      (tester) async {
    await HttpOverrides.runZoned(
      () async {
        final store = await pumpScreen(tester);

        await tester.tap(find.text('Not a subscription'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The action itself speaks, once.
        expect(find.text('Showmax dismissed'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        await tester.tap(find.text('Undo'));
        await tester.pump();
        // Past the outgoing animation, and past the point where a second
        // toast would have entered.
        await tester.pump(const Duration(seconds: 1));

        // The reversal does not. Nothing about a move back to Review, and no
        // second Undo to tap in a circle.
        expect(find.byType(SnackBar), findsNothing);
        expect(find.textContaining('moved back to Review'), findsNothing);
        expect(find.text('Undo'), findsNothing);

        // And it actually reversed: the row is back in Review.
        expect(store.byStatus(SubscriptionStatus.unreviewed).length, 1);
        expect(find.text('Not a subscription'), findsOneWidget);

        // showAppSnackbar arms a fallback close timer; let the first toast's
        // run out rather than leaving it pending past the test.
        await tester.pump(const Duration(seconds: 7));
      },
      createHttpClient: (_) => FakeHttpClient({
        '/subscriptions': {
          'subscriptions': [subscriptionJson('unreviewed')]
        },
      }),
    );
  });

  testWidgets('undo lands even when tapped before the request finishes',
      (tester) async {
    await HttpOverrides.runZoned(
      () async {
        fakeWriteDelay = const Duration(seconds: 2);
        final store = await pumpScreen(tester);

        await tester.tap(find.text('Not a subscription'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Undo'), findsOneWidget);

        // Tapped a fraction of a second in, with the PATCH still open. This
        // is the ordinary case, not a rare one: the toast is up long before
        // the network answers.
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(store.byStatus(SubscriptionStatus.unreviewed).length, 1);
        expect(find.text('Not a subscription'), findsOneWidget);

        // And it comes back ready to answer again, not spinning on a request
        // the user has already moved past.
        expect(tester.widget<SubscriptionTile>(find.byType(SubscriptionTile)).busy, isFalse);

        await tester.pump(const Duration(seconds: 8));
      },
      createHttpClient: (_) => FakeHttpClient({
        '/subscriptions': {
          'subscriptions': [subscriptionJson('unreviewed')]
        },
      }),
    );
  });
}

