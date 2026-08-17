import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/merchants.dart';
import '../theme/recur_brand.dart';
import '../ui/ui.dart';
import '../widgets/aurora_backdrop.dart';
import '../widgets/brand_mark.dart';
import '../widgets/dot_grid.dart';
import '../widgets/onboarding_previews.dart';
import '../widgets/phone_frame.dart';
import '../widgets/recur_logo.dart';

/// Three-beat pitch, then straight into bank linking.
///
/// Composition notes, because they're what makes this read as designed
/// rather than assembled:
///   * Real Recur UI runs inside a tilted device, not an illustration.
///   * A blurred aurora sits behind everything, colour-themed per slide —
///     a white screen with a small card on it always looks unfinished.
///   * Key UI escapes the device bounds and floats in front of it. That
///     single trick is what separates a product shot from a screenshot.
///   * Everything parallaxes at different rates on swipe, so the layers
///     read as having real depth.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();

  /// Drives every preview and the aurora.
  ///
  /// Plays **once** per slide and then rests, rather than looping forever.
  /// Two reasons, and the first is not optional:
  ///
  /// 1. WCAG 2.2.2 (Level A) requires a way to pause or stop any moving
  ///    content that auto-starts, runs longer than five seconds, and sits
  ///    alongside other content. An animation looping indefinitely behind
  ///    body copy fails that outright, and it applies to every user, not
  ///    just those who've set a reduce-motion preference.
  /// 2. The loop was also telling the wrong story. A scan that finds three
  ///    subscriptions and then immediately starts scanning again implies it
  ///    failed. Playing once and holding the result is what actually
  ///    happens in the product.
  late final AnimationController _ambient;

  /// Continuous page position, for parallax. Not the same as [_page], which
  /// only updates when a page settles.
  double _offset = 0;
  int _page = 0;

  bool _reduceMotion = false;

  static const List<_Slide> _slides = [
    _Slide(
      eyebrow: 'THE PROBLEM',
      title: 'It hides in your statement',
      body:
          'Netflix. DStv. A data plan renewing itself. '
          'None of it announces itself. It just leaves.',
      kind: _PreviewKind.statement,
      // Three warm, slightly clashing alarm tones — the chaos before
      // Recur sorts it out. Resolves into the calm green identity on the
      // next slide, on purpose.
      aurora: [Color(0xFFFFB020), Color(0xFFFF6B6B), Color(0xFFB23A2E)],
    ),
    _Slide(
      eyebrow: 'WHAT RECUR DOES',
      title: 'One number, finally',
      body:
          'We group every charge that repeats and show you the total nobody '
          'ever sits down and adds up.',
      kind: _PreviewKind.total,
      aurora: [RecurBrand.gradientStart, RecurBrand.gradientEnd, Color(0xFFF2D9A0)],
    ),
    _Slide(
      eyebrow: 'BEFORE IT HAPPENS',
      title: 'Warned, not surprised',
      body:
          'A heads-up days before each renewal lands, with the exact steps '
          'to cancel if you are done with it.',
      kind: _PreviewKind.notification,
      aurora: [RecurBrand.mint, RecurBrand.gradientEnd, Color(0xFF7BE8C2)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _controller.addListener(() {
      final page = _controller.page;
      if (page != null && page != _offset) {
        setState(() => _offset = page);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS-level setting. Android's "Remove animations" doesn't
    // reach app content on its own, so it has to be honoured explicitly.
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _playSlide();
    } else if (!_ambient.isAnimating && _ambient.value == 0) {
      _playSlide();
    }
  }

  /// Runs the current slide's reveal from the start. With reduce-motion on,
  /// jump straight to the resolved state — the user still sees the finished
  /// composition, just without the journey to it.
  void _playSlide() {
    if (_reduceMotion) {
      _ambient.value = 1;
    } else {
      _ambient.forward(from: 0);
    }
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
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFinished();
    }
  }

  void _back() {
    if (_page > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    }
  }


  /// Aurora colours cross-fade between adjacent slides as you swipe.
  List<Color> get _blendedAurora {
    final lower = _offset.floor().clamp(0, _slides.length - 1);
    final upper = _offset.ceil().clamp(0, _slides.length - 1);
    final f = _offset - lower;
    final a = _slides[lower].aurora;
    final b = _slides[upper].aurora;
    return List.generate(
      math.min(a.length, b.length),
      (i) => Color.lerp(a[i], b[i], f) ?? a[i],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          // ---- aurora sits behind everything, spanning the whole screen ----
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) => AuroraBackdrop(
                t: _ambient.value,
                colors: _blendedAurora,
              ),
            ),
          ),

          // Dot texture over the aurora. Drifts slightly against the page
          // so it sits in the depth stack rather than feeling stuck to the
          // glass, and fades out above the copy block.
          Positioned.fill(
            child: IgnorePointer(
              child: DotGrid(offset: Offset(-_offset * 22, 0)),
            ),
          ),

          // A soft veil at the bottom, matching the page background, so
          // copy always stays legible over whatever colour the aurora
          // happens to drift into — in either theme.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background(context).withValues(alpha: 0.0),
                      AppColors.background(context).withValues(alpha: 0.55),
                      AppColors.background(context).withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.52, 0.78],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ---- top bar: back left, skip right ----
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Row(
                      children: [
                        // Back fades in from the second slide, but keeps its
                        // slot so the row never shifts.
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: _page > 0 ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: _page == 0,
                            child: IconButton(
                              onPressed: _back,
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: AppColors.inkSoft(context),
                              tooltip: 'Back',
                            ),
                          ),
                        ),
                        const Spacer(),
                        AppButton(
                          label: 'Skip',
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.sm,
                          onPressed: widget.onFinished,
                        ),
                      ],
                    ),
                  ),
                ),

                // ---- slides ----
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) {
                      setState(() => _page = i);
                      // Each slide tells its story once, when the user
                      // actually arrives on it.
                      _playSlide();
                    },
                    itemBuilder: (context, i) => _SlideView(
                      slide: _slides[i],
                      ambient: _ambient,
                      // How far this slide is from centre screen: 0 when
                      // settled, ±1 when fully off to either side.
                      delta: i - _offset,
                      textTheme: text,
                    ),
                  ),
                ),

                // ---- progress ----
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final selected = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      height: 5,
                      width: selected ? 30 : 5,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border(context),
                        borderRadius: AppRadius.fullBR,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ---- primary action ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    0,
                    AppSpacing.xxl,
                    AppSpacing.xl,
                  ),
                  child: AppButton(
                    label: isLast ? 'Get started' : 'Continue',
                    size: AppButtonSize.lg,
                    expand: true,
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _PreviewKind { statement, total, notification }

class _Slide {
  const _Slide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.kind,
    required this.aurora,
  });

  final String eyebrow;
  final String title;
  final String body;
  final _PreviewKind kind;
  final List<Color> aurora;
}

