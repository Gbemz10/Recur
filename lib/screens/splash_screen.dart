import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/recur_brand.dart';
import '../ui/ui.dart';

/// Recur's animated launch sequence, on light.
///
/// Two controllers drive everything:
///   * [_main] runs once, 5.2s, and drives the staged reveal via [Interval]s.
///   * [_ambient] loops forever and drives motion that should never stop
///     while the screen is alive (orbiting rings, drifting particles,
///     the highlight that sweeps the wordmark).
///
/// Stages, in order (3.2s total):
///   0.00–0.28  violet wash blooms out from centre
///   0.06–0.40  orbit rings draw themselves, counter-rotating
///   0.12–0.46  the mark (a recurring-cycle arc) draws stroke-by-stroke
///   0.42–0.68  wordmark letters rise in, staggered
///   0.86–1.00  the whole composition lifts and fades out
///
/// Stages overlap heavily on purpose. Running them end to end would read as
/// a slideshow; overlapping them means the arc is still drawing as the
/// letters start arriving, which is what makes 3.2s feel unhurried rather
/// than rushed.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  /// Called once the exit transition finishes.
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
  late final Animation<double> _wash;
  late final Animation<double> _ringDraw;
  late final Animation<double> _markDraw;
  late final Animation<double> _markSettle;
  late final Animation<double> _exit;

  @override
  void initState() {
    super.initState();

    // Well under five seconds on purpose. WCAG 2.2.2 requires a pause
    // control for auto-starting motion that runs longer than that, and a
    // launch sequence is something people sit through on every single cold
    // start — it should feel confident, not indulgent.
    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    Animation<double> stage(double begin, double end, Curve curve) {
      return CurvedAnimation(
        parent: _main,
        curve: Interval(begin, end, curve: curve),
      );
    }

    _wash = stage(0.00, 0.28, Curves.easeOutCubic);
    _ringDraw = stage(0.06, 0.40, Curves.easeOutCubic);
    // The arc draw is the slowest thing to read, so it gets the tightest
    // curve — it should feel drawn, not laboured.
    _markDraw = stage(0.12, 0.46, Curves.easeOutCubic);
    _markSettle = stage(0.38, 0.60, Curves.easeOutBack);
    // A beat of stillness after the wordmark lands, then out.
    _exit = stage(0.86, 1.00, Curves.easeInCubic);

    _main.forward().whenComplete(widget.onComplete);
  }

  bool _appliedMotionPreference = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With reduce-motion on, don't make the user sit through a launch
    // sequence they've explicitly asked not to see. Hold the finished mark
    // briefly so the app doesn't appear to flash, then move on.
    if (!_appliedMotionPreference &&
        MediaQuery.disableAnimationsOf(context)) {
      _appliedMotionPreference = true;
      _ambient.stop();
      _main.stop();
      _main.value = 0.85;
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _main.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// Per-letter entrance: each letter is offset slightly later than the last.
  double _letterProgress(int index) {
    const start = 0.42;
    const span = 0.26;
    const step = span / (_wordmark.length + 1);
    final begin = start + step * index;
    final end = (begin + step * 2).clamp(0.0, 1.0);
    return Interval(begin, end, curve: Curves.easeOutCubic)
        .transform(_main.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: AnimatedBuilder(
        animation: Listenable.merge([_main, _ambient]),
        builder: (context, _) {
          final exit = _exit.value;

          return Opacity(
            opacity: 1 - exit,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ---- background: soft violet wash + drifting particles ----
                CustomPaint(
                  painter: _BackdropPainter(
                    wash: _wash.value,
                    t: _ambient.value,
                  ),
                ),

                // ---- centre stage ----
                Center(
                  child: Transform.translate(
                    offset: Offset(0, -20 - exit * 30),
                    child: Transform.scale(
                      scale: 1 + exit * 0.06,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 210,
                            height: 210,
                            child: CustomPaint(
                              painter: _MarkPainter(
                                rings: _ringDraw.value,
                                mark: _markDraw.value,
                                settle: _markSettle.value,
                                orbit: _ambient.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildWordmark(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordmark(BuildContext context) {
    // A violet highlight drifts across the letters, so the wordmark never
    // sits completely still while the splash is up.
    final sweep = (_ambient.value * 2.2) % 2.2 - 0.6;
    final base = AppColors.ink(context);

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          base,
          RecurBrand.gradientStart,
          base,
        ],
        stops: [
          (sweep - 0.22).clamp(0.0, 1.0),
          sweep.clamp(0.0, 1.0),
          (sweep + 0.22).clamp(0.0, 1.0),
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
              offset: Offset(0, 38 * (1 - p)),
              child: Transform.scale(
                scale: 0.84 + 0.16 * p,
                child: Text(
                  _wordmark[i],
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1.6,
                    color: Colors.white, // replaced by the ShaderMask
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

/// Soft violet wash plus a slow particle field. Kept deliberately faint —
/// on white, anything stronger reads as dirt rather than atmosphere.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.wash, required this.t});

  final double wash;
  final double t;

  static const int _count = 38;

  @override
  void paint(Canvas canvas, Size size) {
    if (wash <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.42);

    // Radial wash behind the mark.
    final washR = size.width * (0.45 + 0.55 * wash);
    canvas.drawCircle(
      center,
      washR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            RecurBrand.gradientStart.withValues(alpha: 0.13 * wash),
            RecurBrand.gradientEnd.withValues(alpha: 0.05 * wash),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: washR)),
    );

    // Drifting specks, deterministic so the field is stable across rebuilds.
    final rnd = math.Random(11);
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final baseX = rnd.nextDouble();
      final baseY = rnd.nextDouble();
      final speed = 0.2 + rnd.nextDouble() * 0.7;
      final radius = 1.0 + rnd.nextDouble() * 2.4;
      final phase = rnd.nextDouble();

      final y = (baseY - (t * speed)) % 1.0;
      final sway = math.sin((t + phase) * 2 * math.pi) * 0.014;
      final x = (baseX + sway) % 1.0;

      // Fade near the vertical edges so nothing pops in or out.
      final edgeFade = (math.min(y, 1 - y) * 4).clamp(0.0, 1.0);
      final alpha = (0.05 + 0.13 * (1 - baseY)) * edgeFade * wash;

      paint.color = (i % 5 == 0 ? RecurBrand.mint : RecurBrand.gradientStart)
          .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x * size.width, y * size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.wash != wash || old.t != t;
}

/// Orbit rings plus the animated brand mark, drawn in one pass so they
/// share a coordinate space and stay perfectly concentric.
class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.rings,
    required this.mark,
    required this.settle,
    required this.orbit,
  });

  final double rings;
  final double mark;
  final double settle;
  final double orbit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // ---- orbit rings: two counter-rotating dashed arcs ----
    if (rings > 0) {
      _drawOrbitRing(
        canvas,
        center,
        radius: maxR * 0.78,
        progress: rings,
        rotation: orbit * 2 * math.pi,
        dashes: 34,
        strokeWidth: 1.6,
        opacity: 0.30,
      );
      _drawOrbitRing(
        canvas,
        center,
        radius: maxR * 0.93,
        progress: Curves.easeOut.transform((rings * 1.15).clamp(0.0, 1.0)),
        rotation: -orbit * 2 * math.pi * 0.6,
        dashes: 54,
        strokeWidth: 1.1,
        opacity: 0.18,
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
        14.0 * rings,
        Paint()..color = RecurBrand.mint.withValues(alpha: 0.16 * rings),
      );
      canvas.drawCircle(
        node,
        5.5 * rings,
        Paint()..color = RecurBrand.mint.withValues(alpha: 0.95 * rings),
      );
    }

    // ---- the mark itself ----
    if (mark > 0) {
      final markR = maxR * 0.46 * (0.92 + 0.08 * settle);
      final rect = Rect.fromCircle(center: center, radius: markR);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
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
        final path = Path();
        const headSize = 16.0;
        for (var i = 0; i < 3; i++) {
          final theta = a + math.pi / 2 + (i * 2 * math.pi / 3);
          final p = Offset(
            tip.dx + math.cos(theta) * headSize * headT,
            tip.dy + math.sin(theta) * headSize * headT,
          );
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = RecurBrand.gradientEnd.withValues(alpha: headT),
        );
      }

      // Inner pulse core.
      final corePulse = 0.5 + 0.5 * math.sin(orbit * 2 * math.pi * 2);
      final s = settle.clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        (markR * 0.24) * s,
        Paint()
          ..color = RecurBrand.gradientStart
              .withValues(alpha: (0.18 + 0.22 * corePulse) * s),
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
      ..color = RecurBrand.gradientStart.withValues(alpha: opacity * progress);

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
      old.rings != rings ||
      old.mark != mark ||
      old.settle != settle ||
      old.orbit != orbit;
}
