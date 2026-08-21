import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../data/bank_store.dart';
import '../data/banks.dart';
import '../data/linked_bank.dart';
import '../data/profile_store.dart';
import '../data/subscription_store.dart';
import '../data/notification_store.dart';
import '../data/theme_controller.dart';
import '../ui/ui.dart';
import '../widgets/bank_logo.dart';
import '../widgets/brand_mark.dart';
import 'help_centre_screen.dart';
import 'link_bank_screen.dart';
import 'profile_screen.dart';

/// Settings: linked account, notification timing, and data controls.
///
/// Grouped the way the App Store review guidelines and most fintech apps
/// converge on independently — account first, then how the app talks to
/// you, then what it does with your data. Predictable structure matters
/// more than cleverness here; this is a screen people scan, not read.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.profileStore,
    required this.bankStore,
    required this.onSignOut,
  });

  final SubscriptionStore store;

  /// Shared with every other tab — see [ProfileStore]. Reading from this
  /// instead of fetching its own copy is what makes a photo changed on the
  /// Profile screen show up here immediately, even though `AppShell` keeps
  /// this tab alive in the background the whole time.
  final ProfileStore profileStore;

  /// Shared with every other tab — see [BankStore]. Same reasoning as
  /// [profileStore]: a bank linked or unlinked from anywhere shows up here
  /// without this tab needing to have been the one that did it.
  final BankStore bankStore;

  /// Called after the session token is cleared, so the root flow can send
  /// the user back to the auth screen.
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Server-backed, so a reminder preference set on one device is the one the
  /// job actually reads. These were local `setState` flags: the switches moved
  /// and nothing else in the system ever knew.
  final _notifications = NotificationStore();

  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    widget.profileStore.addListener(_handleStoreChange);
    widget.bankStore.addListener(_handleStoreChange);
    _notifications.addListener(_handleStoreChange);
  }

  /// Persists a preference change, putting the switch back if it does not
  /// stick. Silent success: a toast for every toggle is noise, but a toggle
  /// that quietly failed is a lie.
  Future<void> _saveNotifications({
    bool? renewalReminders,
    bool? weeklyDigest,
    int? reminderLeadDays,
  }) async {
    try {
      await _notifications.update(
        renewalReminders: renewalReminders,
        weeklyDigest: weeklyDigest,
        reminderLeadDays: reminderLeadDays,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Could not save that. Check your connection and try again.',
        variant: AppAlertVariant.danger,
      );
    }
  }

  @override
  void dispose() {
    _notifications.removeListener(_handleStoreChange);
    _notifications.dispose();
    widget.profileStore.removeListener(_handleStoreChange);
    widget.bankStore.removeListener(_handleStoreChange);
    super.dispose();
  }

  void _handleStoreChange() {
    if (mounted) setState(() {});
  }

  /// The curated [Banks] list only covers real CBN-registered institutions
  /// — Mono's sandbox test banks won't match, so this falls back to a
  /// generic mark rather than crashing on a missing lookup.
  Widget _linkedBankLogo(LinkedBank bank) {
    final known = Banks.byCode(bank.bankCode);
    if (known != null) return BankLogo(bank: known, size: 40);
    return BrandMark(
      slug: 'bank_unknown',
      fallbackLabel: bank.bankName.isEmpty ? 'Bank' : bank.bankName,
      brandColor: AppColors.neutral500,
      size: 40,
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need your email and password to sign back in.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (confirmed) {
      await AuthService.logout();
      if (mounted) widget.onSignOut();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final deleted = await showAppSheet<bool>(
      context,
      title: 'Delete your account?',
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (deleted == true) {
      // The account (and every refresh token tied to it) is already gone
      // server-side — this just clears local storage and best-effort tells
      // the server, same as a normal sign-out.
      await AuthService.logout();
      if (mounted) widget.onSignOut();
    }
  }

  Future<void> _openHelpCentre() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HelpCentreScreen()),
    );
  }

  Future<void> _contactSupport() async {
    final subject = Uri.encodeComponent('Recur support');
    final body = Uri.encodeComponent(
      'Tell us what\'s going on — the more detail, the faster we can help.\n\n'
      'Account email: ${widget.profileStore.profile?.email ?? ''}\n\n',
    );
    final uri = Uri.parse('mailto:support@recur.website?subject=$subject&body=$body');

    final launched = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!launched && mounted) {
      showAppSnackbar(
        context,
        message: 'No email app found — reach us directly at support@recur.website',
        variant: AppAlertVariant.warning,
      );
    }
  }

  /// Entry point for anyone who tapped "Not now" on the LinkBankScreen
  /// during onboarding (or unlinked their only bank since) — the flow
  /// itself already handles consent, the Mono webview, and the
  /// waiting/success/timeout states, so this just reuses it as a pushed
  /// route and refreshes once it's popped.
  Future<void> _linkBank() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkBankScreen(onDone: () => Navigator.of(context).pop()),
      ),
    );
    if (mounted) widget.bankStore.load();
  }

  Future<void> _unlinkBank(LinkedBank bank) async {
    // A deletion rather than a status change: the connection stops existing,
    // and getting it back means going through Mono's consent flow again.
    final confirmed = await showAppDeleteDialog(
      context,
      title: 'Unlink ${bank.bankName}?',
      message:
          'Recur stops reading new transactions. Subscriptions already detected stay in your history.',
      confirmLabel: 'Unlink',
    );
    if (!confirmed || !mounted) return;

    try {
      await widget.bankStore.unlink(bank);
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: '${bank.bankName} unlinked',
        variant: AppAlertVariant.success,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fixed header, matching every tab except Home. The explainer line under
    // the title is gone: "Manage your account, alerts, and data" only restates
    // the word Settings, and the sections below already name themselves.
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: -0.5),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.huge,
              ),
              children: [
                // ---- account ----
                Builder(
                  builder: (context) {
                    final profile = widget.profileStore.profile;
                    final loading = widget.profileStore.isInitialLoad;

                    return AppCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            store: widget.store,
                            profileStore: widget.profileStore,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (loading)
                            const ClipOval(child: AppSkeleton(width: 52, height: 52))
                          else
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: AppAvatar(
                                name: profile?.displayLabel ?? 'Account',
                                imageUrl: profile?.avatarUrl,
                                size: 48,
                              ),
                            ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.displayLabel ?? 'Loading…',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: AppColors.ink(context),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  profile?.email ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.muted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.muted(context)),
                        ],
                      ),
                    );
                  },
                ),

                _SectionLabel(
                    widget.bankStore.active.length > 1 ? 'Linked accounts' : 'Linked account'),
                if (widget.bankStore.isLoading && widget.bankStore.all.isEmpty)
                  const AppSkeletonListTile()
                else if (widget.bankStore.error != null && widget.bankStore.all.isEmpty) ...[
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            widget.bankStore.error!,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Try again',
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.sm,
                    expand: true,
                    onPressed: widget.bankStore.load,
                  ),
                ] else if (widget.bankStore.active.isEmpty) ...[
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, color: AppColors.neutral400),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'No bank connected yet',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Link bank account',
                    size: AppButtonSize.sm,
                    expand: true,
                    icon: Icons.link_rounded,
                    onPressed: _linkBank,
                  ),
                ] else ...[
                  // Each linked bank gets its own card and its own unlink action —
                  // the backend has always supported more than one, this is just
                  // the first Settings UI that shows more than the first one.
                  for (final bank in widget.bankStore.active) ...[
                    AppCard(
                      child: Row(
                        children: [
                          _linkedBankLogo(bank),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bank.isSyncing ? 'Syncing…' : bank.bankName,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink(context)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bank.accountNumberMask.isEmpty
                                      ? '•••• ••••'
                                      : bank.accountNumberMask,
                                  style: AppTypography.mono(
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: AppColors.muted(context)),
                                ),
                              ],
                            ),
                          ),
                          const AppBadge(
                              label: 'Connected', variant: AppBadgeVariant.success, dot: true),
                          const SizedBox(width: AppSpacing.sm),
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.link_off_rounded,
                                  size: 18, color: AppColors.neutral400),
                              tooltip: 'Unlink ${bank.bankName.isEmpty ? 'bank' : bank.bankName}',
                              onPressed: () => _unlinkBank(bank),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppButton(
                    label: 'Link another bank',
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.sm,
                    expand: true,
                    icon: Icons.add_link_rounded,
                    onPressed: _linkBank,
                  ),
                ],

                _SectionLabel('Appearance'),
                ListenableBuilder(
                  listenable: themeController,
                  builder: (context, _) => AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        for (final mode in AppThemeMode.values) ...[
                          Expanded(
                            child: _ThemeOptionChip(
                              icon: switch (mode) {
                                AppThemeMode.system => Icons.brightness_auto_rounded,
                                AppThemeMode.light => Icons.light_mode_rounded,
                                AppThemeMode.dark => Icons.dark_mode_rounded,
                              },
                              label: switch (mode) {
                                AppThemeMode.system => 'System',
                                AppThemeMode.light => 'Light',
                                AppThemeMode.dark => 'Dark',
                              },
                              selected: themeController.mode == mode,
                              onTap: () => themeController.setMode(mode),
                            ),
                          ),
                          if (mode != AppThemeMode.dark) const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ),

                _SectionLabel('Notifications'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ToggleRow(
                        icon: Icons.notifications_active_outlined,
                        title: 'Renewal reminders',
                        subtitle: 'A heads-up before a charge hits',
                        value: _notifications.renewalReminders,
                        onChanged: _notifications.isInitialLoad
                            ? null
                            : (v) => _saveNotifications(renewalReminders: v),
                      ),
                      if (_notifications.renewalReminders) ...[
                        Divider(height: 1, color: AppColors.border(context)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                          child: Row(
                            children: [
                              Text(
                                'Remind me',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.muted(context)),
                              ),
                              const Spacer(),
                              for (final d in [1, 3, 7]) ...[
                                _DayChip(
                                  days: d,
                                  selected: _notifications.reminderLeadDays == d,
                                  onTap: () => _saveNotifications(reminderLeadDays: d),
                                ),
                                if (d != 7) const SizedBox(width: AppSpacing.sm),
                              ],
                            ],
                          ),
                        ),
                      ],
                      Divider(height: 1, color: AppColors.border(context)),
                      _ToggleRow(
                        icon: Icons.mail_outline_rounded,
                        title: 'Weekly digest',
                        subtitle: 'A Monday email of what is coming up',
                        value: _notifications.weeklyDigest,
                        onChanged: _notifications.isInitialLoad
                            ? null
                            : (v) => _saveNotifications(weeklyDigest: v),
                      ),
                      Divider(height: 1, color: AppColors.border(context)),
                      _ToggleRow(
                        icon: Icons.phone_iphone_rounded,
                        title: 'Push notifications',
                        subtitle: 'Alerts on this device',
                        value: _pushEnabled,
                        onChanged: (v) => setState(() => _pushEnabled = v),
                      ),
                    ],
                  ),
                ),

                _SectionLabel('Data & privacy'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.download_outlined,
                        title: 'Export my data',
                        onTap: () => showAppSnackbar(
                          context,
                          message: 'We will email a copy of your data shortly',
                          variant: AppAlertVariant.success,
                        ),
                      ),
                      Divider(height: 1, color: AppColors.border(context)),
                      _NavRow(
                        icon: Icons.shield_outlined,
                        title: 'Privacy policy',
                        onTap: () {},
                      ),
                      Divider(height: 1, color: AppColors.border(context)),
                      _NavRow(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete account',
                        danger: true,
                        onTap: _confirmDeleteAccount,
                      ),
                    ],
                  ),
                ),

                _SectionLabel('Support'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _NavRow(
                          icon: Icons.help_outline_rounded,
                          title: 'Help centre',
                          onTap: _openHelpCentre),
                      Divider(height: 1, color: AppColors.border(context)),
                      _NavRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Contact support',
                          onTap: _contactSupport),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'Sign out',
                  variant: AppButtonVariant.outline,
                  expand: true,
                  icon: Icons.logout_rounded,
                  onPressed: _confirmSignOut,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'Recur v1.0.0',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted(context)),
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

