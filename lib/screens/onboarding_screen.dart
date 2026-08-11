import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/recur_brand.dart';
import '../ui/ui.dart';
import 'link_bank_screen.dart';

/// Three-beat pitch, then straight into bank linking.
///
/// Each page has its own animated illustration rather than a static image —
/// the motion is what sells "this happens automatically" better than the
/// copy does.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  late final AnimationController _ambient;
  int _page = 0;

  static const List<_Slide> _slides = [
    _Slide(
      title: 'Money leaves quietly',
      body:
          'Old subscriptions, auto-renewing data plans, that free trial from '
          'March. Small charges you stopped noticing months ago.',
      art: _ArtKind.leak,
    ),
    _Slide(
      title: 'Link your bank once',
      body:
          'Recur reads your transaction history through a secure, '
          'read-only connection. No passwords stored, no ability to move '
          'your money.',
      art: _ArtKind.link,
    ),
    _Slide(
      title: 'We find the repeats',
      body:
          'Every recurring charge, grouped and dated, with a heads-up '
          'before the next one hits. You do nothing.',
      art: _ArtKind.radar,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _openLinkFlow();
    }
  }

  Future<void> _openLinkFlow() async {
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LinkBankScreen()),
    );
    if (linked == true) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                ),
                child: AppButton(
                  label: 'Skip',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onPressed: _openLinkFlow,
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 260,
                          width: double.infinity,
                          child: AnimatedBuilder(
                            animation: _ambient,
                            builder: (_, __) => CustomPaint(
                              painter: _OnboardingArtPainter(
                                kind: slide.art,
                                t: _ambient.value,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.huge),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: text.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.neutral600,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final selected = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  height: 6,
                  width: selected ? 26 : 6,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.neutral300,
                    borderRadius: AppRadius.fullBR,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xxl),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                0,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: AppButton(
                label: isLast ? 'Link my bank' : 'Continue',
                size: AppButtonSize.lg,
                expand: true,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ArtKind { leak, link, radar }

class _Slide {
  const _Slide({required this.title, required this.body, required this.art});
  final String title;
  final String body;
  final _ArtKind art;
}

/// Hand-drawn-in-code illustrations. Keeping these as painters (rather than
/// bundled images) means they animate, theme correctly, and cost nothing
/// in app size.
class _OnboardingArtPainter extends CustomPainter {
  _OnboardingArtPainter({required this.kind, required this.t});

  final _ArtKind kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _ArtKind.leak:
        _paintLeak(canvas, size);
      case _ArtKind.link:
        _paintLink(canvas, size);
      case _ArtKind.radar:
        _paintRadar(canvas, size);
    }
  }

  /// A wallet outline with coins escaping downward — the money leak.
  void _paintLeak(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.38);
    final walletRect = Rect.fromCenter(center: c, width: 150, height: 104);

    canvas.drawRRect(
      RRect.fromRectAndRadius(walletRect, const Radius.circular(AppRadius.lg)),
      Paint()..color = AppColors.primaryLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(walletRect, const Radius.circular(AppRadius.lg)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(walletRect.right - 26, c.dy),
      7,
      Paint()..color = AppColors.primary.withValues(alpha: 0.7),
    );

    // Escaping coins on staggered loops.
    for (var i = 0; i < 5; i++) {
      final phase = (t + i / 5) % 1.0;
      final x = c.dx - 46 + i * 23;
      final y = walletRect.bottom + phase * 96;
      final fade = (1 - phase).clamp(0.0, 1.0);
      final r = 9.0 - phase * 3;

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = AppColors.warning.withValues(alpha: 0.85 * fade),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.warning.withValues(alpha: 0.9 * fade),
      );
    }
  }

  /// Phone and bank node joined by a travelling data pulse.
  void _paintLink(Canvas canvas, Size size) {
    final left = Offset(size.width * 0.28, size.height * 0.45);
    final right = Offset(size.width * 0.72, size.height * 0.45);

    // Phone
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: left, width: 66, height: 108),
      const Radius.circular(AppRadius.md),
    );
    canvas.drawRRect(phone, Paint()..color = AppColors.primary);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: left.translate(0, 6),
          width: 48,
          height: 74,
        ),
        const Radius.circular(AppRadius.sm),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    // Bank
    final bankBase = Rect.fromCenter(center: right, width: 92, height: 62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bankBase, const Radius.circular(AppRadius.sm)),
      Paint()..color = AppColors.neutral200,
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(bankBase.left + 12 + i * 19, bankBase.top + 12, 7, 38),
        Paint()..color = AppColors.neutral400,
      );
    }
    final roof = Path()
      ..moveTo(bankBase.left - 8, bankBase.top)
      ..lineTo(right.dx, bankBase.top - 30)
      ..lineTo(bankBase.right + 8, bankBase.top)
      ..close();
    canvas.drawPath(roof, Paint()..color = AppColors.neutral500);

    // Connection line + travelling pulse
    final linePaint = Paint()
      ..strokeWidth = 2
      ..color = AppColors.primary.withValues(alpha: 0.3);
    canvas.drawLine(left.translate(38, 0), right.translate(-52, 0), linePaint);

    final pulseX = left.dx + 38 + ((right.dx - 52) - (left.dx + 38)) * t;
    canvas.drawCircle(
      Offset(pulseX, left.dy),
      6,
      Paint()..color = RecurBrand.mint,
    );
    canvas.drawCircle(
      Offset(pulseX, left.dy),
      13,
      Paint()..color = RecurBrand.mint.withValues(alpha: 0.22),
    );

    // Lock badge — the trust cue does a lot of work on this slide.
    final lockCenter = Offset(size.width / 2, size.height * 0.72);
    canvas.drawCircle(
      lockCenter,
      20,
      Paint()..color = AppColors.successBg,
    );
    canvas.drawCircle(
      lockCenter,
      20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.success.withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: lockCenter.translate(0, 3), width: 15, height: 12),
        const Radius.circular(2.5),
      ),
      Paint()..color = AppColors.success,
    );
    canvas.drawArc(
      Rect.fromCenter(center: lockCenter.translate(0, -4), width: 12, height: 12),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = AppColors.success,
    );
  }

  /// Sweeping radar that lights up detected charges.
  void _paintRadar(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.5);
    const maxR = 108.0;

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        c,
        maxR * i / 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.neutral300,
      );
    }

    // Sweep wedge
    final angle = t * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: maxR),
      angle,
      math.pi / 3.2,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: angle,
          endAngle: angle + math.pi / 3.2,
          colors: [
            AppColors.primary.withValues(alpha: 0.30),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: maxR)),
    );
    canvas.drawLine(
      c,
      Offset(c.dx + math.cos(angle) * maxR, c.dy + math.sin(angle) * maxR),
      Paint()
        ..strokeWidth = 2
        ..color = AppColors.primary.withValues(alpha: 0.75),
    );

    // Blips light up as the sweep passes them.
    const blips = [
      (0.9, 0.62), // angle fraction, radius fraction
      (2.4, 0.85),
      (4.1, 0.45),
      (5.3, 0.72),
    ];
    for (final (a, rf) in blips) {
      final pos = Offset(
        c.dx + math.cos(a) * maxR * rf,
        c.dy + math.sin(a) * maxR * rf,
      );
      // How recently the sweep crossed this blip.
      var delta = (angle % (2 * math.pi)) - a;
      if (delta < 0) delta += 2 * math.pi;
      final freshness = (1 - delta / (2 * math.pi)).clamp(0.0, 1.0);
      final glow = math.pow(freshness, 3).toDouble();

      canvas.drawCircle(
        pos,
        5 + 3 * glow,
        Paint()..color = RecurBrand.mint.withValues(alpha: 0.35 + 0.65 * glow),
      );
      canvas.drawCircle(
        pos,
        14 * glow,
        Paint()..color = RecurBrand.mint.withValues(alpha: 0.20 * glow),
      );
    }

    canvas.drawCircle(c, 6, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _OnboardingArtPainter old) =>
      old.t != t || old.kind != kind;
}
