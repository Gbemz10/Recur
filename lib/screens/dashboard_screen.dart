import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/subscription.dart';
import '../theme/recur_brand.dart';
import '../ui/ui.dart';
import '../widgets/subscription_tile.dart';
import 'subscription_detail_screen.dart';

/// The one screen that matters in v1: what is repeating, what it costs,
/// and what is about to hit.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<Subscription> _subs = List.of(MockData.subscriptions);
  int _tab = 0;

  static const _tabs = ['Active', 'Review', 'Cancelled'];

  List<Subscription> get _visible => switch (_tab) {
        0 => _subs.where((s) => s.status == SubscriptionStatus.active).toList(),
        1 => _subs
            .where((s) => s.status == SubscriptionStatus.unreviewed)
            .toList(),
        _ => _subs
            .where((s) => s.status == SubscriptionStatus.cancelled)
            .toList(),
      };

  double get _monthlyTotal => _subs
      .where((s) => s.status == SubscriptionStatus.active)
      .fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

  List<Subscription> get _dueSoon {
    final list = _subs
        .where((s) => s.status == SubscriptionStatus.active && s.isDueSoon)
        .toList()
      ..sort((a, b) => a.daysUntilCharge.compareTo(b.daysUntilCharge));
    return list;
  }

  int get _reviewCount =>
      _subs.where((s) => s.status == SubscriptionStatus.unreviewed).length;

  void _updateStatus(Subscription sub, SubscriptionStatus status) {
    setState(() {
      final i = _subs.indexWhere((s) => s.id == sub.id);
      if (i != -1) _subs[i] = _subs[i].copyWith(status: status);
    });
  }

  Future<void> _openDetail(Subscription sub) async {
    final result = await Navigator.of(context).push<SubscriptionStatus>(
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailScreen(subscription: sub),
      ),
    );
    if (result != null) _updateStatus(sub, result);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.neutral500),
                        ),
                        Text('Your repeats', style: text.headlineSmall),
                      ],
                    ),
                  ),
                  const AppAvatar(name: 'Gbemiga S'),
                ],
              ),
            ),
          ),

          // ---- hero total ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                0,
              ),
              child: _TotalCard(
                monthly: _monthlyTotal,
                yearly: _monthlyTotal * 12,
                count: _subs
                    .where((s) => s.status == SubscriptionStatus.active)
                    .length,
              ),
            ),
          ),

          // ---- due soon ----
          if (_dueSoon.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hitting soon', style: text.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _dueSoon.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.md),
                        itemBuilder: (context, i) => _DueSoonCard(
                          subscription: _dueSoon[i],
                          onTap: () => _openDetail(_dueSoon[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ---- review nudge ----
          if (_reviewCount > 0 && _tab != 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = 1),
                  child: AppAlert(
                    title: '$_reviewCount charges need a quick look',
                    message:
                        'We are fairly sure these repeat, but not sure enough '
                        'to call them subscriptions. Tap to review.',
                    variant: AppAlertVariant.warning,
                  ),
                ),
              ),
            ),

          // ---- tabs ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: AppTabs(
                labels: _tabs,
                selectedIndex: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
            ),
          ),

          // ---- list ----
          if (_visible.isEmpty)
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: switch (_tab) {
                  1 => Icons.fact_check_outlined,
                  2 => Icons.do_not_disturb_on_outlined,
                  _ => Icons.autorenew_rounded,
                },
                title: switch (_tab) {
                  1 => 'Nothing to review',
                  2 => 'Nothing cancelled yet',
                  _ => 'No active subscriptions',
                },
                message: switch (_tab) {
                  1 => 'Every detected charge has been confirmed or dismissed.',
                  2 =>
                    'When you cancel something, it moves here so you can see '
                        'what you stopped paying.',
                  _ => 'Once we detect a repeating charge it will show up here.',
                },
              ),
            )
          else
            SliverList.separated(
              itemCount: _visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final sub = _visible[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: SubscriptionTile(
                    subscription: sub,
                    index: i,
                    showConfidence: _tab == 1,
                    onTap: () => _openDetail(sub),
                    onConfirm: _tab == 1
                        ? () => _updateStatus(sub, SubscriptionStatus.active)
                        : null,
                    onDismiss: _tab == 1
                        ? () => _updateStatus(sub, SubscriptionStatus.cancelled)
                        : null,
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.huge),
          ),
        ],
      ),
    );
  }
}

/// The number the whole app exists to show. Animated on first paint because
/// a total that counts up reads as "we just worked this out for you".
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.monthly,
    required this.yearly,
    required this.count,
  });

  final double monthly;
  final double yearly;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: RecurBrand.brandGradient,
        borderRadius: AppRadius.xlBR,
        boxShadow: [
          BoxShadow(
            color: RecurBrand.gradientStart.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.autorenew_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Repeating every month',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: monthly),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  formatNaira(value),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$count active · ${formatNaira(yearly)} a year',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal card for charges landing within a week, with a small
/// countdown ring so urgency is legible at a glance.
class _DueSoonCard extends StatelessWidget {
  const _DueSoonCard({required this.subscription, required this.onTap});

  final Subscription subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = subscription.daysUntilCharge;
    final urgent = days <= 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: AppRadius.lgBR,
          border: Border.all(
            color: urgent
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CustomPaint(
                painter: _CountdownRingPainter(
                  days: days,
                  color: urgent ? AppColors.warning : AppColors.primary,
                ),
                child: Center(
                  child: Text(
                    days == 0 ? 'now' : '${days}d',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: urgent ? AppColors.warning : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subscription.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatNaira(subscription.amount),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.neutral500),
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

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({required this.days, required this.color});

  final int days;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.neutral200,
    );

    // Fuller ring = sooner. 7 days out is the window we care about.
    final progress = ((7 - days) / 7).clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter old) =>
      old.days != days || old.color != color;
}
