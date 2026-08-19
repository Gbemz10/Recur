import 'package:flutter/material.dart';

/// Central color palette for the design system.
///
/// The concept: every Nigerian with a bank account knows the debit alert —
/// abrupt, uppercase, monospaced, always a little alarming. Recur exists to
/// turn that reactive dread into something calm and controllable, so the
/// palette borrows the ledger's confidence (deep naira green, warm paper,
/// ink-dark text) instead of the generic indigo-gradient look most fintech
/// apps default to. Semantic colors stay in the same warm, muted family so
/// nothing in the UI accidentally shouts louder than the number it's next
/// to — except the one accent that's supposed to: `warning`, repointed to
/// a vermilion "alert" tone, is the single loud color in the system, used
/// only where money is genuinely about to move.
class AppColors {
  AppColors._();

  // Brand — deep, confident naira green. Not a neon fintech-teal cliché;
  // muted and a little serious, like ink on a ledger.
  static const Color primary = Color(0xFF0B6E4F);
  static const Color primaryDark = Color(0xFF084F39);
  static const Color primaryLight = Color(0xFFDCF2E7);

  // Neutrals — warm, paper-toned scale (a hint of green undertone, not
  // cool gray) so text and surfaces agree with the paper background.
  static const Color neutral900 = Color(0xFF171A14);
  static const Color neutral800 = Color(0xFF262A22);
  static const Color neutral700 = Color(0xFF3E4238);
  static const Color neutral600 = Color(0xFF5E6255);
  static const Color neutral500 = Color(0xFF83867A);
  static const Color neutral400 = Color(0xFFA8AB9E);
  static const Color neutral300 = Color(0xFFD2D4C9);
  static const Color neutral200 = Color(0xFFE8E9E0);
  static const Color neutral100 = Color(0xFFF2F2EA);
  static const Color neutral50 = Color(0xFFFAF9F4);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF1FAE73);
  static const Color successBg = Color(0xFFE1F5EC);

  /// The one loud color in the system. Used for "this is about to charge"
  /// tension: due-soon badges, the attention strip, confidence meters. A
  /// vermilion nod to the bank alert this app is designed to make obsolete.
  static const Color warning = Color(0xFFE4572E);
  static const Color warningBg = Color(0xFFFBE7DE);

  static const Color danger = Color(0xFFA6291D);
  static const Color dangerBg = Color(0xFFF7E4E1);

  /// The one cool note against an otherwise warm palette — reserved for
  /// purely informational moments so it never competes with the alert
  /// accent above.
  static const Color info = Color(0xFF2C6FA6);
  static const Color infoBg = Color(0xFFE3EDF5);

  // Light theme surfaces — warm paper, not stark white.
  static const Color lightBackground = neutral50;
  static const Color lightSurface = white;
  static const Color lightBorder = neutral200;

  // Dark theme / ink surfaces
  static const Color darkBackground = Color(0xFF10130F);
  static const Color darkSurface = Color(0xFF191D16);
  static const Color darkBorder = Color(0xFF2C3127);

  // Built from `fromSeed` + `copyWith` rather than the raw ColorScheme()
  // constructor — fromSeed fills in every Material 3 role (container
  // colors, surface tints, etc.) with sensible derived values, and we only
  // override the handful of roles our components actually reference. This
  // is more resilient across Flutter SDK versions than hand-listing every
  // required field.
  static ColorScheme get lightScheme => ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        onPrimary: white,
        secondary: neutral700,
        onSecondary: white,
        error: danger,
        onError: white,
        surface: lightSurface,
        onSurface: neutral900,
        surfaceContainerHighest: neutral100,
        outline: lightBorder,
      );

  static ColorScheme get darkScheme => ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: primary,
        onPrimary: white,
        secondary: neutral300,
        onSecondary: neutral900,
        error: const Color(0xFFE8897B),
        onError: neutral900,
        surface: darkSurface,
        onSurface: neutral50,
        surfaceContainerHighest: const Color(0xFF1F241C),
        outline: darkBorder,
      );

  // ---- theme-aware lookups ----
  //
  // Most of the app was originally built referencing `lightBackground` /
  // `neutral900` etc. directly rather than through `Theme.of(context)` —
  // fine when there was only ever one theme, a real problem once dark mode
  // exists. These give every screen a one-word swap (`AppColors.background(context)`
  // instead of `AppColors.lightBackground`) rather than requiring a switch
  // to full Theme-driven styling everywhere at once.
  static bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) => _isDark(context) ? darkBackground : lightBackground;
  static Color surface(BuildContext context) => _isDark(context) ? darkSurface : lightSurface;
  static Color border(BuildContext context) => _isDark(context) ? darkBorder : lightBorder;

  /// High-contrast "ink" — near-black on light backgrounds, near-white on
  /// dark ones. What most hardcoded `neutral900` text-color usages meant.
  static Color ink(BuildContext context) => _isDark(context) ? neutral50 : neutral900;

  /// Secondary "ink" a shade softer — what hardcoded `neutral800` usually
  /// meant.
  static Color inkSoft(BuildContext context) => _isDark(context) ? neutral200 : neutral800;

  /// Tertiary/caption text — help copy, FAQ answers, muted metadata. What
  /// hardcoded `neutral600` usually meant. `neutral600` itself measures a
  /// respectable ~6:1 contrast against the light surfaces it was written
  /// for, but only ~2.7:1 against the dark ones — well under WCAG AA's 4.5:1
  /// floor for normal text, which is what made this text unreadable in dark
  /// mode rather than just "a little dim." `neutral400` clears ~7:1 against
  /// both dark surfaces while still reading as visibly softer than
  /// `ink()`/`inkSoft()`.
  static Color muted(BuildContext context) => _isDark(context) ? neutral400 : neutral600;

  /// The "empty" half of anything that fills up: meter and progress tracks,
  /// skeleton blocks, the disc behind an empty-state icon.
  ///
  /// This existed as a hardcoded `neutral200`/`neutral100` in half a dozen
  /// places, which is the same bug the skeleton shimmer had: both are
  /// near-white, so on a near-black surface a track rendered as a bright bar
  /// with a coloured bar on top of it, reading as two fills rather than one
  /// fill and its remainder.
  static Color track(BuildContext context) => _isDark(context) ? darkBorder : neutral200;

  /// Fill for a row or chip selected in the brand's own hue.
  ///
  /// [primaryLight] is a pale mint that only ever worked on light surfaces.
  /// Used unconditionally it left near-white text sitting on a near-white
  /// fill in dark mode, which is what made the highlighted rows in the
  /// onboarding preview unreadable. The dark value is deep enough for
  /// [ink] to clear 12:1 on it.
  /// Dark counterpart to [successBg]. Same reasoning as [primaryTint]: the
  /// light tint is mixed toward white, which on a dark surface reads as a
  /// bright disc rather than a tint.
  static Color successTint(BuildContext context) =>
      _isDark(context) ? const Color(0xFF14372A) : successBg;

  static Color primaryTint(BuildContext context) =>
      _isDark(context) ? const Color(0xFF14372A) : primaryLight;

  /// Brand green as *text or iconography*, rather than as a fill.
  ///
  /// [primary] is tuned to be read on paper and drops to roughly 2:1 against
  /// dark surfaces, so anything that renders the brand colour as a glyph has
  /// to step up to this on dark. Fills keep using [primary]: a filled badge
  /// carries its own contrast with white on top.
  static Color primaryInk(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3DBE8B) : primary;
}