// ---------------------------------------------------------------------------

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.ambient,
    required this.delta,
    required this.textTheme,
  });

  final _Slide slide;
  final AnimationController ambient;

  /// 0 when this slide is centred, ±1 when a full page away.
  final double delta;

  final TextTheme textTheme;

  /// Copy block height. Fixed so the CTA never jumps between slides.
  static const double _copyHeight = 162;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Size the device from whatever's left after the copy block, so
        // short phones shrink it rather than overflowing.
        final stageHeight = constraints.maxHeight - _copyHeight;
        final phoneHeight = math.min(348.0, math.max(200.0, stageHeight - 16));
        final phoneWidth = phoneHeight * 0.70;

        return Column(
          children: [
            SizedBox(
              height: stageHeight,
              child: AnimatedBuilder(
                animation: ambient,
                builder: (context, _) => _Stage(
                  slide: slide,
                  t: ambient.value,
                  delta: delta,
                  phoneWidth: phoneWidth,
                  phoneHeight: phoneHeight,
                ),
              ),
            ),
            SizedBox(
              height: _copyHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  0,
                ),
                child: Transform.translate(
                  // Copy drifts slightly faster than the device — the
                  // cheapest possible depth cue.
                  offset: Offset(-delta * 40, 0),
                  child: Opacity(
                    opacity: (1 - delta.abs() * 1.4).clamp(0.0, 1.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.eyebrow,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.title,
                          style: textTheme.headlineSmall?.copyWith(
                            height: 1.18,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.body,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted(context),
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The device plus everything floating around it.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.slide,
    required this.t,
    required this.delta,
    required this.phoneWidth,
    required this.phoneHeight,
  });

  final _Slide slide;
  final double t;
  final double delta;
  final double phoneWidth;
  final double phoneHeight;

  @override
  Widget build(BuildContext context) {
    // The device settles into place rather than bobbing forever. Three
    // independent oscillations running at once — aurora, phone, cards —
    // is what tipped this from "alive" into "restless".
    final settle = (1 - Curves.easeOutCubic.transform(t.clamp(0.0, 1.0))) * -10;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // ---- the device ----
        Transform.translate(
          offset: Offset(-delta * 70, settle),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011) // perspective
              ..rotateY(-0.15 + delta * 0.5)
              ..rotateX(0.045)
              ..rotateZ(-0.015),
            child: PhoneFrame(
              width: phoneWidth,
              height: phoneHeight,
              child: switch (slide.kind) {
                _PreviewKind.statement => StatementScanPreview(t: t),
                _PreviewKind.total => TotalStackPreview(t: t),
                _PreviewKind.notification => QuietAppPreview(
                    t: t,
                    dim: _notifPresence(t),
                  ),
              },
            ),
          ),
        ),

        // ---- escaping UI ----
        ..._floaters(),
      ],
    );
  }

  /// How present the notification is, 0–1. Shared by the dimming inside the
  /// device and the floating card outside it so they stay in sync.
  ///
  /// Arrives and stays. It used to slide back out so the loop could replay,
  /// which meant the slide's whole point — the alert — was absent half the
  /// time the user was looking at it.
  static double _notifPresence(double t) =>
      Curves.easeOutBack.transform(((t - 0.14) / 0.26).clamp(0.0, 1.0))
          .clamp(0.0, 1.0);

  /// Switch *expression* rather than a statement, so the compiler enforces
  /// that every preview kind has floating UI defined for it.
  List<Widget> _floaters() => switch (slide.kind) {
        // Detected charges lifting out of the statement.
        _PreviewKind.statement => [
            _Floater(
              offset: Offset(phoneWidth * 0.33, -phoneHeight * 0.21),
              delta: delta,
              parallax: 1.7,
              appear: ((t - 0.34) / 0.14).clamp(0.0, 1.0),
              bob: 0,
              child: _DetectedChip(merchant: Merchants.netflix, amount: '₦7,000'),
            ),
            _Floater(
              offset: Offset(-phoneWidth * 0.34, phoneHeight * 0.14),
              delta: delta,
              parallax: 2.1,
              appear: ((t - 0.52) / 0.14).clamp(0.0, 1.0),
              bob: 0,
              child: _DetectedChip(merchant: Merchants.dstv, amount: '₦19,000'),
            ),
          ],

        // The annual number — the actual gut-punch.
        _PreviewKind.total => [
            _Floater(
              offset: Offset(phoneWidth * 0.32, phoneHeight * 0.30),
              delta: delta,
              parallax: 1.9,
              appear: ((t - 0.60) / 0.16).clamp(0.0, 1.0),
              bob: 0,
              child: const _AnnualPill(),
            ),
          ],

        // The alert itself, hero-sized, fully outside the device.
        _PreviewKind.notification => [
            _Floater(
              offset: Offset(phoneWidth * 0.06, -phoneHeight * 0.30),
              delta: delta,
              parallax: 1.8,
              appear: _notifPresence(t),
              bob: 0,
              child: const _AlertCard(),
            ),
          ],
      };
}

