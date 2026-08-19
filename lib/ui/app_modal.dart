import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

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
    actions: [
      AppButton(
        label: cancelLabel,
        variant: AppButtonVariant.outline,
        expand: true,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      AppButton(
        label: confirmLabel,
        variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
        expand: true,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  return result ?? false;
}
