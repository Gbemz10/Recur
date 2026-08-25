import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/screens/create_password_screen.dart';
import 'package:recur/ui/ui.dart';

/// The last screen of the sign-up flow, on the same shape as the two before
/// it: a circular back control, one big question, and the button on top of the
/// keyboard rather than behind it.
///
/// The password rules themselves are untouched — the same four lines that
/// tick off as you type.
void main() {
  Future<void> pump(WidgetTester tester, {double keyboard = 0}) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: CreatePasswordScreen(email: 'ada@example.com', isReset: false),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('asks one thing, and keeps the rules underneath', (tester) async {
    await pump(tester);

    expect(find.text('Create your password'), findsOneWidget);
    expect(find.text('Choose a password'), findsOneWidget);

    // The same rules as before, said once instead of stacked in four rows.
    expect(find.textContaining('At least'), findsOneWidget);
    expect(find.textContaining('8 characters'), findsOneWidget);
    expect(find.textContaining('a letter'), findsOneWidget);
    expect(find.textContaining('a number'), findsOneWidget);

    // And no subtitle above the fields — the address was confirmed two
    // screens ago.
    expect(find.textContaining('This is how you will sign in'), findsNothing);

    // And no second box to retype into.
    expect(find.text('Type it again'), findsNothing);
  });

  testWidgets('Done stays out of reach until the rules are met', (tester) async {
    await pump(tester);

    final done = find.widgetWithText(AppButton, 'Done');
    expect(done, findsOneWidget);
    expect(tester.widget<AppButton>(done).onPressed, isNull);

    // One field, and one typing of it — the eye control is what catches a
    // typo now, so there is nothing to confirm against.
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'recur1234');
    await tester.pumpAndSettle();

    expect(tester.widget<AppButton>(done).onPressed, isNotNull);
  });

  testWidgets('each rule strikes itself out as it is met', (tester) async {
    await pump(tester);

    /// The decoration on the span carrying [text], wherever it lives.
    ///
    /// Searched rather than indexed: the strength meter appears as soon as
    /// there is a character in the field, which shifts any positional finder
    /// out from under this.
    TextDecoration? decorationOf(String text) {
      TextDecoration? found;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text == text) found = span.style?.decoration;
          return true;
        });
      }
      return found;
    }

    expect(decorationOf('8 characters'), isNot(TextDecoration.lineThrough));
    expect(decorationOf('a number'), isNot(TextDecoration.lineThrough));

    // Nine letters: long enough, has a letter, still no digit.
    await tester.enterText(find.byType(TextField), 'recurrent');
    await tester.pumpAndSettle();

    expect(decorationOf('8 characters'), TextDecoration.lineThrough);
    expect(decorationOf('a letter'), TextDecoration.lineThrough);
    expect(decorationOf('a number'), isNot(TextDecoration.lineThrough),
        reason: 'no digit typed yet');

    await tester.enterText(find.byType(TextField), 'recurrent1');
    await tester.pumpAndSettle();
    expect(decorationOf('a number'), TextDecoration.lineThrough);
  });

  testWidgets('Done sits above the keyboard, not behind it', (tester) async {
    const keyboard = 336.0;
    await pump(tester, keyboard: keyboard);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final button = tester.getRect(find.widgetWithText(AppButton, 'Done'));
    expect(button.bottom, lessThanOrEqualTo(screen.height - keyboard));
  });
}
