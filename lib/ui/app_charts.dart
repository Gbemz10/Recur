import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Charts for the spending and trials screens.
///
/// Hand-drawn with [CustomPainter] rather than pulling in a charting package.
/// Three reasons: the app needs exactly three shapes and a library brings
/// dozens; every charting package has its own theming model that would end up
/// fighting [AppColors] for control of the palette; and these have to animate
/// on the same curve as the rest of the app, which is easier to guarantee
/// when the tween is ours.
///
/// All three take their colours from the caller. None of them invent a
/// palette, so a category's colour is the same in a donut, a bar and a
/// legend without any of them knowing what a category is.

/// One slice of an [AppDonut].
class DonutSlice {
  const DonutSlice({required this.value, required this.color, this.label});

  final double value;
  final Color color;
  final String? label;
}

/// A donut chart with a free centre.
///
/// A donut rather than a pie because the centre is the most valuable space in
/// the shape: it holds the total, which is the number people actually came
/// for. A pie spends that space on ink and then needs a caption underneath to
/// say the same thing.
class AppDonut extends StatelessWidget {
  const AppDonut({
    super.key,
    required this.slices,
    this.size = 200,
    this.thickness = 26,
    this.gapDegrees = 2.2,
    this.center,
    this.highlighted,
  });

  final List<DonutSlice> slices;
  final double size;
  final double thickness;

  /// Angular gap between slices. Small, but enough that two adjacent
  /// categories of similar colour never read as one wedge.
  final double gapDegrees;

  final Widget? center;

  /// Index of the slice to emphasise; every other slice dims. Null means all
  /// slices render at full strength.
  final int? highlighted;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => CustomPaint(
          painter: _DonutPainter(
            slices: slices,
            total: total,
            progress: t,
            thickness: thickness,
            gapRadians: gapDegrees * math.pi / 180,
            trackColor: AppColors.track(context),
            highlighted: highlighted,
          ),
          child: child,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.progress,
    required this.thickness,
    required this.gapRadians,
    required this.trackColor,
    required this.highlighted,
  });

  final List<DonutSlice> slices;
  final double total;
  final double progress;
  final double thickness;
  final double gapRadians;
  final Color trackColor;
  final int? highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final arcRect = Rect.fromCircle(center: rect.center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = trackColor;
    canvas.drawCircle(rect.center, radius, track);

    if (total <= 0) return;

    // Start at twelve o'clock and sweep clockwise, which is how a person
    // reads a dial. Canvas angles start at three o'clock, hence the offset.
    var start = -math.pi / 2;

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      if (slice.value <= 0) continue;

      final full = (slice.value / total) * math.pi * 2;
      final sweep = (full - gapRadians) * progress;
      if (sweep <= 0) {
        start += full;
        continue;
      }

      final dimmed = highlighted != null && highlighted != i;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..color = dimmed ? slice.color.withValues(alpha: 0.28) : slice.color;

      canvas.drawArc(arcRect, start + gapRadians / 2, sweep, false, paint);
      start += full;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.highlighted != highlighted ||
      old.total != total ||
      old.trackColor != trackColor ||
      !identical(old.slices, slices);
}

/// One column of an [AppBarTrend].
class TrendBar {
  const TrendBar({required this.value, required this.label, this.isCurrent = false});

  final double value;

  /// Short axis label, e.g. a three-letter month.
  final String label;

  /// The period being viewed. Rendered in the brand colour while the rest
  /// stay neutral, so "where am I" needs no legend.
  final bool isCurrent;
}

/// A small bar series for month-over-month spend.
///
/// Deliberately not a line chart. A line implies a continuous quantity
/// sampled over time; monthly spend is a set of discrete totals, and bars say
/// that. It also makes the current month easy to single out, which a line
/// cannot do without a marker.
class AppBarTrend extends StatelessWidget {
  const AppBarTrend({
    super.key,
    required this.bars,
    this.height = 132,
    this.barColor,
    this.currentColor,
  });

  final List<TrendBar> bars;
  final double height;
  final Color? barColor;
  final Color? currentColor;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return SizedBox(height: height);

    final max = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    // Not AppColors.track: in dark that is the border token, which sits about
    // 1.3:1 against the card it is drawn on. The whole point of this chart is
    // comparing past months to the current one, and you cannot compare bars
    // you cannot see. Blend the muted ink into the surface instead, which
    // lifts in both themes without competing with the highlighted bar.
    final neutral = barColor ??
        Color.alphaBlend(
          AppColors.muted(context).withValues(alpha: 0.32),
          AppColors.surface(context),
        );
    final current = currentColor ?? AppColors.primary;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // A floor of 3px, so a month with a token amount of
                          // spend still reads as a bar rather than as a gap
                          // in the series.
                          final target = max <= 0
                              ? 0.0
                              : math.max(3.0, (bar.value / max) * constraints.maxHeight);
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: target),
                            duration: const Duration(milliseconds: 750),
                            curve: Curves.easeOutCubic,
                            builder: (context, h, _) => Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: h,
                                decoration: BoxDecoration(
                                  color: bar.isCurrent ? current : neutral,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                    bottom: Radius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bar.label,
                      style: AppTypography.mono(
                        size: 10,
                        weight: bar.isCurrent ? FontWeight.w700 : FontWeight.w400,
                        color: bar.isCurrent ? AppColors.ink(context) : AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A circular progress ring, used for a trial counting down to its charge date.
///
/// Reads as time running out in a way a horizontal bar does not: a ring closing
/// on itself has an obvious end, and the remaining gap is the remaining time.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 52,
    this.thickness = 4,
    this.child,
  });

  /// 0 to 1, where 1 is fully elapsed.
  final double progress;
  final Color color;
  final double size;
  final double thickness;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, t, inner) => CustomPaint(
          painter: _RingPainter(
            progress: t,
            color: color,
            thickness: thickness,
            trackColor: AppColors.track(context),
          ),
          child: inner,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.thickness,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final double thickness;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (math.min(size.width, size.height) - thickness) / 2;

    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = trackColor,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: rect.center, radius: radius),
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.trackColor != trackColor;
}

/// A compact horizontal series of proportional segments, for showing a split
/// inline where a donut would be too large. Same idea as the website's
/// summary rule.
class AppSplitBar extends StatelessWidget {
  const AppSplitBar({
    super.key,
    required this.slices,
    this.height = 10,
    this.gap = 2,
  });

  final List<DonutSlice> slices;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.track(context),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < slices.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                flex: math.max(1, (slices[i].value / total * 1000).round()),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500 + i * 70),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: t,
                      child: ColoredBox(
                        color: slices[i].color,
                        child: SizedBox(height: height),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
