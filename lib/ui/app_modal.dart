import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_delete_animation.dart';

/// Centred dialog: the "are you sure?" and "one short question" cases.
///
/// The previous version was a bare [Dialog] with a title, a body, and a row of
/// buttons pushed to the trailing edge. Three problems came with that. Small
/// end-aligned buttons are the hardest target on a phone and put the
/// destructive one under the thumb that is already there. It arrived with
/// Flutter's default dialog fade, which is the same motion as a page, so
/// nothing said "this is a layer you can dismiss". And a wall of text with no
/// visual anchor gave the eye nowhere to land before it had to make a
/// decision.
///
/// So: an optional emblem to name the stakes before the sentence does,
/// full-width actions sized for a thumb, and a short scale-in that reads as
/// something surfacing rather than something navigating.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  List<Widget>? actions,
  IconData? icon,
  bool destructive = false,
  double width = 400,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, __) => _ModalBody(
      title: title,
      message: message,
      content: content,
      actions: actions,
      icon: icon,
      destructive: destructive,
      width: width,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        // Starts near full size. A dialog that scales up from small reads as
        // an object flying in; a few percent reads as one coming into focus.
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ModalBody extends StatelessWidget {
  const _ModalBody({
    required this.title,
    required this.message,
    required this.content,
    required this.actions,
    required this.icon,
    required this.destructive,
    required this.width,
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;
  final bool destructive;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.danger : AppColors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Material(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 23, color: accent),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.25,
                      color: AppColors.ink(context),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message!,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                  if (content != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    content!,
                  ],
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        for (var i = 0; i < actions!.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(child: actions![i]),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "are you sure?" case, which is most of them.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showAppModal<bool>(
    context,
    title: title,
    message: message,
    destructive: destructive,
    // Destructive confirms get an emblem by default: the icon does the work of
    // slowing someone down before they have finished reading the sentence.
    icon: icon ?? (destructive ? Icons.warning_amber_rounded : null),
    // Same rule as the delete dialog: a destructive confirm gives up the
    // filled style, so the heaviest button in the row is never the one you
    // cannot undo. Cancel stays outlined either way.
    actions: [
      AppButton(
        label: cancelLabel,
        variant: AppButtonVariant.outline,
        expand: true,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      AppButton(
        label: confirmLabel,
        variant: destructive ? AppButtonVariant.destructiveOutline : AppButtonVariant.primary,
        expand: true,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  return result ?? false;
}

/// The confirmation before something is actually destroyed.
///
/// Distinct from [showAppConfirmDialog] with `destructive: true`, which covers
/// actions that are merely consequential: marking a subscription cancelled
/// changes a status and can be undone from the same screen. This one is for
/// deletion, where the row stops existing.
///
/// Centred rather than left-aligned, and larger than an ordinary dialog,
/// because the point is to interrupt. The animation is the reason it works: a
/// static icon is read in the same glance as the title, whereas motion takes a
/// beat to resolve, and that beat is the whole feature. It plays once and
/// stops, so it reads as a reaction to what you just tapped rather than as a
/// spinner that never resolves.
Future<bool> showAppDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => _DeleteDialogBody(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class _DeleteDialogBody extends StatelessWidget {
  const _DeleteDialogBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppDeleteAnimation(size: 92),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.25,
                          color: AppColors.ink(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // Both outlined, with colour carrying the difference.
                      // The reference filled the destructive button, which
                      // made the irreversible action the heaviest thing on
                      // screen and put it under the resting thumb. Neither
                      // button being the default is the honest arrangement:
                      // this is a question, and the app should not be leaning
                      // on either answer.
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: confirmLabel,
                              variant: AppButtonVariant.destructiveOutline,
                              size: AppButtonSize.lg,
                              expand: true,
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppButton(
                              label: cancelLabel,
                              variant: AppButtonVariant.outline,
                              size: AppButtonSize.lg,
                              expand: true,
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // A second way out, in the corner the thumb is not resting in.
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.muted(context),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