/// Positions a floating element relative to the device centre, with its own
/// parallax rate and entrance.
class _Floater extends StatelessWidget {
  const _Floater({
    required this.offset,
    required this.delta,
    required this.parallax,
    required this.appear,
    required this.bob,
    required this.child,
  });

  final Offset offset;
  final double delta;

  /// Multiplier on the base swipe translation. Higher = moves more = reads
  /// as closer to the viewer.
  final double parallax;

  final double appear;
  final double bob;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = Curves.easeOutBack.transform(appear.clamp(0.0, 1.0));
    return Transform.translate(
      offset: Offset(
        offset.dx - delta * 70 * parallax,
        offset.dy + bob,
      ),
      child: Opacity(
        opacity: appear.clamp(0.0, 1.0) * (1 - delta.abs()).clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.86 + 0.14 * a, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating card designs
// ---------------------------------------------------------------------------

class _FloatCard extends StatelessWidget {
  const _FloatCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.14),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetectedChip extends StatelessWidget {
  const _DetectedChip({required this.merchant, required this.amount});

  final Merchant merchant;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return _FloatCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(
            slug: merchant.slug,
            fallbackLabel: merchant.name,
            brandColor: merchant.brandColor,
            networkUrl: merchant.logoUrl,
            size: 30,
            radius: 9,
            bordered: false,
            padded: false,
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${merchant.name} · $amount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 1),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.autorenew_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'every month',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnualPill extends StatelessWidget {
  const _AnnualPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.30),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "THAT'S A YEAR",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            '₦756,396',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      child: _FloatCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The app icon as it would actually appear in a notification
            // tray: the brand mark on the brand gradient.
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: RecurBrand.brandGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const RecurLogo(size: 20, onDark: true, showNode: false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Recur',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'now',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.neutral400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'DStv takes ₦19,000 in 2 days',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Still watching? Tap for how to cancel.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
