import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/trial_store.dart';
import '../models/trial.dart';
import '../ui/ui.dart';

/// The Trials tab: every free trial the user has manually logged, grouped
/// by urgency, plus the entry point for adding a new one.
///
/// A trial gets its own destination rather than living inside Settings or a
/// dashboard drawer because it's time-sensitive in a way account settings
/// never are — the whole point is catching it before a specific date, and
/// a screen you have to remember to dig for defeats that.
class TrialRemindersScreen extends StatefulWidget {
  const TrialRemindersScreen({super.key, required this.store});

  final TrialStore store;

  @override
  State<TrialRemindersScreen> createState() => _TrialRemindersScreenState();
}

class _TrialRemindersScreenState extends State<TrialRemindersScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_handleStoreChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_handleStoreChange);
    super.dispose();
  }

  void _handleStoreChange() {
    if (mounted) setState(() {});
  }

  Future<void> _addReminder() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTrialReminderSheet(store: widget.store),
    );
  }

  Future<void> _dismiss(TrialReminder trial) async {
    try {
      await widget.store.dismiss(trial);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.isLoading) {
      return const SafeArea(bottom: false, child: Center(child: AppLoadingIndicator()));
    }

    final trials = widget.store.upcoming;

    // A failed fetch and a genuinely empty list both leave `trials` empty —
    // without this check they'd render identically, and a real failure
    // would look exactly like "you have nothing to track" with no way to
    // tell the difference or retry.
    if (widget.store.error != null && trials.isEmpty) {
      return SafeArea(
        bottom: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Couldn't load your trial reminders", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                AppButton(label: 'Try again', onPressed: widget.store.load),
              ],
            ),
          ),
        ),
      );
    }

    // Nothing tracked yet: the screen's only job is telling the user what
    // this tab is for and getting them to add the first one — centered,
    // not pinned under a header the way a populated list needs one.
    if (trials.isEmpty) {
      return SafeArea(
        bottom: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: AppEmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No trials being tracked',
              message: 'Log a trial the moment you sign up, so nothing '
                  'converts to a real charge without you noticing.',
              actionLabel: 'Add a trial reminder',
              onAction: _addReminder,
            ),
          ),
        ),
      );
    }

    // Once there's real content, the screen is just that content — the
    // bottom nav already says "Trials", so a repeated headline plus an
    // explainer paragraph above the list would be re-introducing itself to
    // someone who's already here. Adding another one moves to a floating
    // button instead of competing with the list for the top of the screen.
    final endingSoon = trials.where((t) => t.isDueSoon || t.isOverdue).toList();
    final tracking = trials.where((t) => !t.isDueSoon && !t.isOverdue).toList();

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.huge,
            ),
            children: [
              if (endingSoon.isNotEmpty) ...[
                _sectionHeader(context, 'Ending soon', '${endingSoon.length}'),
                _list(endingSoon),
              ],
              if (tracking.isNotEmpty) ...[
                _sectionHeader(context, 'Tracking', '${tracking.length}'),
                _list(tracking),
              ],
            ],
          ),
          Positioned(
            right: AppSpacing.xl,
            bottom: AppSpacing.xl,
            child: _AddTrialFab(onPressed: _addReminder),
          ),
        ],
      ),
    );
  }

  /// Mirrors `dashboard_screen.dart`'s `_sectionHeader` exactly — same
  /// small-caps label, count pill, and trailing divider — so a list group
  /// reads the same whether it's subscriptions on Home or trials here.
  Widget _sectionHeader(BuildContext context, String label, String count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: AppRadius.fullBR,
            ),
            child: Text(
              count,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.neutral500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Divider(color: AppColors.neutral200)),
        ],
      ),
    );
  }

  Widget _list(List<TrialReminder> items) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _TrialReminderCard(trial: items[i], onDismiss: () => _dismiss(items[i])),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Bottom-right floating action button for adding another trial once the
/// list already has content. Hand-rolled rather than `Scaffold.
/// floatingActionButton` — this screen is one tab inside `AppShell`'s
/// single `Scaffold` (the `IndexedStack` body), not its own `Scaffold`, so
/// the button is just a `Positioned` layer over the list instead.
class _AddTrialFab extends StatelessWidget {
  const _AddTrialFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _TrialReminderCard extends StatelessWidget {
  const _TrialReminderCard({required this.trial, required this.onDismiss});

  final TrialReminder trial;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final urgent = trial.isDueSoon || trial.isOverdue;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: urgent ? AppColors.warningBg : AppColors.infoBg,
              borderRadius: AppRadius.mdBR,
            ),
            child: Icon(
              Icons.hourglass_bottom_rounded,
              size: 18,
              color: urgent ? AppColors.warning : AppColors.info,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trial.label,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  trial.endsLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: urgent ? AppColors.warning : AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.neutral400),
              tooltip: 'Dismiss reminder',
              onPressed: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet form for logging a new trial. Owns its own controller and
/// date state — same lifecycle shape as settings_screen.dart's
/// `_DeleteAccountSheet`.
class _AddTrialReminderSheet extends StatefulWidget {
  const _AddTrialReminderSheet({required this.store});

  final TrialStore store;

  @override
  State<_AddTrialReminderSheet> createState() => _AddTrialReminderSheetState();
}

class _AddTrialReminderSheetState extends State<_AddTrialReminderSheet> {
  final TextEditingController _label = TextEditingController();
  DateTime _trialEndsAt = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _label.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      title: 'Trial ends',
      initialDate: _trialEndsAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _trialEndsAt = picked);
  }

  Future<void> _submit() async {
    if (_label.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      await widget.store.addTrialReminder(label: _label.text.trim(), trialEndsAt: _trialEndsAt);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = e.message;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hourglass_bottom_rounded, color: AppColors.warning, size: 28),
            const SizedBox(height: AppSpacing.md),
            Text('Add a trial reminder', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We will show this on your dashboard as the end date gets close.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral600, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _label,
              label: 'What is it?',
              hint: 'e.g. Netflix Premium',
              prefixIcon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Trial ends', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.neutral500),
                      const SizedBox(width: AppSpacing.md),
                      Text(_formatDate(_trialEndsAt), style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _serverError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.ghost,
                    expand: true,
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Add reminder',
                    expand: true,
                    isLoading: _saving,
                    onPressed: _saving || _label.text.trim().isEmpty ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
