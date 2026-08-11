import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/recur_brand.dart';
import '../ui/ui.dart';

/// Recur's animated launch sequence.
///
/// The whole thing is choreographed off two controllers:
///   * [_main] runs once, 3.2s, and drives the staged reveal via [Interval]s.
///   * [_ambient] loops forever and drives motion that should never stop
///     while the screen is alive (orbiting rings, drifting particles,
///     the shimmer that sweeps the wordmark).
///
/// Stages, in order:
///   0.00–0.55  ink gradient settles, halo blooms out from centre
///   0.15–0.70  orbit rings draw themselves, sweeping clockwise
///   0.30–0.78  the mark (a recurring-cycle arc) draws stroke-by-stroke
///   0.55–0.85  wordmark letters rise in, staggered, with a blur-to-sharp feel
///   0.72–0.92  tagline fades up
///   0.88–1.00  everything lifts and a circular wipe hands off to the app
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  /// Called once the exit wipe finishes.
  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _main;
  late final AnimationController _ambient;

  static const String _wordmark = 'recur';

  // Stage curves -------------------------------------------------------
  late final Animation<double> _haloBloom;
  late final Animation<double> _ringDraw;
  late final Animation<double> _markDraw;
  late final Animation<double> _markSettle;
  late final Animation<double> _taglineFade;
  late final Animation<double> _liftOff;
  late final Animation<double> _wipe;

  @override
  void initState() {
    super.initState();

    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    Animation<double> stage(double begin, double end, Curve curve) {
      return CurvedAnimation(
        parent: _main,
        curve: Interval(begin, end, curve: curve),
      );
    }

    _haloBloom = stage(0.00, 0.55, Curves.easeOutCubic);
    _ringDraw = stage(0.15, 0.70, Curves.easeOutCubic);
    _markDraw = stage(0.30, 0.78, Curves.easeInOutCubic);
    _markSettle = stage(0.62, 0.88, Curves.easeOutBack);
    _taglineFade = stage(0.72, 0.92, Curves.easeOut);
    _liftOff = stage(0.88, 1.00, Curves.easeInCubic);
    _wipe = stage(0.90, 1.00, Curves.easeInOutCubic);

    _main.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _main.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// Per-letter entrance: each letter is offset slightly later than the last.
  double _letterProgress(int index) {
    const start = 0.55;
    const span = 0.30;
    const step = span / (_wordmark.length + 1);
    final begin = start + step * index;
    final end = (begin + step * 2).clamp(0.0, 1.0);
    return Interval(begin, end, curve: Curves.easeOutCubic)
        .transform(_main.value);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);

    return Scaffold(
      backgroundColor: RecurBrand.ink,
      body: AnimatedBuilder(
        animation: Listenable.merge([_main, _ambient]),
        builder: (context, _) {
          final wipe = _wipe.value;

          return Stack(
            fit: StackFit.expand,
            children: [
              // ---- background: ink gradient + drifting particles ----
              const DecoratedBox(
                decoration: BoxDecoration(gradient: RecurBrand.inkGradient),
              ),
              CustomPaint(
                painter: _ParticleFieldPainter(
                  t: _ambient.value,
                  reveal: _haloBloom.value,
                ),
              ),

              // ---- centre stage ----
              Center(
                child: Transform.translate(
                  offset: Offset(0, -18 - _liftOff.value * 26),
                  child: Transform.scale(
                    scale: 1 + _liftOff.value * 0.12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CustomPaint(
                            painter: _MarkPainter(
                              halo: _haloBloom.value,
                              rings: _ringDraw.value,
                              mark: _markDraw.value,
                              settle: _markSettle.value,
                              orbit: _ambient.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildWordmark(),
                        const SizedBox(height: AppSpacing.md),
                        Opacity(
                          opacity: _taglineFade.value,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - _taglineFade.value)),
                            child: Text(
                              'Every recurring charge, caught.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: RecurBrand.onInkMuted,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ---- exit wipe ----
              if (wipe > 0)
                ClipPath(
                  clipper: _CircleRevealClipper(
                    radius: wipe * diagonal * 0.62,
                  ),
                  child: Container(color: AppColors.lightBackground),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordmark() {
    // Shimmer sweeps across the letters once they've mostly arrived.
    final shimmerPos = (_ambient.value * 2.4) % 2.4 - 0.7;

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          RecurBrand.onInk,
          Colors.white,
          RecurBrand.onInk,
        ],
        stops: [
          (shimmerPos - 0.18).clamp(0.0, 1.0),
          shimmerPos.clamp(0.0, 1.0),
          (shimmerPos + 0.18).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: List.generate(_wordmark.length, (i) {
          final p = _letterProgress(i);
          return Opacity(
            opacity: p,
            child: Transform.translate(
              offset: Offset(0, 34 * (1 - p)),
              child: Transform.scale(
                scale: 0.86 + 0.14 * p,
                child: Text(
                  _wordmark[i],
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Halo + orbit rings + the animated brand mark, all drawn in one pass so
/// they share a coordinate space and stay perfectly concentric.
class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.halo,
    required this.rings,
    required this.mark,
    required this.settle,
    required this.orbit,
  });

  final double halo;
  final double rings;
  final double mark;
  final double settle;
  final double orbit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // ---- halo bloom ----
    if (halo > 0) {
      final haloR = maxR * (0.35 + 0.65 * halo);
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            RecurBrand.glow(0.34 * halo),
            RecurBrand.glow(0.10 * halo),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: haloR));
      canvas.drawCircle(center, haloR, haloPaint);
    }

    // ---- orbit rings: two counter-rotating dashed arcs ----
    if (rings > 0) {
      _drawOrbitRing(
        canvas,
        center,
        radius: maxR * 0.78,
        progress: rings,
        rotation: orbit * 2 * math.pi,
        dashes: 34,
        strokeWidth: 1.4,
        opacity: 0.42,
      );
      _drawOrbitRing(
        canvas,
        center,
        radius: maxR * 0.92,
        progress: Curves.easeOut.transform((rings * 1.15).clamp(0.0, 1.0)),
        rotation: -orbit * 2 * math.pi * 0.6,
        dashes: 52,
        strokeWidth: 1.0,
        opacity: 0.22,
      );

      // A single bright node riding the inner orbit — reads as "a charge
      // coming around again", which is the whole product in one detail.
      final nodeAngle = -math.pi / 2 + orbit * 2 * math.pi;
      final nodeR = maxR * 0.78;
      final node = Offset(
        center.dx + math.cos(nodeAngle) * nodeR,
        center.dy + math.sin(nodeAngle) * nodeR,
      );
      canvas.drawCircle(
        node,
        5.0 * rings,
        Paint()..color = RecurBrand.mint.withValues(alpha: 0.9 * rings),
      );
      canvas.drawCircle(
        node,
        11.0 * rings,
        Paint()..color = RecurBrand.mint.withValues(alpha: 0.18 * rings),
      );
    }

    // ---- the mark itself ----
    if (mark > 0) {
      final markR = maxR * 0.46 * (0.92 + 0.08 * settle);
      final rect = Rect.fromCircle(center: center, radius: markR);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..shader = RecurBrand.brandGradient.createShader(rect);

      // Sweep just under a full turn so the gap reads as an open cycle.
      const startAngle = -math.pi / 2;
      final sweep = 2 * math.pi * 0.82 * mark;
      canvas.drawArc(rect, startAngle, sweep, false, strokePaint);

      // Arrowhead at the leading edge, so the cycle has direction.
      if (mark > 0.55) {
        final headT = ((mark - 0.55) / 0.45).clamp(0.0, 1.0);
        final a = startAngle + sweep;
        final tip = Offset(
          center.dx + math.cos(a) * markR,
          center.dy + math.sin(a) * markR,
        );
        final headPaint = Paint()
          ..color = RecurBrand.gradientEnd.withValues(alpha: headT)
          ..style = PaintingStyle.fill;
        final path = Path();
        const headSize = 15.0;
        for (var i = 0; i < 3; i++) {
          final theta = a + math.pi / 2 + (i * 2 * math.pi / 3);
          final p = Offset(
            tip.dx + math.cos(theta) * headSize * headT,
            tip.dy + math.sin(theta) * headSize * headT,
          );
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(path, headPaint);
      }

      // Inner pulse core.
      final corePulse = 0.5 + 0.5 * math.sin(orbit * 2 * math.pi * 2);
      canvas.drawCircle(
        center,
        (markR * 0.26) * settle.clamp(0.0, 1.0),
        Paint()
          ..color = RecurBrand.gradientMid
              .withValues(alpha: (0.25 + 0.35 * corePulse) * settle.clamp(0.0, 1.0)),
      );
    }
  }

  void _drawOrbitRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double progress,
    required double rotation,
    required int dashes,
    required double strokeWidth,
    required double opacity,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = RecurBrand.gradientMid.withValues(alpha: opacity * progress);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final segment = (2 * math.pi) / dashes;
    final visible = (dashes * progress).floor();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    for (var i = 0; i < visible; i++) {
      canvas.drawArc(rect, i * segment, segment * 0.45, false, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.halo != halo ||
      old.rings != rings ||
      old.mark != mark ||
      old.settle != settle ||
      old.orbit != orbit;
}

/// Slow-drifting specks. Deterministic seed so the field is stable across
/// rebuilds instead of resampling every frame.
class _ParticleFieldPainter extends CustomPainter {
  _ParticleFieldPainter({required this.t, required this.reveal});

  final double t;
  final double reveal;

  static const int _count = 46;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final rnd = math.Random(7);
    final paint = Paint();

    for (var i = 0; i < _count; i++) {
      final baseX = rnd.nextDouble();
      final baseY = rnd.nextDouble();
      final speed = 0.25 + rnd.nextDouble() * 0.9;
      final radius = 0.7 + rnd.nextDouble() * 2.1;
      final phase = rnd.nextDouble();

      // Drift upward and wrap, with a gentle horizontal sway.
      final y = (baseY - (t * speed)) % 1.0;
      final sway = math.sin((t + phase) * 2 * math.pi) * 0.012;
      final x = (baseX + sway) % 1.0;

      // Fade in/out near the vertical edges so nothing pops.
      final edgeFade = math.min(y, 1 - y) * 4;
      final alpha = (0.06 + 0.30 * (1 - baseY)) *
          edgeFade.clamp(0.0, 1.0) *
          reveal;

      paint.color = (i % 6 == 0 ? RecurBrand.mint : RecurBrand.gradientMid)
          .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x * size.width, y * size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter old) =>
      old.t != t || old.reveal != reveal;
}

/// Expanding circular hole punched from the centre — used for the handoff
/// from splash to the first real screen.
class _CircleRevealClipper extends CustomClipper<Path> {
  _CircleRevealClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant _CircleRevealClipper old) =>
      old.radius != radius;
}
