import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_delete_animation.dart';
import 'app_sheet.dart';

/// The "are you sure?" case, which is all of them.
///
/// There was a second, near-identical function for deletions — same sheet,
/// same stacked buttons, a bespoke title and a trash emblem. The only caller
/// left was unlinking a bank, which is not a deletion at all: nothing is
/// destroyed, Recur just stops reading. Once its emblem became the alert, the
/// two were the same function with different defaults, so there is one.
///
/// A sheet from the bottom edge rather than a card in the middle of the
/// screen. The buttons are the whole point of this thing, and at the bottom
/// they are where the thumb already is — a centred dialog puts its answers in
/// the middle of the display and asks the hand to travel to them.
///
/// The question is the title and the consequence is the sentence under it —
/// "Are you sure?" over "We will stop counting MTN in your monthly total",
/// rather than a restatement of the button the user just pressed. The emblem
/// above both is animated for the same reason the delete dialog's is: it takes
/// a beat to resolve, and that beat is the point of asking at all.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  String title = 'Are you sure?',
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await _showAppQuestionSheet<bool>(
    context,
    closeResult: false,
    (context) => _SheetBody(
      emblem: const AppAlertAnimation(size: 88),
      title: title,
      message: message,
      actions: [
        AppButton(
          label: confirmLabel,
          variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
          size: AppButtonSize.lg,
          expand: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.lg,
          expand: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shown after something final has happened.
///
/// The counterpart to [showAppDeleteDialog], and governed by one rule: a toast
/// when the change is reversible and carries an Undo, this when the action is
/// final. Both together would be two pieces of furniture saying the same
/// thing, and an Undo underneath a celebration is a mixed message.
///
/// So this is deliberately rare. Setting a budget cap keeps its snackbar,
/// because it has an Undo and the user is likely mid-flow. This is for the
/// moments where something completed and there is nothing left to reverse.
///
/// One button, because there is no decision left to make. Dismissing is the
/// only thing a person can do here, so it should not look like a choice
/// between two.
Future<void> showAppSuccessDialog(
  BuildContext context, {
  required String title,
  String? message,
  String buttonLabel = 'Done',
}) {
  return _showAppQuestionSheet<void>(
    context,
    (context) => _SheetBody(
      emblem: const AppSuccessAnimation(size: 88),
      title: title,
      message: message,
      actions: [
        AppButton(
          label: buttonLabel,
          size: AppButtonSize.lg,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// The one shape every question in the app is asked in.
///
/// Confirm, delete and success were three near-identical bodies that had
/// drifted apart in padding, radius and button order. They are one shape now,
/// so a change to the shape is one edit rather than three.
///
/// In order: an emblem, the question, the sentence that explains it, and the
/// answers stacked full-width. Stacked rather than side by side because two
/// buttons in a row are each half a phone wide; a column gives each one the
/// full width and puts them in reading order, which is also the order of
/// consequence.
class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.emblem,
    required this.title,
    required this.message,
    required this.actions,
  });

  final Widget emblem;
  final String title;
  final String? message;

  /// Most consequential first. The column reads top to bottom, so the action
  /// the sheet is asking about goes above the way out of it.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Center(child: emblem),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.25,
            color: AppColors.ink(context),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            // Narrower than the buttons under it. A line of body text that
            // runs the full width of a phone is hard to track back to the
            // start of the next one.
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: AppColors.muted(context),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          actions[i],
        ],
      ],
    );
  }
}

/// Opens one of these on the app's own sheet chrome — grabber, corner radius,
/// height cap, safe area — rather than on a second set of flags that would
/// drift from it. Dismissing by drag or barrier returns null, which every
/// caller already reads as "no".
Future<T?> _showAppQuestionSheet<T>(
  BuildContext context,
  WidgetBuilder body, {
  Object? closeResult,
}) {
  return showAppSheet<T>(
    context,
    inset: true,
    showClose: true,
    closeResult: closeResult,
    builder: body,
  );
}
