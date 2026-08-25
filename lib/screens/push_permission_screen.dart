import 'package:flutter/material.dart';

import '../data/mock_data.dart' show formatNaira;
import '../ui/ui.dart';

/// Asks for push, before the system does.
///
/// iOS gives you exactly one chance at the real permission dialog: answer
/// "Don't Allow" once and the app cannot ask again, only send you to Settings.
/// So this screen goes first — it can be declined harmlessly, and the OS
/// prompt is only spent on someone who has already said yes here.
///
/// The preview above the copy is a real Recur alert rather than a generic
/// bell, because "turn on notifications" is an abstraction and "your MTN
/// charge lands tomorrow" is the actual offer.
class PushPermissionScreen extends StatelessWidget {
  const PushPermissionScreen({super.key, required this.onDecided});

  /// Called with whether the user opted in. The system prompt is not wired up
  /// yet — this screen records the intent and the request itself follows once
  /// push is set up. Either answer moves the flow on; neither can strand
  /// anyone here.
  final void Function(bool enabled) onDecided;

  void _decide(BuildContext context, {required bool enabled}) => onDecided(enabled);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _NotificationPreview(),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                'Turn on notifications',
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A heads-up before a charge lands, and a nudge before a free '
                'trial turns into a real bill. Nothing else.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.muted(context),
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 3),
              AppButton(
                label: 'Turn on notifications',
                size: AppButtonSize.lg,
                expand: true,
                onPressed: () => _decide(context, enabled: true),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Not now',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.lg,
                expand: true,
                onPressed: () => _decide(context, enabled: false),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'You can change this any time in Settings.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.muted(context)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two stacked cards, the front one carrying a notification this app would
/// actually send.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The one behind, peeking out to say there is more than one.
          Positioned(
            top: 0,
            child: Transform.scale(
              scale: 0.92,
              child: const Opacity(
                opacity: 0.55,
                child: _PreviewCard(
                  title: 'Showmax trial ends tomorrow',
                  body: 'Cancel before it turns into a real charge',
                ),
              ),
            ),
          ),
          Positioned(
            top: 34,
            child: _PreviewCard(
              title: 'MTN charges tomorrow',
              body: '${formatNaira(10000)} leaves your account',
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.lgBR,
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.mdBR,
            ),
            child: const Icon(Icons.notifications_rounded, size: 18, color: AppColors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
