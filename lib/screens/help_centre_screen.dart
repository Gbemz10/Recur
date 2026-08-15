import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Static FAQ screen. No backend, no CMS — just the questions people
/// actually ask about a bank-linked subscription tracker, answered plainly.
/// Content can move to a real CMS later if it ever needs to change more
/// often than an app release cycle allows.
class HelpCentreScreen extends StatelessWidget {
  const HelpCentreScreen({super.key});

  static const _faqs = [
    AppAccordionItem(
      title: 'How does Recur find my subscriptions?',
      content: Text(
        'Once your bank is linked, Recur reads your transaction history through '
        'Mono (a licensed Nigerian open banking provider) and looks for debits '
        'that repeat — the same amount, from the same merchant, on a roughly '
        'regular schedule. Two or more matching charges is enough to flag '
        'something as a likely subscription.',
        style: TextStyle(color: AppColors.neutral600, fontSize: 13.5, height: 1.5),
      ),
    ),
    AppAccordionItem(
      title: 'Is my bank information safe?',
      content: Text(
        'Recur never sees or stores your bank login details — that exchange '
        'happens entirely inside Mono\'s secure connection flow. Recur only '
        'receives read-only access to transaction data, never the ability to '
        'move money.',
        style: TextStyle(color: AppColors.neutral600, fontSize: 13.5, height: 1.5),
      ),
    ),
    AppAccordionItem(
      title: 'Can Recur move money or make payments?',
      content: Text(
        'No. Recur is read-only. It can see that a charge happened; it cannot '
        'initiate one, cancel one, or transfer funds. Cancelling a subscription '
        'always happens outside the app, with the merchant — Recur shows the '
        'steps where it can.',
        style: TextStyle(color: AppColors.neutral600, fontSize: 13.5, height: 1.5),
      ),
    ),
    AppAccordionItem(
      title: 'Why haven\'t my subscriptions shown up yet?',
      content: Text(
        'A newly linked account needs at least two matching charges before '
        'Recur is confident enough to flag something — a single Netflix debit '
        'looks the same as a one-off purchase until it repeats. If it\'s been a '
        'while, pull down to refresh on the Home or Calendar tab, or check '
        'that your bank connection is still marked "Connected" in Settings.',
        style: TextStyle(color: AppColors.neutral600, fontSize: 13.5, height: 1.5),
      ),
    ),
    AppAccordionItem(
      title: 'Can I link more than one bank account?',
      content: Text(
        'Yes — go to Settings and tap "Link another bank". Every linked '
        'account is scanned independently, and everything detected across all '
        'of them shows up together on your dashboard.',
        style: TextStyle(color: AppColors.neutral600, fontSize: 13.5, height: 1.5),
      ),
    ),
    AppAccordionItem(
      title: 'Recur flagged something that isn\'t a subscription',
      content: Text(
        'That happens — a recurring transfer to a friend or a regular rent '
        'payment can look like a subscription from the outside. Open it and '
        'tap "Not a subscription" to dismiss it; Recur won\'t flag that same '
        'pattern again.',
        style: TextStyle(color: AppColors.neutral600, fontSize: 13.5, height: 1.5),
      ),
    ),
    AppAccordionItem(
      title: 'How do I delete my account?',
      content: Text(
        'Settings → Data & privacy → Delete account. You\'ll need to confirm '
        'with your password. This permanently removes your linked banks, '
        'detected subscriptions, and everything else tied to your account — '
        'it can\'t be undone.',
        style: TextStyle(color: AppColors.neutral600, fontSize: 13.5, height: 1.5),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Help centre'),
        backgroundColor: AppColors.background(context),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
          children: [
            Text(
              'Common questions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: -0.4),
            ),
            const SizedBox(height: 4),
            Text(
              'Can\'t find what you need? Reach us directly from Settings → Contact support.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral500, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppAccordion(items: _faqs),
          ],
        ),
      ),
    );
  }
}
