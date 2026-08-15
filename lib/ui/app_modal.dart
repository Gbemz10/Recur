import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Centered modal dialog with title, body, and an action row. Covers the
/// "confirm this destructive action" / "quick form" cases that make up
/// most real-world dialog usage.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  List<Widget>? actions,
  double width = 420,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xlBR),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              content,
              if (actions != null) ...[
                const SizedBox(height: AppSpacing.xxl),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Convenience wrapper for the extremely common "are you sure?" dialog.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showAppModal<bool>(
    context,
    title: title,
    content: Text(message, style: TextStyle(color: AppColors.muted(context), fontSize: 14, height: 1.5)),
    actions: [
      AppButton(
        label: cancelLabel,
        variant: AppButtonVariant.ghost,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      const SizedBox(width: AppSpacing.sm),
      AppButton(
        label: confirmLabel,
        variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  return result ?? false;
}
