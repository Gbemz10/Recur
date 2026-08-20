import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Three dots pulsing in sequence — the app's only loading indicator.
///
/// Preferred over a spinner for a reason worth stating: a circular
/// indicator sweeps continuously and gives no sense of rhythm, so a slow
/// request feels stalled. Three dots have a visible beat, and the loop
/// resolving over and over reads as "working" rather than "hung" — which
/// matters on a Nigerian connection where a request can genuinely take
/// several seconds.
///
/// No accompanying label. Loading copy is almost always either obvious
/// ("Loading…") or a lie about what's happening, and it forces a layout
/// that shifts the moment content arrives.
class AppDotsLoader extends StatefulWidget {
  const AppDotsLoader({
    super.key,
    this.size = 8,
    this.color,
    this.spacing,
  });

  /// Diameter of each dot at rest.
  final double size;

  /// Defaults to the brand primary.
  final Color? color;

  /// Gap between dots. Defaults to 60% of [size].
  final double? spacing;

  @override
  State<AppDotsLoader> createState() => _AppDotsLoaderState();
}

class _AppDotsLoaderState extends State<AppDotsLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final gap = widget.spacing ?? widget.size * 0.6;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            // Each dot trails the one before it by a third of the cycle.
            final phase = (_c.value + i * 0.16) % 1.0;

            // Rise and fall over the first 60% of the phase, then rest —
            // the pause is what gives the loop its beat.
            final wave = phase < 0.6 ? math.sin((phase / 0.6) * math.pi) : 0.0;

            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : gap),
              child: Transform.translate(
                offset: Offset(0, -widget.size * 0.42 * wave),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: (0.35 + 0.65 * wave).clamp(0.0, 1.0),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
