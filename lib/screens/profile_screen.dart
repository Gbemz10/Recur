import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../data/mock_data.dart' show formatNairaCompact;
import '../data/profile.dart';
import '../data/profile_service.dart';
import '../data/profile_store.dart';
import '../data/subscription_store.dart';
import '../models/subscription.dart';
import '../ui/ui.dart';

/// Personal profile: identity, membership, and a quick summary of what
/// Recur has done for the account so far.
///
/// Reachable from the dashboard avatar and from Settings — both are valid
/// entry points to "who am I signed in as", so both should land here
/// rather than on two different half-built screens.
///
/// The screen fetches `GET /auth/me` on open — name and photo are real,
/// server-stored fields now rather than hardcoded strings, so there's
/// necessarily a round trip before they're known. It's the same reason the
/// dashboard and Settings both show a brief loading state before their
/// numbers appear.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.store, required this.profileStore});

  /// Shared store, so stats here stay correct if something changes status
  /// while this screen happens to still be on the stack.
  final SubscriptionStore store;

  /// Shared with every other tab — see [ProfileStore]. Edits made here
  /// (name, photo) go through this store rather than local state, so the
  /// dashboard header and Settings' account card pick them up immediately,
  /// even though `AppShell` keeps both of those tabs alive in the
  /// background the whole time this screen is open.
  final ProfileStore profileStore;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    widget.profileStore.addListener(_handleProfileChange);
    // Always reached with a profile already loaded (every entry point sits
    // behind AppShell, which loads this on startup) — this is a background
    // refresh for "did anything change on another device", not the first
    // load, so it never needs its own loading flash.
    widget.profileStore.load();
  }

  @override
  void dispose() {
    widget.profileStore.removeListener(_handleProfileChange);
    super.dispose();
  }

  void _handleProfileChange() {
    if (mounted) setState(() {});
  }

  Future<void> _quickChangePhoto() async {
    setState(() => _uploadingPhoto = true);
    final updated = await pickAndUploadAvatar(context);
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    if (updated != null) widget.profileStore.setProfile(updated);
  }

  /// Single entry point for "change anything about who I am" — both the
  /// "Full name" row and the "Edit profile" button open this, so there's
  /// one place that edits identity instead of the name field, the photo,
  /// and a button that only did one of those all pointing different ways.
  Future<void> _openEditProfile() async {
    final profile = widget.profileStore.profile;
    if (profile == null) return;

    final updated = await showModalBottomSheet<Profile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: profile),
    );
    if (updated == null || !mounted) return;
    widget.profileStore.setProfile(updated);
  }

  Future<void> _openChangePassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true && mounted) {
      showAppSnackbar(
        context,
        message: 'Password changed. Other signed-in devices have been signed out.',
        variant: AppAlertVariant.success,
      );
    }
  }

  String _memberSinceLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Member since ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final active = widget.store.byStatus(SubscriptionStatus.active).length;
    final cancelled = widget.store.byStatus(SubscriptionStatus.cancelled).length;
    final saved = widget.store
        .byStatus(SubscriptionStatus.cancelled)
        .fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

    final profile = widget.profileStore.profile;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: widget.profileStore.isInitialLoad
            ? const Center(child: AppLoadingIndicator())
            : profile == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Couldn't load your profile", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(label: 'Try again', onPressed: widget.profileStore.load),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                AppAvatar(name: profile.displayLabel, imageUrl: profile.avatarUrl, size: 88),
                                if (_uploadingPhoto)
                                  const SizedBox(
                                    width: 88,
                                    height: 88,
                                    child: Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Material(
                                    color: AppColors.primary,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _uploadingPhoto ? null : _quickChangePhoto,
                                      child: const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              profile.displayLabel,
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink(context)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile.email,
                              style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppBadge(label: _memberSinceLabel(profile.memberSince), variant: AppBadgeVariant.neutral),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // ---- quick stats ----
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Active',
                              value: '$active',
                              icon: Icons.autorenew_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatTile(
                              label: 'Cancelled',
                              value: '$cancelled',
                              icon: Icons.do_not_disturb_on_outlined,
                              color: AppColors.neutral500,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _StatTile(
                              label: 'Saved / mo',
                              value: formatNairaCompact(saved),
                              icon: Icons.trending_down_rounded,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xxl),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _EditableRow(label: 'Full name', value: profile.displayName ?? 'Not set', onTap: _openEditProfile),
                            const Divider(height: 1, color: AppColors.neutral100),
                            _EditableRow(label: 'Email address', value: profile.email),
                            const Divider(height: 1, color: AppColors.neutral100),
                            _EditableRow(label: 'Password', value: '••••••••', onTap: _openChangePassword),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Edit profile',
                        variant: AppButtonVariant.outline,
                        expand: true,
                        icon: Icons.edit_outlined,
                        onPressed: _openEditProfile,
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Picks a gallery image and uploads it, centralizing the error handling so
/// a native-plugin-not-registered failure (the "photo library" error you
/// get if the app is still running from before `image_picker` was added —
/// hot reload/restart doesn't re-link new native plugins, only a full stop
/// and `flutter run` does) reads as an actionable message instead of a
/// generic one. Returns the updated [Profile] on success, null otherwise —
/// callers just no-op on null since a snackbar has already explained why.
Future<Profile?> pickAndUploadAvatar(BuildContext context) async {
  final picker = ImagePicker();
  final XFile? picked;
  try {
    picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
  } catch (e) {
    if (!context.mounted) return null;
    final message = e.toString().contains('MissingPluginException')
        ? "Photo picker isn't loaded yet — fully stop the app and run it again (not hot reload/restart) so the new plugin registers."
        : "Couldn't open your photo library";
    showAppSnackbar(context, message: message, variant: AppAlertVariant.danger);
    return null;
  }
  if (picked == null || !context.mounted) return null;

  final mimeType = switch (picked.name.split('.').last.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  try {
    final bytes = await picked.readAsBytes();
    return await ProfileService.uploadAvatar(bytes: bytes, filename: picked.name, mimeType: mimeType);
  } on ApiException catch (e) {
    if (!context.mounted) return null;
    showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    return null;
  }
}

/// Combined name + photo editor — the one place "who am I" gets changed,
/// rather than splitting photo (camera badge) and name (a bare text field)
/// across two disconnected interactions.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final Profile profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late Profile _profile;
  bool _uploadingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _nameController = TextEditingController(text: widget.profile.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    setState(() => _uploadingPhoto = true);
    final updated = await pickAndUploadAvatar(context);
    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (updated != null) _profile = updated;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackbar(context, message: 'Enter a name first', variant: AppAlertVariant.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await ProfileService.updateDisplayName(name);
      if (!mounted) return;
      // The name update response reflects the latest name but was computed
      // server-side before any photo change in this sheet — merge so a
      // photo swapped earlier in this same session isn't clobbered.
      Navigator.of(context).pop(Profile(
        id: updated.id,
        email: updated.email,
        displayName: updated.displayName,
        avatarUrl: _profile.avatarUrl,
        memberSince: updated.memberSince,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    }
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
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Stack(
                children: [
                  AppAvatar(name: _profile.displayLabel, imageUrl: _profile.avatarUrl, size: 72),
                  if (_uploadingPhoto)
                    const SizedBox(
                      width: 72,
                      height: 72,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploadingPhoto ? null : _changePhoto,
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppTextField(
              label: 'Name',
              hint: 'Your name',
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Save',
              expand: true,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Change-password sheet, reached from the Profile screen's "Password" row.
/// Owns its own controllers (same lifecycle fix as `_EditProfileSheet` —
/// disposing a controller from the parent after `await showModalBottomSheet`
/// returns is fragile) and mirrors the requirement checklist from
/// `CreatePasswordScreen` so the rules are visible up front rather than
/// discovered via a rejected submit.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _obscure = true;
  bool _submitted = false;
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _current.addListener(() => setState(() {}));
    _next.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _newValue => _next.text;
  bool get _longEnough => _newValue.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_newValue);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newValue);
  bool get _matches => _newValue.isNotEmpty && _newValue == _confirm.text;
  bool get _valid => _current.text.isNotEmpty && _longEnough && _hasLetter && _hasNumber && _matches;

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (!_valid) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await AuthService.changePassword(currentPassword: _current.text, newPassword: _newValue);
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

  @override
  Widget build(BuildContext context) {
    final confirmError = _submitted && !_matches && _confirm.text.isNotEmpty ? 'Passwords do not match' : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change password', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Signing in on other devices will need this new password.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral500),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _current,
                label: 'Current password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffixIcon: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                onSuffixIconTap: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _next,
                label: 'New password',
                hint: 'At least 8 characters',
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: _obscure,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _confirm,
                label: 'Confirm new password',
                hint: 'Type it again',
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: _obscure,
                errorText: confirmError,
              ),
              const SizedBox(height: AppSpacing.lg),
              _Requirement(met: _longEnough, label: 'At least 8 characters'),
              _Requirement(met: _hasLetter, label: 'Contains a letter'),
              _Requirement(met: _hasNumber, label: 'Contains a number'),
              _Requirement(met: _matches, label: 'Both entries match'),
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
              AppButton(
                label: 'Update password',
                expand: true,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Local copy of the same checklist row used in `CreatePasswordScreen` —
/// Dart's `_`-privacy is per-file, not per-feature, so it can't be shared
/// directly without promoting it to a public widget in `ui/`.
class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: met ? AppColors.success : AppColors.neutral100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              met ? Icons.check_rounded : Icons.remove_rounded,
              size: 11,
              color: met ? Colors.white : AppColors.neutral400,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: met ? AppColors.neutral700 : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.mono(size: 15, weight: FontWeight.w600, color: AppColors.ink(context))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.neutral500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.neutral500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink(context)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.neutral400),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, child: row));
  }
}
