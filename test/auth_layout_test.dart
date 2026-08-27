import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/screens/auth_screen.dart';
import 'package:recur/ui/ui.dart';

/// The button you are reaching for should not be behind the thing you are
/// typing on.
///
/// This screen manages the keyboard inset itself rather than letting the
/// Scaffold resize, so it is worth pinning: a regression here puts Continue
/// under the keyboard, where the only way to reach it is to dismiss the
/// keyboard first.
void main() {
  Future<void> pumpAuth(WidgetTester tester, {double keyboard = 0}) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(onAuthenticated: ({bool isNewAccount = false}) {}, onBack: () {}),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the email screen asks for one thing', (tester) async {
    await pumpAuth(tester);

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Your email'), findsOneWidget);

    // The way out for someone who is not new, under the field rather than
    // stranded at the bottom of the screen.
    expect(find.textContaining('Already have an account?'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
  });

  testWidgets('Continue sits above the keyboard, not behind it', (tester) async {
    const keyboard = 336.0;
    await pumpAuth(tester, keyboard: keyboard);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final button = tester.getRect(find.widgetWithText(AppButton, 'Continue'));

    expect(button.bottom, lessThanOrEqualTo(screen.height - keyboard),
        reason: 'the whole button should clear the keyboard');
    expect(find.textContaining('By registering'), findsOneWidget,
        reason: 'the terms stay visible with the button that agrees to them');
  });

  testWidgets('signing in swaps the question and asks for a password', (tester) async {
    await pumpAuth(tester);

    await tester.tap(find.textContaining('Already have an account?'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Your password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Sign in'), findsOneWidget);

    // And back again, for anyone who tapped it by mistake.
    expect(find.textContaining('New to Recur?'), findsOneWidget);
  });
}
