import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../ui/ui.dart';

/// Consent → pick bank → connecting → done.
///
/// The consent step is doing the heaviest lifting in the whole product:
/// asking a Nigerian user to connect a real bank account to a new app is
/// the single biggest drop-off point, so it states plainly what Recur can
/// and cannot do before anything else happens.
class LinkBankScreen extends StatefulWidget {
  const LinkBankScreen({super.key});

  @override
  State<LinkBankScreen> createState() => _LinkBankScreenState();
}

enum _Step { consent, pickBank, connecting, success }

class _LinkBankScreenState extends State<LinkBankScreen> {
  _Step _step = _Step.consent;
  String? _bank;
  String _statusLine = 'Establishing secure connection…';
  Timer? _timer;

  static const List<String> _connectingLines = [
    'Establishing secure connection…',
    'Verifying with your bank…',
    'Reading transaction history…',
    'Looking for repeating charges…',
    'Grouping what we found…',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startConnecting(String bank) {
    setState(() {
      _bank = bank;
      _step = _Step.connecting;
      _statusLine = _connectingLines.first;
    });

    var i = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      i++;
      if (!mounted) return;
      if (i < _connectingLines.length) {
        setState(() => _statusLine = _connectingLines[i]);
      } else {
        timer.cancel();
        setState(() => _step = _Step.success);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(switch (_step) {
          _Step.consent => 'Before we start',
          _Step.pickBank => 'Choose your bank',
          _Step.connecting => 'Connecting',
          _Step.success => 'All set',
        }),
        leading: _step == _Step.connecting
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (_step == _Step.pickBank) {
                    setState(() => _step = _Step.consent);
                  } else {
                    Navigator.of(context).pop(false);
                  }
                },
              ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: switch (_step) {
            _Step.consent => _buildConsent(),
            _Step.pickBank => _buildPickBank(),
            _Step.connecting => _buildConnecting(),
            _Step.success => _buildSuccess(),
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- consent

  Widget _buildConsent() {
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      key: const ValueKey('consent'),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recur only ever reads.', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your bank connection is read-only. Here is exactly what that '
            'means in practice.',
            style: text.bodyMedium?.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: AppSpacing.xxl),

          const _ConsentRow(
            icon: Icons.check_circle_outline_rounded,
            positive: true,
            title: 'We can see your transaction history',
            body: 'That is how we spot charges that repeat.',
          ),
          const _ConsentRow(
            icon: Icons.check_circle_outline_rounded,
            positive: true,
            title: 'We can see your account balance',
            body: 'Used to warn you when a renewal might bounce.',
          ),
          const _ConsentRow(
            icon: Icons.block_rounded,
            positive: false,
            title: 'We cannot move your money',
            body: 'No transfers, no payments, no card charges. Ever.',
          ),
          const _ConsentRow(
            icon: Icons.block_rounded,
            positive: false,
            title: 'We never see your bank password',
            body: 'You authorise through your bank, not through us.',
          ),

          const SizedBox(height: AppSpacing.lg),
          const AppAlert(
            title: 'You stay in control',
            message:
                'Disconnect any account and delete its data from Settings '
                'at any time.',
            variant: AppAlertVariant.info,
          ),
          const SizedBox(height: AppSpacing.xxl),

          AppButton(
            label: 'I understand, continue',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: () => setState(() => _step = _Step.pickBank),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Not now',
            variant: AppButtonVariant.ghost,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- pick bank

  Widget _buildPickBank() {
    return Column(
      key: const ValueKey('pick'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
          ),
          child: Text(
            'Pick the bank your subscriptions are charged to. You can add '
            'more later.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.neutral600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              0,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 2.4,
            ),
            itemCount: MockData.supportedBanks.length,
            itemBuilder: (context, i) {
              final bank = MockData.supportedBanks[i];
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                onTap: () => _startConnecting(bank),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: AppRadius.smBR,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bank.substring(0, 1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        bank,
                        style: Theme.of(context).textTheme.labelLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- connecting

  Widget _buildConnecting() {
    return Center(
      key: const ValueKey('connecting'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingOrb(),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              _bank ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                _statusLine,
                key: ValueKey(_statusLine),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.neutral500),
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            Text(
              'This usually takes a few seconds. Keep the app open.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.neutral400),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- success

  Widget _buildSuccess() {
    final found = MockData.subscriptions.length;
    final text = Theme.of(context).textTheme;

    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('$found recurring charges found', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'That is ${formatNaira(MockData.monthlyTotal)} a month leaving '
            'your account on repeat. Let us go through them.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: AppColors.neutral600,
              height: 1.5,
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'See what we found',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.positive,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.neutral500;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.neutral500, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Concentric pulse used while the bank connection is in flight.
class _PulsingOrb extends StatefulWidget {
  const _PulsingOrb();

  @override
  State<_PulsingOrb> createState() => _PulsingOrbState();
}

class _PulsingOrbState extends State<_PulsingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Three expanding rings, evenly offset in time.
              for (var i = 0; i < 3; i++)
                Builder(
                  builder: (_) {
                    final p = ((_c.value + i / 3) % 1.0);
                    return Opacity(
                      opacity: (1 - p) * 0.6,
                      child: Container(
                        width: 46 + p * 86,
                        height: 46 + p * 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            width: 1.6,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
