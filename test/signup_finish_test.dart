import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/screens/choose_name_screen.dart';
import 'package:recur/screens/push_permission_screen.dart';
import 'package:recur/ui/ui.dart';

/// The two screens that close out signup: a name for the greeting, and the
/// notification ask. Neither may block anyone from reaching the app.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('choosing a name', () {
    testWidgets('asks for one, and will not submit an empty one', (tester) async {
      await pump(tester, ChooseNameScreen(onDone: () {}));

      expect(find.text("What's your name?"), findsOneWidget);

      final continueButton = find.widgetWithText(AppButton, 'Continue');
      expect(tester.widget<AppButton>(continueButton).onPressed, isNull);

      // Spaces are not a name.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(continueButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(continueButton).onPressed, isNotNull);
    });

    testWidgets('can be skipped, because a greeting is a courtesy', (tester) async {
      var moved = false;
      await pump(tester, ChooseNameScreen(onDone: () => moved = true));

      await tester.tap(find.widgetWithText(AppButton, 'Skip for now'));
      await tester.pumpAndSettle();

      expect(moved, isTrue, reason: 'skipping moves the flow on, it does not stall it');
    });
  });

  testWidgets('the name screen carries no placeholder or helper text', (tester) async {
    await pump(tester, ChooseNameScreen(onDone: () {}));

    // The label above the field says what it is; a greyed-out example name
    // inside it says the same thing twice and reads as a value already there.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, isNull);

    expect(find.textContaining('This is what Recur will call you'), findsNothing);
  });

  group('the notification ask', () {
    testWidgets('offers both answers, and says where to change it', (tester) async {
      await pump(tester, PushPermissionScreen(onDecided: (_) {}));

      expect(find.text('Turn on notifications'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Not now'), findsOneWidget);
      expect(find.textContaining('change this any time in Settings'), findsOneWidget);

      // The preview shows real Recur alerts rather than a generic bell.
      expect(find.textContaining('MTN charges tomorrow'), findsOneWidget);
      expect(find.textContaining('Showmax trial ends tomorrow'), findsOneWidget);
    });

    testWidgets('reports which answer was given', (tester) async {
      final answers = <bool>[];

      await pump(tester, PushPermissionScreen(onDecided: answers.add));
      await tester.tap(find.widgetWithText(AppButton, 'Not now'));
      await tester.pumpAndSettle();
      expect(answers, [false]);

      await pump(tester, PushPermissionScreen(onDecided: answers.add));
      await tester.tap(find.widgetWithText(AppButton, 'Turn on notifications'));
      await tester.pumpAndSettle();
      expect(answers, [false, true]);
    });
  });
}
