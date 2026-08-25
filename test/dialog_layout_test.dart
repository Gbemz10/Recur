import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/ui/ui.dart';

/// The dialogs are one shape now, and this is the shape.
///
/// Two buttons side by side are each half a phone wide and sit where the thumb
/// already rests. Stacked, each gets the full width and they read in the order
/// of consequence: the action being asked about, then the way out.
void main() {
  Future<void> pumpWith(WidgetTester tester, void Function(BuildContext) open) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Same width, and the first strictly above the second.
  void expectStacked(WidgetTester tester, String top, String bottom) {
    final a = tester.getRect(find.widgetWithText(AppButton, top));
    final b = tester.getRect(find.widgetWithText(AppButton, bottom));
    expect(a.bottom, lessThanOrEqualTo(b.top), reason: '$top should sit above $bottom');
    expect(a.width, closeTo(b.width, 0.5), reason: 'both should be full width');
    expect(a.left, closeTo(b.left, 0.5));
  }

  testWidgets('the confirm dialog asks the question and stacks its answers',
      (tester) async {
    await pumpWith(
      tester,
      (context) => showAppConfirmDialog(
        context,
        message: 'We will stop counting MTN in your monthly total.',
        confirmLabel: 'Mark cancelled',
      ),
    );

    // The title is the question; the sentence under it carries the detail.
    expect(find.text('Are you sure?'), findsOneWidget);
    expect(find.text('We will stop counting MTN in your monthly total.'), findsOneWidget);
    expectStacked(tester, 'Mark cancelled', 'Cancel');
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('a confirm can name the thing instead of asking the generic question',
      (tester) async {
    await pumpWith(
      tester,
      (context) => showAppConfirmDialog(
        context,
        title: 'Unlink GTBank?',
        message: 'Recur stops reading new transactions.',
        confirmLabel: 'Unlink',
        destructive: true,
      ),
    );

    // Which bank is the point when more than one is linked, so this one keeps
    // its own title rather than defaulting to "Are you sure?".
    expect(find.text('Unlink GTBank?'), findsOneWidget);
    expect(find.text('Are you sure?'), findsNothing);
    expectStacked(tester, 'Unlink', 'Cancel');
  });

  testWidgets('the success dialog offers one button, since nothing is being asked',
      (tester) async {
    await pumpWith(
      tester,
      (context) => showAppSuccessDialog(
        context,
        title: 'Account deleted',
        message: 'Your data is on its way out.',
      ),
    );

    expect(find.text('Account deleted'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Done'), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('the floating sheet sits evenly inside the screen', (tester) async {
    // iPhone 15: 393x852 points, with the home indicator's 34pt inset. The
    // inset is the whole reason this needs a test — it is invisible in a
    // default 800x600 harness, and it used to be added underneath the sheet's
    // own margin, which made the gap below three times the gap beside.
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(bottom: 34 * 3, top: 59 * 3);
    addTearDown(tester.view.reset);

    await pumpWith(
      tester,
      (context) => showAppConfirmDialog(context, message: 'Sign out of Recur?'),
    );

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final card = tester
        .renderObjectList<RenderBox>(
          find.descendant(of: find.byType(AppSheet), matching: find.byType(DecoratedBox)),
        )
        .first;
    final rect = card.localToGlobal(Offset.zero) & card.size;

    // The card, clear of three edges by the same margin.
    expect(rect.left, 12);
    expect(screen.width - rect.right, 12);
    expect(screen.height - rect.bottom, 12);

    // The close control lines up with the column it sits above, rather than
    // floating in the corner curve — at a 42pt radius, a control tucked into
    // the corner reads as one that missed its mark.
    final close = tester.getRect(find.byIcon(Icons.close_rounded));
    final confirm = tester.getRect(find.widgetWithText(AppButton, 'Confirm'));
    expect(rect.right - close.right, closeTo(rect.right - confirm.right, 6),
        reason: 'the close button should share the content margin');

    // And the content inside it, clear of the card by the same padding — the
    // two together are what the eye actually reads as even.
    final cancel = tester.getRect(find.widgetWithText(AppButton, 'Cancel'));
    expect(cancel.left, screen.width - cancel.right,
        reason: 'left and right of the button should match');
    expect(screen.height - cancel.bottom, cancel.left,
        reason: 'the gap under the button should match the gap beside it');
  });

  testWidgets('a confirm returns false when dismissed from the corner', (tester) async {
    bool? answer;
    await pumpWith(
      tester,
      (context) async =>
          answer = await showAppConfirmDialog(context, message: 'Sign out of Recur?'),
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });
}
