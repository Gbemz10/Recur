import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography scale built on two deliberately paired faces.
///
/// Plus Jakarta Sans carries every UI chrome, heading, and body-copy role —
/// a geometric sans with slightly rounded terminals that reads as friendly
/// but precise. IBM Plex Mono is the ledger face: every naira figure, date,
/// and bank narration in the app renders in it, tabular figures locked so
/// digits never jitter sideways while a total counts up. That split isn't
/// decoration — it's the app's whole thesis in typographic form. A bank
/// alert renders your money in a fixed-width font because a machine wrote
/// it; Recur borrows that vernacular deliberately, so the one thing this
/// app is about (the number) always looks like a number, not UI copy.
///
/// Stick to three weights in the Sans role across the whole app: 500
/// (medium) for labels and body copy, 600 (semibold) for emphasis and
/// headings, 800 (extrabold) reserved for hero/display text only. Mixing
/// more weights than that is what makes hand-rolled design systems start
/// to feel inconsistent.
class AppTypography {
  AppTypography._();

  /// Google Fonts ships static font files that sometimes omit less common
  /// currency glyphs (₦ among them) — without an explicit fallback list,
  /// Flutter can render that one glyph from a mismatched weight/baseline,
  /// which is what caused the broken-looking ₦ in earlier builds. Every
  /// text style below carries this fallback so the naira sign always
  /// renders from a font that actually has it.
  static const List<String> _glyphFallback = [
    'Roboto',
    'Noto Sans',
    'Noto Sans Symbols',
    'Arial',
  ];

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
      ).copyWith(fontFamilyFallback: _glyphFallback);
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

  /// The money face.
  ///
  /// Amounts used to render in [mono] on the theory that a machine wrote the
  /// number. That reads well at 11px on a statement row and badly at 38px on
  /// a hero card, where a monospace naira total looks like terminal output
  /// rather than money. Plus Jakarta Sans at 700/800 with tabular figures
  /// keeps the alignment that mattered about mono while looking like a
  /// currency figure.
  ///
  /// [mono] keeps the jobs it is genuinely good at: raw bank narrations,
  /// uppercase meta labels, references. Those are machine text and should
  /// still look like it.
  ///
  /// Tabular figures are load-bearing either way. Without them a counting-up
  /// total visibly reflows as digit widths change.
  static TextStyle money({
    required double size,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      // Slightly tighter than the sans default: large figures set at 800 open
      // up more than the same size in text, and money should read as one
      // object rather than a row of separate digits.
      letterSpacing: letterSpacing ?? -size * 0.02,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    ).copyWith(fontFamilyFallback: _glyphFallback);
  }

  /// The ledger face. Raw bank narrations, uppercase meta labels, and
  /// references: text a machine produced and should still look like it.
  /// Tabular figures are load-bearing here too.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    ).copyWith(fontFamilyFallback: _glyphFallback);
  }
}
