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
  const AppSheet({super.key, this.title, this.trailing, required this.child});

  /// Optional heading. Sheets that open straight into a form usually want one;
  /// a sheet that is a single list of choices often reads better without.
  final String? title;

  /// Sits opposite the title — a "Save", a count, a clear action.
  final Widget? trailing;

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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: AppColors.border(context))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
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
                      AppSpacing.xxl,
                    ),
                    child: child,
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
      child: builder(context),
    ),
  );
}
