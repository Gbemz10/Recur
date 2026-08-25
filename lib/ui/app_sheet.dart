import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The app's one bottom-sheet shell.
///
/// Every sheet used to build its own chrome: the same rounded container, the
/// same `viewInsets` padding, the same guessed corner radius, copied into six
/// files and already drifting apart. None of them had a grabber, so a sheet
/// looked like a screen that had failed to finish loading, and none capped
/// their height, so a long one could run off the top of the display.
///
/// This owns all of that. A caller supplies content and nothing else.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    this.title,
    this.trailing,
    this.inset = false,
    this.showClose = false,
    this.closeResult,
    required this.child,
  });

  /// Optional heading. Sheets that open straight into a form usually want one;
  /// a sheet that is a single list of choices often reads better without.
  final String? title;

  /// Sits opposite the title — a "Save", a count, a clear action.
  final Widget? trailing;

  /// Floats the sheet clear of the screen edges instead of sitting flush in
  /// the corner of the display.
  ///
  /// For the sheets that ask a question rather than hold a form. A form wants
  /// every pixel of width it can get and benefits from being anchored, but a
  /// question is a small object handed to you — the gap around it is what says
  /// the app is still there, waiting, behind it.
  final bool inset;

  /// Adds a close control in the top corner.
  ///
  /// A second way out, for anyone who does not want to drag the sheet away and
  /// does not want to read as far as the Cancel button.
  final bool showClose;

  /// What the close control pops with. Popping is done from this widget's own
  /// context, which is inside the sheet's route — a callback built at the call
  /// site would close whatever was underneath instead.
  final Object? closeResult;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      // Lift above the keyboard rather than letting it cover the field the
      // sheet exists to fill in.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        // Never taller than most of the screen, so the sheet always reads as a
        // layer over the app rather than as a new page.
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        // Insetting happens outside the card, and the safe area does not
        // apply to it: stacking the home indicator's inset on top of the
        // margin left a gap under the sheet three times the one beside it.
        // The margin is the same number on all three sides instead, and the
        // content's own bottom padding is what keeps the last button clear of
        // the indicator.
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: inset
                ? const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md)
                : EdgeInsets.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                // All four corners once it is floating, and rounder than the
                // anchored sheet's.
                //
                // Nested rounded rectangles only look right when the inner
                // radius is the outer one minus the gap between them —
                // otherwise the two curves run at different rates and the
                // corner reads as a mistake. The display corner on the phones
                // this ships to is around 55pt and the margin is 12, so 42
                // puts the card's curve very nearly parallel to the bezel it
                // is sitting inside. At 26 it was fighting it.
                borderRadius: inset
                    ? BorderRadius.circular(42)
                    : const BorderRadius.vertical(top: Radius.circular(26)),
                border: inset
                    ? Border.all(color: AppColors.border(context))
                    : Border(top: BorderSide(color: AppColors.border(context))),
              ),
              child: SafeArea(
                top: false,
                bottom: !inset,
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Grabber(),
                        if (title != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.sm,
                              AppSpacing.xl,
                              AppSpacing.lg,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: AppColors.ink(context),
                                    ),
                                  ),
                                ),
                                if (trailing != null) trailing!,
                              ],
                            ),
                          ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              title == null ? AppSpacing.md : 0,
                              AppSpacing.xl,
                              // The same as the sides once the sheet is floating.
                              // An anchored sheet wants the deeper pad, because
                              // its last row sits near the edge of the display; a
                              // floating one already has a margin down there, and
                              // stacking a deeper pad on top of it put four more
                              // points under the content than beside it — just
                              // enough to read as lopsided.
                              inset ? AppSpacing.xl : AppSpacing.xxl,
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                    if (showClose)
                      Positioned(
                        // Lined up with the content's own right margin rather
                        // than pushed into the corner. At 12 it sat inside the
                        // 42pt corner curve, which reads as a control that
                        // missed its mark; at 20 its right edge agrees with
                        // the buttons below it and the curve stays clear.
                        top: AppSpacing.lg,
                        right: AppSpacing.xl,
                        child: _CloseButton(
                          onPressed: () => Navigator.of(context).pop(closeResult),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small, quiet, and on its own plate so it reads as a control rather than as
/// a stray glyph over the corner of the sheet.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.track(context),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.close_rounded, size: 17, color: AppColors.muted(context)),
        ),
      ),
    );
  }
}

/// The one affordance that tells a person this panel can be dragged away.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.track(context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Opens [builder] inside an [AppSheet]. Use this rather than
/// `showModalBottomSheet` directly, so every sheet in the app shares one set
/// of flags — scroll-controlled, transparent host, and a barrier dark enough
/// to actually separate the sheet from the screen behind it.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  Widget? trailing,
  Color? barrierColor,
  bool inset = false,
  bool showClose = false,
  Object? closeResult,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Overridable, because a sheet opened *from* another sheet must not add a
    // second barrier: two stacked scrims dim the first sheet along with the
    // screen. See the date picker, which opens from inside a form sheet.
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.46),
    builder: (context) => AppSheet(
      title: title,
      trailing: trailing,
      inset: inset,
      showClose: showClose,
      closeResult: closeResult,
      child: builder(context),
    ),
  );
}
