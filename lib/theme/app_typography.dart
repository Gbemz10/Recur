import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography scale built on Plus Jakarta Sans.
///
/// Plus Jakarta Sans is a geometric sans with slightly rounded terminals —
/// it reads as friendly but still precise, which is why it works for both
/// marketing surfaces (hero headlines) and dense product UI (tables, forms).
///
/// Stick to three weights across the whole app: 500 (medium) for UI labels
/// and body copy, 600 (semibold) for emphasis and headings, 800 (extrabold)
/// reserved for hero/display text only. Mixing more weights than that is
/// what makes hand-rolled design systems start to feel inconsistent.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color baseColor) {
    final base = GoogleFonts.plusJakartaSansTextTheme();

    TextStyle style({
      required double size,
      required FontWeight weight,
      double? height,
      double? letterSpacing,
      Color? color,
    }) {
      return GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? baseColor,
      );
    }

    return base.copyWith(
      // Display / hero text — extrabold, tight tracking, tight leading.
      displayLarge: style(size: 57, weight: FontWeight.w800, height: 1.1, letterSpacing: -1.5),
      displayMedium: style(size: 45, weight: FontWeight.w800, height: 1.12, letterSpacing: -1),
      displaySmall: style(size: 36, weight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),

      // Section / page headings — semibold.
      headlineLarge: style(size: 32, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.5),
      headlineMedium: style(size: 28, weight: FontWeight.w700, height: 1.22, letterSpacing: -0.3),
      headlineSmall: style(size: 24, weight: FontWeight.w700, height: 1.25),

      // Card titles, list headers.
      titleLarge: style(size: 20, weight: FontWeight.w600, height: 1.3),
      titleMedium: style(size: 16, weight: FontWeight.w600, height: 1.4, letterSpacing: 0.1),
      titleSmall: style(size: 14, weight: FontWeight.w600, height: 1.4, letterSpacing: 0.1),

      // Body copy — medium weight reads better than regular at UI sizes
      // with a geometric sans like this.
      bodyLarge: style(size: 16, weight: FontWeight.w500, height: 1.5),
      bodyMedium: style(size: 14, weight: FontWeight.w500, height: 1.5),
      bodySmall: style(size: 12, weight: FontWeight.w500, height: 1.45),

      // Buttons, chips, form labels, table headers.
      labelLarge: style(size: 14, weight: FontWeight.w600, height: 1.2, letterSpacing: 0.1),
      labelMedium: style(size: 12, weight: FontWeight.w600, height: 1.2, letterSpacing: 0.2),
      labelSmall: style(size: 11, weight: FontWeight.w600, height: 1.2, letterSpacing: 0.3),
    );
  }

  static TextTheme get light => textTheme(AppColors.neutral900);
  static TextTheme get dark => textTheme(AppColors.neutral50);
}
