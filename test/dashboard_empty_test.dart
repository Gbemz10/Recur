import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/bank_store.dart';
import 'package:recur/data/notice_read_store.dart';
import 'package:recur/data/profile_store.dart';
import 'package:recur/data/spending_store.dart';
import 'package:recur/data/subscription_store.dart';
import 'package:recur/data/trial_store.dart';
import 'package:recur/screens/dashboard_screen.dart';
import 'package:recur/ui/ui.dart';

import 'support/fake_api.dart';

/// Home before there is anything to count.
///
/// A total of zero is not a total: ₦0 over a gradient built to make a figure
/// feel important is furniture, and it was the only thing on the screen for
/// anyone who skipped linking a bank at signup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubSecureStorage();
    fakeWriteDelay = Duration.zero;
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    required Map<String, Map<String, dynamic>> backend,
  }) async {
    setFakeResponses(backend);
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await HttpOverrides.runZoned(
      () async {
        final subscriptions = SubscriptionStore();
        final trials = TrialStore();
        final profile = ProfileStore();
        final spending = SpendingStore();
        final banks = BankStore();
        final read = NoticeReadStore();
        await tester.pumpAndSettle();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              store: subscriptions,
              trialStore: trials,
              profileStore: profile,
              spendingStore: spending,
              readStore: read,
              bankStore: banks,
              onOpenTab: (_, {int? section}) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
      },
      createHttpClient: (_) => FakeHttpClient(backend),
    );
  }

  testWidgets('with no bank linked, it asks for one instead of showing zero',
      (tester) async {
    await pumpHome(tester, backend: {
      '/subscriptions': {'subscriptions': <dynamic>[]},
      '/trials': {'trialReminders': <dynamic>[]},
      '/banking/accounts': {'banks': <dynamic>[]},
    });

    expect(find.text('Connect a bank to begin'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Link my bank'), findsOneWidget);

    // And none of the furniture a zero total brings with it.
    expect(find.text('TOTAL MONTHLY SUBSCRIPTIONS'), findsNothing);
    expect(find.textContaining('0 active subscriptions'), findsNothing);
  });

  testWidgets('with a bank linked and nothing found, it offers no button',
      (tester) async {
    await pumpHome(tester, backend: {
      '/subscriptions': {'subscriptions': <dynamic>[]},
      '/trials': {'trialReminders': <dynamic>[]},
      // `banks`, and the fields BankingService actually reads — a shape that
      // only looks right is how a fixture passes while the app would not.
      '/banking/accounts': {
        'banks': [
          {
            'id': 'bank_1',
            'bankName': 'GTBank',
            'bankCode': '058',
            'accountNumberMask': '••••1234',
            'status': 'ACTIVE',
          },
        ],
      },
    });

    expect(find.text('Nothing repeating yet'), findsOneWidget);
    // Nothing to press: the next sync is not something the user can hurry,
    // and a button that cannot help is a lie.
    expect(find.widgetWithText(AppButton, 'Link my bank'), findsNothing);
  });
}
