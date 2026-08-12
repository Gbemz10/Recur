import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand-level accents used for expressive surfaces (splash, empty-state
/// art, the logo mark). Everyday UI should keep using [AppColors] tokens —
/// these exist for the few moments the product is allowed to be loud.
///
/// The gradient runs forest green into warm brass — verdigris into gilt,
/// the way old currency and ledgers actually age. It reads as "money" from
/// two different angles (green notes, gold coin) without landing on the
/// indigo-to-blue gradient nearly every fintech app already uses.
class RecurBrand {
  RecurBrand._();

  /// Deep ink background for the splash and other expressive dark surfaces.
  /// Same values as the dark theme tokens, referenced directly so the two
  /// never drift apart.
  static const Color ink = AppColors.darkBackground;
  static const Color inkSoft = AppColors.darkSurface;

  /// Brand gradient — forest green through olive into warm brass.
  static const Color gradientStart = AppColors.primary;
  static const Color gradientMid = Color(0xFF6E8F45);
  static const Color gradientEnd = Color(0xFFD9A441);

  /// Bright emerald pop, used sparingly for delight moments that need to
  /// stand apart from the deeper brand green: splash particles, the logo's
  /// node dot, the "already cut" indicator.
  static const Color mint = Color(0xFF2EE6A6);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMid, gradientEnd],
  );

  static const LinearGradient inkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [inkSoft, ink],
  );

  /// Glow colour for the splash halo / focus rings.
  static Color glow(double opacity) =>
      gradientMid.withValues(alpha: opacity.clamp(0.0, 1.0));

  /// Neutral text colours that read correctly on [ink].
  static const Color onInk = Color(0xFFF7F6EF);
  static const Color onInkMuted = Color(0xFFA6AC9C);
}
