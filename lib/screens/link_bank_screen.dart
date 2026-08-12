import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/api_client.dart';
import '../data/banking_service.dart';
import '../ui/ui.dart';

/// Consent → Mono's hosted Connect page (webview) → confirming → done.
///
/// The consent step is doing the heaviest lifting in the whole product:
/// asking a Nigerian user to connect a real bank account to a new app is
/// the single biggest drop-off point, so it states plainly what Recur can
/// and cannot do before anything else happens.
///
/// Bank selection and login happen entirely on Mono's own hosted page
/// (opened in the webview below) — this app never sees which bank was
/// picked or any credentials, only a redirect once the user finishes.
/// Even then, the actual linked-account id isn't known synchronously: it
/// arrives moments later via a webhook to the backend, so "waiting" here
/// means polling for that to land rather than a fixed animation.
class LinkBankScreen extends StatefulWidget {
  const LinkBankScreen({super.key, required this.onDone});

  /// Called when the user finishes linking, or chooses to skip for now.
  /// Skipping is allowed on purpose: forcing a bank connection before
  /// someone has seen anything useful is how you lose them at the door.
  final VoidCallback onDone;

  @override
  State<LinkBankScreen> createState() => _LinkBankScreenState();
}

enum _Step { consent, webview, waiting, success, timeout }

class _LinkBankScreenState extends State<LinkBankScreen> {
  _Step _step = _Step.consent;
  bool _busy = false;

  WebViewController? _controller;
  String? _redirectUrl;
  bool _redirectHandled = false;

  Future<void> _startLinking() async {
    setState(() => _busy = true);
    try {
      final result = await BankingService.initiateLink();
      _redirectUrl = result.redirectUrl;
      _redirectHandled = false;

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (request.url.startsWith(_redirectUrl!)) {
                _onLinkingRedirect();
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(result.monoUrl));

      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.webview;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    }
  }

  void _onLinkingRedirect() {
    // The webview can fire multiple navigation events for the same
    // redirect (query-string variants, a trailing fragment); only act on
    // the first one.
    if (_redirectHandled) return;
    _redirectHandled = true;
    setState(() => _step = _Step.waiting);
    _pollForLinkedAccount();
  }

  /// The account id isn't known until Mono's `account_connected` webhook
  /// reaches the backend — anywhere from "instant" to a couple of minutes
  /// per Mono's own docs. Polling `GET /banking/accounts` is the only way
  /// to know when that's landed; this isn't the final "subscriptions
  /// detected" state, just "the bank is actually linked, not abandoned."
  Future<void> _pollForLinkedAccount() async {
    const maxAttempts = 20;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return;
      try {
        final accounts = await BankingService.listAccounts();
        if (accounts.isNotEmpty) {
          if (!mounted) return;
          setState(() => _step = _Step.success);
          return;
        }
      } catch (_) {
        // Transient network hiccup — keep polling rather than failing the
        // whole flow on one bad request.
      }
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    setState(() => _step = _Step.timeout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(switch (_step) {
          _Step.consent => 'Before we start',
          _Step.webview => 'Connect your bank',
          _Step.waiting => 'Confirming',
          _Step.success => 'All set',
          _Step.timeout => 'Still connecting',
        }),
        leading: _step == _Step.webview
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _controller = null;
                  _step = _Step.consent;
                }),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: switch (_step) {
            _Step.consent => _buildConsent(),
            _Step.webview => _buildWebview(),
            _Step.waiting => _buildWaiting(),
            _Step.success => _buildSuccess(),
            _Step.timeout => _buildTimeout(),
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

          Text(
            'You stay in control. Disconnect any account and delete its data '
            'from Settings at any time.',
            style: text.bodySmall?.copyWith(
              color: AppColors.neutral500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          AppButton(
            label: 'I understand, continue',
            size: AppButtonSize.lg,
            expand: true,
            isLoading: _busy,
            onPressed: _busy ? null : _startLinking,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Not now',
            variant: AppButtonVariant.ghost,
            expand: true,
            onPressed: widget.onDone,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- webview

  Widget _buildWebview() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return WebViewWidget(key: const ValueKey('webview'), controller: controller);
  }

  // ---------------------------------------------------------------- waiting

  Widget _buildWaiting() {
    return Center(
      key: const ValueKey('waiting'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingOrb(),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'Confirming your connection',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "This can take a few seconds, sometimes longer depending on your bank.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutral500),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- success

  Widget _buildSuccess() {
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
          Text('Bank connected', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "We're scanning your transaction history now. Recurring charges "
            'will start showing up on your dashboard shortly.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: AppColors.neutral600,
              height: 1.5,
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Go to dashboard',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: widget.onDone,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- timeout

  Widget _buildTimeout() {
    final text = Theme.of(context).textTheme;

    return Padding(
      key: const ValueKey('timeout'),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.hourglass_top_rounded, size: 56, color: AppColors.neutral400),
          const SizedBox(height: AppSpacing.xl),
          Text('Taking longer than usual', style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Your bank connection is still being confirmed in the background. "
            "You can continue into the app now — we'll update your dashboard "
            'as soon as it comes through.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: AppColors.neutral600,
              height: 1.5,
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Continue to dashboard',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: widget.onDone,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Try again',
            variant: AppButtonVariant.ghost,
            expand: true,
            onPressed: () => setState(() => _step = _Step.consent),
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

/// Concentric pulse used while the link is being confirmed.
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
