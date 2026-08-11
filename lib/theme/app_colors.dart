import 'package:flutter/material.dart';

/// Central color palette for the design system.
///
/// Brand color is an indigo/violet that reads as modern and trustworthy
/// without being generic "startup blue." Semantic colors (success, warning,
/// danger, info) are tuned to have the same visual weight/saturation as the
/// brand color so nothing in the UI accidentally shouts louder than it should.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6D5DF6); // indigo/violet
  static const Color primaryDark = Color(0xFF5849D6);
  static const Color primaryLight = Color(0xFFECEAFF);

  // Neutrals (warm-neutral gray scale, not pure gray — pairs well with
  // Plus Jakarta Sans' slightly rounded letterforms).
  static const Color neutral900 = Color(0xFF15161A);
  static const Color neutral800 = Color(0xFF23252B);
  static const Color neutral700 = Color(0xFF3A3D46);
  static const Color neutral600 = Color(0xFF5B5F6B);
  static const Color neutral500 = Color(0xFF80838F);
  static const Color neutral400 = Color(0xFFA6A9B4);
  static const Color neutral300 = Color(0xFFD1D3DA);
  static const Color neutral200 = Color(0xFFE7E8ED);
  static const Color neutral100 = Color(0xFFF3F4F7);
  static const Color neutral50 = Color(0xFFFAFAFC);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFE7F8ED);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFDF3E3);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFDEBEB);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFE9F0FE);

  // Light theme surfaces
  static const Color lightBackground = neutral50;
  static const Color lightSurface = white;
  static const Color lightBorder = neutral200;

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF0E0F13);
  static const Color darkSurface = Color(0xFF17181D);
  static const Color darkBorder = Color(0xFF2B2D34);

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
        error: const Color(0xFFF87171),
        onError: neutral900,
        surface: darkSurface,
        onSurface: neutral50,
        surfaceContainerHighest: const Color(0xFF1F2128),
        outline: darkBorder,
      );
}
