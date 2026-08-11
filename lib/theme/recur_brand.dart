import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand-level accents used for expressive surfaces (splash, hero cards,
/// empty-state art). Everyday UI should keep using [AppColors] tokens —
/// these exist for the few moments the product is allowed to be loud.
class RecurBrand {
  RecurBrand._();

  /// Deep ink background the splash and hero cards sit on.
  static const Color ink = Color(0xFF0B0A1F);
  static const Color inkSoft = Color(0xFF17153A);

  /// Brand gradient — violet into a cooler electric blue.
  static const Color gradientStart = Color(0xFF6D5DF6);
  static const Color gradientMid = Color(0xFF7B6BFF);
  static const Color gradientEnd = Color(0xFF3FC7F4);

  /// Accent used sparingly for "money saved / caught" moments.
  static const Color mint = Color(0xFF3DDC97);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
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
  static const Color onInk = Color(0xFFF6F5FF);
  static const Color onInkMuted = Color(0xFF9E9CC4);
}
