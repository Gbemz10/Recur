import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_dots_loader.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, destructive }

enum AppButtonSize { sm, md, lg }

/// A single button widget that covers every button case in the app via
/// [variant] and [size], instead of five different bespoke button classes.
/// This is the pattern most production design systems use (shadcn/ui,
/// Material 3 `FilledButton` family, etc.) — one component, a small enum
/// surface, consistent behavior (loading/disabled/icon) everywhere.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool expand;

  double get _height => switch (size) { AppButtonSize.sm => 36, AppButtonSize.md => 44, AppButtonSize.lg => 52 };

  double get _fontSize => switch (size) { AppButtonSize.sm => 13, AppButtonSize.md => 14, AppButtonSize.lg => 15 };

  double get _hPad => switch (size) { AppButtonSize.sm => AppSpacing.md, AppButtonSize.md => AppSpacing.lg, AppButtonSize.lg => AppSpacing.xl };

  ({Color bg, Color fg, Color? border, Color? hoverBg}) _colors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (variant) {
      AppButtonVariant.primary => (bg: AppColors.primary, fg: AppColors.white, border: null, hoverBg: AppColors.primaryDark),
      AppButtonVariant.secondary => (bg: scheme.surfaceContainerHighest, fg: scheme.onSurface, border: null, hoverBg: null),
      AppButtonVariant.outline => (bg: Colors.transparent, fg: scheme.onSurface, border: scheme.outline, hoverBg: null),
      AppButtonVariant.ghost => (bg: Colors.transparent, fg: scheme.onSurface, border: null, hoverBg: null),
      AppButtonVariant.destructive => (bg: AppColors.danger, fg: AppColors.white, border: null, hoverBg: null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors(context);
    final disabled = onPressed == null || isLoading;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Loading replaces the label entirely — dots only, no text beside
        // them. A spinner sitting next to "Send me a code" reads as two
        // competing signals; the dots alone say "working" on their own.
        if (isLoading)
          AppDotsLoader(size: _fontSize * 0.5, color: c.fg)
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: c.fg),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              color: c.fg,
              height: 1,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(trailingIcon, size: 18, color: c.fg),
          ],
        ],
      ],
    );

    return SizedBox(
      height: _height,
      width: expand ? double.infinity : null,
      child: Material(
        color: disabled ? c.bg.withValues(alpha: 0.5) : c.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: c.border != null ? BorderSide(color: c.border!) : BorderSide.none,
        ),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _hPad),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
