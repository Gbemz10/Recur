import 'package:flutter/material.dart';

/// Spacing, radius, and elevation tokens.
///
/// Everything is built on a 4px base unit. Using named constants instead of
/// raw numbers (`AppSpacing.md` instead of `16.0`) is what keeps a whole
/// app's rhythm consistent — it also makes it trivial to rescale density
/// later by changing one file.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
  static const double massive = 64;
}

class AppRadius {
  AppRadius._();

  // Slightly tightened from the original scale. Containers that hold
  // information (cards, statements, sheets) read as more "ledger" and
  // less "bubble app" a few points off full-round; controls people tap
  // (buttons, chips, badges) stay at `full` so touch targets still feel
  // inviting. The gap between the two is deliberate, not an oversight.
  static const double sm = 6;
  static const double md = 9;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 999;

  static BorderRadius get smBR => BorderRadius.circular(sm);
  static BorderRadius get mdBR => BorderRadius.circular(md);
  static BorderRadius get lgBR => BorderRadius.circular(lg);
  static BorderRadius get xlBR => BorderRadius.circular(xl);
  static BorderRadius get fullBR => BorderRadius.circular(full);
}

class AppShadows {
  AppShadows._();

  // Soft, low-opacity, multi-layer shadows read as more premium than a
  // single hard drop shadow. Keep blur high and opacity low.
  static List<BoxShadow> get sm => [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
      ];
}
