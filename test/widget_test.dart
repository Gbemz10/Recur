// Basic smoke test — confirms the app boots and renders its first frame
// without throwing. The default `flutter create` template that used to be
// here tested a counter demo (`MyApp`) that was never this app; `RecurApp`
// is the real entry point, defined in lib/main.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recur/main.dart';

void main() {
  testWidgets('RecurApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const RecurApp());
    await tester.pump();

    // Doesn't assert on specific screen content — the root flow starts on
    // the splash screen and moves through several async stages (session
    // check, onboarding, etc.), so the only thing worth guaranteeing here
    // is that construction itself doesn't throw.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
