import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/recur_brand.dart';
import '../ui/ui.dart';

/// Recur's brand mark: an open cycle with a leading arrowhead and a single
/// node riding the ring.
///
/// It's the same shape the splash screen draws, held still. That matters —
/// a launch animation that resolves into a mark the user then sees on every
/// screen is what makes a logo feel earned rather than decorative. A generic
/// icon dropped in a rounded square is a placeholder, not an identity.
///
/// The meaning is literal: the gap says the cycle is still open, the
/// arrowhead gives it direction, and the node is a charge coming back around.
///
/// Drawn rather than shipped as an asset so it stays crisp at any size and
/// can be recoloured for dark surfaces without a second file.
class RecurLogo extends StatelessWidget {
  const RecurLogo({
    super.key,
    this.size = 36,
    this.onDark = false,
    this.showNode = false,
  });

  final double size;

  /// Renders in solid white for use on the brand gradient or ink.
  final bool onDark;

  /// The mint dot. Off by default — reads as a stray mark rather than a
  /// deliberate accent at header sizes. Worth dropping below ~20px too,
  /// where it turns to mush.
  final bool showNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RecurLogoPainter(
          onDark: onDark,
          showNode: showNode && size >= 20,
        ),
      ),
    );
  }
}

class _RecurLogoPainter extends CustomPainter {
  _RecurLogoPainter({required this.onDark, required this.showNode});

  final bool onDark;
  final bool showNode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave room for the arrowhead, which extends past the stroke.
    final radius = size.width * 0.34;
    final stroke = size.width * 0.155;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (onDark) {
      arcPaint.color = Colors.white;
    } else {
      arcPaint.shader = RecurBrand.brandGradient.createShader(rect);
    }

    // Start at the top, sweep clockwise, stop short so the cycle reads open.
    const startAngle = -math.pi / 2 + 0.30;
    const sweep = 2 * math.pi * 0.78;
    canvas.drawArc(rect, startAngle, sweep, false, arcPaint);

    // Arrowhead at the leading tip, rotated to sit tangent to the circle.
    const tipAngle = startAngle + sweep;
    final tip = Offset(
      center.dx + math.cos(tipAngle) * radius,
      center.dy + math.sin(tipAngle) * radius,
    );
    final headSize = size.width * 0.19;
    final tangent = tipAngle + math.pi / 2;

    final head = Path();
    for (var i = 0; i < 3; i++) {
      final theta = tangent + (i * 2 * math.pi / 3);
      final p = Offset(
        tip.dx + math.cos(theta) * headSize,
        tip.dy + math.sin(theta) * headSize,
      );
      i == 0 ? head.moveTo(p.dx, p.dy) : head.lineTo(p.dx, p.dy);
    }
    head.close();

    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.fill
        ..color = onDark ? Colors.white : RecurBrand.gradientEnd,
    );

    // The node — a charge coming back around.
    if (showNode) {
      const nodeAngle = startAngle - 0.42;
      final node = Offset(
        center.dx + math.cos(nodeAngle) * radius,
        center.dy + math.sin(nodeAngle) * radius,
      );
      canvas.drawCircle(
        node,
        stroke * 0.62,
        Paint()..color = onDark ? Colors.white : RecurBrand.mint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecurLogoPainter old) =>
      old.onDark != onDark || old.showNode != showNode;
}

/// Mark plus wordmark, for headers and auth screens.
class RecurWordmark extends StatelessWidget {
  const RecurWordmark({
    super.key,
    this.markSize = 34,
    this.fontSize = 24,
    this.onDark = false,
  });

  final double markSize;
  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RecurLogo(size: markSize, onDark: onDark),
        SizedBox(width: markSize * 0.28),
        Text(
          'recur',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -fontSize * 0.045,
            height: 1.0,
            color: onDark ? Colors.white : AppColors.neutral900,
          ),
        ),
      ],
    );
  }
}
