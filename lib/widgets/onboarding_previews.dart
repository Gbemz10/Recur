import 'package:flutter/material.dart';

import '../data/merchants.dart';
import '../data/mock_data.dart';
import '../theme/recur_brand.dart';
import '../ui/ui.dart';
import 'brand_mark.dart';

/// Month label for the simulated statement, so the preview never shows a
/// stale date. Hardcoding this was a small lie that would age badly.
String currentMonthLabel() {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final now = DateTime.now();
  return '${months[now.month - 1]} ${now.year}';
}

/// Live previews of real Recur UI, shown inside a phone frame during
/// onboarding.
///
/// The rule for all three: show the actual product doing its job. Abstract
/// illustration is cheaper to build and much weaker at explaining what the
/// app is — the strongest fintech onboarding (Wise, Slack) shows something
/// real before it asks for anything.
///
/// Every preview is wrapped in a non-scrolling [SingleChildScrollView] so
/// content can never trigger a RenderFlex overflow on a short device — it
/// just gets clipped by the frame, which is the correct behaviour for a
/// simulated screen.

/// Shared wrapper: overflow-proof, consistent padding.
class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Statement scanning — a real transaction list, with the repeats
//    picking themselves out as a scan line passes over them.
// ---------------------------------------------------------------------------

class StatementScanPreview extends StatelessWidget {
  const StatementScanPreview({super.key, required this.t});

  /// 0–1, loops.
  final double t;

  static const List<_Txn> _rows = [
    _Txn('Bolt ride', '₦3,400', false, Merchants.bolt),
    _Txn('NETFLIX.COM NGN', '₦7,000', true, Merchants.netflix),
    _Txn('Chicken Republic', '₦6,200', false, null),
    _Txn('MULTICHOICE DSTV', '₦19,000', true, Merchants.dstv),
    _Txn('Transfer to Tunde', '₦25,000', false, null),
    _Txn('MTNNG DATA AUTOREN', '₦10,000', true, Merchants.mtn),
  ];

  @override
  Widget build(BuildContext context) {
    // Scan sweeps over the first 65% of the loop, then holds on the result.
    final scan = (t / 0.65).clamp(0.0, 1.0);

    return Stack(
      children: [
        _PreviewSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Your statement',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const Spacer(),
                  _ScanStatus(t: t, done: scan >= 1),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                currentMonthLabel(),
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutral400,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _rows.length; i++)
                _TxnRow(
                  txn: _rows[i],
                  // A row resolves once the scan line has passed it.
                  found: scan > (i + 1) / _rows.length,
                ),
            ],
          ),
        ),

        // The scan line itself.
        if (scan < 1)
          Positioned(
            left: 0,
            right: 0,
            top: 44 + scan * 216,
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    RecurBrand.gradientStart.withValues(alpha: 0.0),
                    RecurBrand.gradientStart.withValues(alpha: 0.18),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: RecurBrand.gradientStart.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Txn {
  const _Txn(this.label, this.amount, this.recurring, this.merchant);
  final String label;
  final String amount;
  final bool recurring;

  /// Null for one-off spend we can't attribute to a known brand — which is
  /// most of a real statement.
  final Merchant? merchant;
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn, required this.found});

  final _Txn txn;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final highlight = txn.recurring && found;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryLight : AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? RecurBrand.gradientStart.withValues(alpha: 0.5)
              : AppColors.neutral200,
          width: highlight ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          // Brand mark for anything we recognise, a neutral dot otherwise.
          if (txn.merchant case final m?)
            BrandMark(
              slug: m.slug,
              fallbackLabel: m.name,
              brandColor: m.brandColor,
              networkUrl: m.logoUrl,
              size: 17,
              radius: 5,
              bordered: false,
              padded: false,
            )
          else
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 10,
                color: AppColors.neutral400,
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              txn.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? AppColors.neutral900 : AppColors.neutral600,
              ),
            ),
          ),
          // The repeat badge slides in beside the amount once detected.
          AnimatedScale(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            scale: highlight ? 1 : 0.3,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              opacity: highlight ? 1 : 0,
              child: Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.only(right: 5),
                decoration: const BoxDecoration(
                  color: RecurBrand.gradientStart,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.autorenew_rounded,
                  size: 8.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Text(
            txn.amount,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: highlight ? RecurBrand.gradientStart : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Spinner that resolves into a result pill once the scan lands.
class _ScanStatus extends StatelessWidget {
  const _ScanStatus({required this.t, required this.done});

  final double t;
  final bool done;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '3 repeats',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppColors.success,
          ),
        ),
      );
    }
    return Row(
      children: [
        Transform.rotate(
          angle: t * 14,
          child: const Icon(
            Icons.autorenew_rounded,
            size: 12,
            color: AppColors.neutral400,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Scanning',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral400,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. The total — real hero card counting up, with subscription cards
//    stacking in underneath it.
// ---------------------------------------------------------------------------

class TotalStackPreview extends StatelessWidget {
  const TotalStackPreview({super.key, required this.t});

  final double t;

  static const List<_Sub> _subs = [
    _Sub('Netflix', '₦7,000', Merchants.netflix),
    _Sub('DStv Compact', '₦19,000', Merchants.dstv),
    _Sub('MTN Data', '₦10,000', Merchants.mtn),
    _Sub('ChatGPT Plus', '₦32,000', Merchants.openai),
  ];

  @override
  Widget build(BuildContext context) {
    // Count up over the first 42% of the loop.
    final countT = Curves.easeOutCubic.transform((t / 0.42).clamp(0.0, 1.0));
    final total = 63033 * countT;

    return _PreviewSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero total card — same gradient treatment as the real dashboard.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: RecurBrand.brandGradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: RecurBrand.gradientStart.withValues(alpha: 0.34),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.autorenew_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Repeating every month',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  formatNaira(total),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '9 active subscriptions',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),

          // Cards stack in one after another, once the count settles.
          for (var i = 0; i < _subs.length; i++)
            _StackedSubRow(
              sub: _subs[i],
              progress: Curves.easeOutCubic.transform(
                ((t - 0.40 - i * 0.10) / 0.15).clamp(0.0, 1.0),
              ),
            ),
        ],
      ),
    );
  }
}

class _Sub {
  const _Sub(this.name, this.amount, this.merchant);
  final String name;
  final String amount;
  final Merchant merchant;
}

class _StackedSubRow extends StatelessWidget {
  const _StackedSubRow({required this.sub, required this.progress});

  final _Sub sub;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 24 * (1 - progress)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              BrandMark(
                slug: sub.merchant.slug,
                fallbackLabel: sub.merchant.name,
                brandColor: sub.merchant.brandColor,
                networkUrl: sub.merchant.logoUrl,
                size: 22,
                radius: 6,
                bordered: false,
                padded: false,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  sub.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              Text(
                sub.amount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutral900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. The heads-up — the app sitting quietly, dimmed, while the real alert
//    is shown outside the frame by the onboarding screen.
// ---------------------------------------------------------------------------

class QuietAppPreview extends StatelessWidget {
  const QuietAppPreview({super.key, required this.t, required this.dim});

  final double t;

  /// 0–1. How much the app recedes as the notification takes over.
  final double dim;

  @override
  Widget build(BuildContext context) {
    return _PreviewSurface(
      child: Opacity(
        opacity: 1 - dim * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: RecurBrand.brandGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hitting soon',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '₦63,033',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.05,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                height: 37,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 21,
                      height: 21,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 56 + (i % 3) * 14,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(4),
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
