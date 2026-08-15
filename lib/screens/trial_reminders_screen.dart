import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/trial_store.dart';
import '../models/trial.dart';
import '../ui/ui.dart';

/// Full list of manually-entered trial reminders, plus the entry point for
/// adding a new one. Reached from Settings, and from the dashboard's
/// attention strip when something is genuinely close to converting.
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
    final text = Theme.of(context).textTheme;
    final trials = widget.store.upcoming;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: const Text('Trial reminders')),
      body: SafeArea(
        child: widget.store.isLoading
            ? const Center(child: AppLoadingIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(
                    'Log a free trial the moment you sign up. We will surface '
                    'it here as the end date gets close, so you can cancel '
                    'before it converts to a real charge.',
                    style: text.bodySmall?.copyWith(color: AppColors.neutral500, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Add a trial reminder',
                    icon: Icons.add_rounded,
                    expand: true,
                    onPressed: _addReminder,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (trials.isEmpty)
                    const AppEmptyState(
                      icon: Icons.hourglass_empty_rounded,
                      title: 'No trial reminders yet',
                      message: 'Add one right after you sign up somewhere new.',
                    )
                  else
                    for (var i = 0; i < trials.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _TrialReminderCard(
                        trial: trials[i],
                        onDismiss: () => _dismiss(trials[i]),
                      ),
                    ],
                ],
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
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: trial.isDueSoon ? AppColors.warningBg : AppColors.infoBg,
              borderRadius: AppRadius.mdBR,
            ),
            child: Icon(
              Icons.hourglass_bottom_rounded,
              size: 18,
              color: trial.isDueSoon ? AppColors.warning : AppColors.info,
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
                    color: trial.isDueSoon ? AppColors.warning : AppColors.neutral500,
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
    final picked = await showDatePicker(
      context: context,
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
