import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// A fine dot grid used as background texture.
///
/// Chosen over grain/noise because it's geometric, which suits a product
/// about repeating cycles, and because it's drawn rather than sampled —
/// no asset, no HTTP request, crisp at any density.
///
/// The important part is the mask. Every guide on background patterns lands
/// on the same warning: a background that fights your copy tanks
/// readability. So the grid fades out vertically well before the text
/// block, and sits at an opacity low enough to read as paper texture rather
/// than as a pattern anyone consciously notices.
class DotGrid extends StatelessWidget {
  const DotGrid({
    super.key,
    this.spacing = 24,
    this.dotRadius = 1.1,
    this.opacity = 0.07,
    this.fadeStart = 0.05,
    this.fadeEnd = 0.62,
    this.offset = Offset.zero,
  });

  final double spacing;
  final double dotRadius;

  /// Peak alpha, at [fadeStart].
  final double opacity;

  /// Fraction of height where the grid is at full strength.
  final double fadeStart;

  /// Fraction of height where it has fully disappeared. Keep this above
  /// wherever the copy begins.
  final double fadeEnd;

  /// Shifts the grid — used to parallax it against the rest of the screen.
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DotGridPainter(
          spacing: spacing,
          dotRadius: dotRadius,
          opacity: opacity,
          fadeStart: fadeStart,
          fadeEnd: fadeEnd,
          offset: offset,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({
    required this.spacing,
    required this.dotRadius,
    required this.opacity,
    required this.fadeStart,
    required this.fadeEnd,
    required this.offset,
  });

  final double spacing;
  final double dotRadius;
  final double opacity;
  final double fadeStart;
  final double fadeEnd;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || spacing <= 0) return;

    final paint = Paint();
    final startY = size.height * fadeStart;
    final endY = size.height * fadeEnd;
    final span = (endY - startY).abs() < 1 ? 1.0 : endY - startY;

    // Start a row/column before zero so the grid doesn't visibly begin at
    // the edge when offset is applied.
    final dx = offset.dx % spacing;
    final dy = offset.dy % spacing;

    for (var y = -spacing + dy; y < size.height + spacing; y += spacing) {
      // Alpha falls off with depth; below fadeEnd nothing is drawn at all.
      final t = ((y - startY) / span).clamp(0.0, 1.0);
      final alpha = opacity * (1 - t);
      if (alpha <= 0.002) continue;

      paint.color = AppColors.neutral900.withValues(alpha: alpha);

      for (var x = -spacing + dx; x < size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) =>
      old.spacing != spacing ||
      old.dotRadius != dotRadius ||
      old.opacity != opacity ||
      old.fadeStart != fadeStart ||
      old.fadeEnd != fadeEnd ||
      old.offset != offset;
}
