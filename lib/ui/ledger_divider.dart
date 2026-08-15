import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A dashed hairline — the tear-line off a receipt or a rule under a
/// statement heading. This is the app's one recurring structural motif,
/// so it's used sparingly and only at boundaries that are genuinely
/// statement-like (under the hero total, between a calendar day and its
/// charges), never as generic decoration between arbitrary sections.
class LedgerDivider extends StatelessWidget {
  const LedgerDivider({
    super.key,
    this.color,
    this.thickness = 1.2,
    this.dashWidth = 4,
    this.gapWidth = 4,
  });

  final Color? color;
  final double thickness;
  final double dashWidth;
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        // neutral300 was hardcoded here — a subtle ~1.5:1 hairline against
        // the light surfaces it was tuned for, but the same fixed color
        // reads as a bright, prominent line against a dark surface instead
        // of a subtle one. AppColors.border(context) already carries an
        // equivalently subtle tone for whichever theme is active.
        painter: _DashPainter(
          color: color ?? AppColors.border(context),
          thickness: thickness,
          dashWidth: dashWidth,
          gapWidth: gapWidth,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({
    required this.color,
    required this.thickness,
    required this.dashWidth,
    required this.gapWidth,
  });

  final Color color;
  final double thickness;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final step = dashWidth + gapWidth;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += step;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.thickness != thickness ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.gapWidth != gapWidth;
}