/// Password-confirmed account deletion — a plain "are you sure" dialog
/// isn't enough friction for something this irreversible, so this asks for
/// the actual password, same as the backend requires (`DELETE /auth/me`).
/// Owns its own controller (same lifecycle reasoning as the profile
/// screen's edit sheets).
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _deleting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _deleting = true;
      _serverError = null;
    });
    try {
      await AuthService.deleteAccount(_password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _serverError = e.message;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 23),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'This permanently removes your linked bank connections and everything '
          'Recur has detected. This cannot be undone.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted(context), height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          controller: _password,
          label: 'Confirm your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          suffixIcon: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          onSuffixIconTap: () => setState(() => _obscure = !_obscure),
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
                onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Delete account',
                variant: AppButtonVariant.destructive,
                expand: true,
                isLoading: _deleting,
                onPressed: _deleting || _password.text.isEmpty ? null : _delete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.xxl, 4, AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.muted(context),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  /// Null disables the switch, which is what a row whose real value has not
  /// arrived yet should be: showing a default as though it were the user's
  /// own setting, and letting them toggle it, writes a preference they never
  /// chose.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.muted(context)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink(context))),
                const SizedBox(height: 1),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: AppColors.muted(context))),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow(
      {required this.icon, required this.title, required this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.inkSoft(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 19, color: danger ? AppColors.danger : AppColors.muted(context)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionChip extends StatelessWidget {
  const _ThemeOptionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : AppColors.muted(context)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.muted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.days, required this.selected, required this.onTap});

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.track(context),
          borderRadius: AppRadius.fullBR,
        ),
        child: Text(
          '${days}d',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.muted(context),
          ),
        ),
      ),
    );
  }
}
