import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Large, heavily blurred colour blobs drifting behind content.
///
/// This exists because a white screen with a small card on it reads as
/// unfinished no matter how good the card is. The aurora gives the
/// composition depth and lets each onboarding slide carry its own colour
/// mood without resorting to a hard coloured background.
///
/// Real gaussian blur via [MaskFilter.blur] — cheaper and softer than
/// stacking translucent gradients, and it survives being scaled up.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({
    super.key,
    required this.t,
    required this.colors,
    this.intensity = 1.0,
  });

  /// 0–1, loops. Drives the drift.
  final double t;

  /// Two or three colours for this slide's mood.
  final List<Color> colors;

  /// Scales overall opacity — used to fade the aurora during page swipes.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(
          t: t,
          colors: colors,
          intensity: intensity.clamp(0.0, 1.0),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.colors,
    required this.intensity,
  });

  final double t;
  final List<Color> colors;
  final double intensity;

  /// Each blob gets its own orbit so they drift independently rather than
  /// moving as one rigid group.
  static const List<_Blob> _blobs = [
    _Blob(cx: 0.26, cy: 0.30, rx: 0.11, ry: 0.07, r: 0.46, speed: 1.0),
    _Blob(cx: 0.76, cy: 0.36, rx: 0.09, ry: 0.10, r: 0.40, speed: -0.72),
    _Blob(cx: 0.52, cy: 0.70, rx: 0.13, ry: 0.06, r: 0.52, speed: 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || colors.isEmpty) return;

    final shortest = math.min(size.width, size.height);

    for (var i = 0; i < _blobs.length; i++) {
      final blob = _blobs[i];
      final color = colors[i % colors.length];
      final angle = t * 2 * math.pi * blob.speed;

      final center = Offset(
        (blob.cx + math.cos(angle) * blob.rx) * size.width,
        (blob.cy + math.sin(angle) * blob.ry) * size.height,
      );

      // Gentle breathing so the blobs never look frozen.
      final breathe = 1 + 0.08 * math.sin(angle * 1.3);
      final radius = shortest * blob.r * breathe;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.30 * intensity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.intensity != intensity || old.colors != colors;
}

class _Blob {
  const _Blob({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.r,
    required this.speed,
  });

  /// Centre of the blob's orbit, as a fraction of the canvas.
  final double cx;
  final double cy;

  /// Orbit radii, as a fraction of the canvas.
  final double rx;
  final double ry;

  /// Blob radius, as a fraction of the canvas's shortest side.
  final double r;

  /// Orbit speed and direction. Negative counter-rotates.
  final double speed;
}
