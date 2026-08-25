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
    //
    // Deferred to after this frame rather than called directly: `load()`
    // calls `notifyListeners()` synchronously before its first `await`, and
    // this runs inside `initState`, which itself runs while the framework
    // is still building the widget tree (this screen is being pushed). A
    // synchronous notify at that point reaches every other listener of the
    // same shared ProfileStore — including DashboardScreen, which is kept
    // alive in AppShell's IndexedStack — and its `setState` call lands
    // mid-build, which Flutter throws on ("setState() or markNeedsBuild()
    // called during build"). Waiting for the post-frame callback lets this
    // screen finish mounting first, so the notify lands in a safe window.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.profileStore.load();
    });
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
    if (updated == null) return;
    widget.profileStore.setProfile(updated);
    showAppSnackbar(context, message: 'Photo updated', variant: AppAlertVariant.success);
  }

  /// Single entry point for "change anything about who I am" — both the
  /// "Full name" row and the "Edit profile" button open this, so there's
  /// one place that edits identity instead of the name field, the photo,
  /// and a button that only did one of those all pointing different ways.
  Future<void> _openEditProfile() async {
    final profile = widget.profileStore.profile;
    if (profile == null) return;

    final updated = await showAppSheet<Profile>(
      context,
      title: 'Edit profile',
      builder: (_) => _EditProfileSheet(profile: profile),
    );
    if (updated == null || !mounted) return;
    widget.profileStore.setProfile(updated);
    showAppSnackbar(context, message: 'Profile updated', variant: AppAlertVariant.success);
  }

  Future<void> _openChangePassword() async {
    final changed = await showAppSheet<bool>(
      context,
      title: 'Change password',
      inset: true,
      showClose: true,
      closeResult: false,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true && mounted) {
      // A dialog rather than a toast: this is final, it cannot be undone from
      // here, and it signed the user out everywhere else. That last part is a
      // consequence worth being certain they saw, and a toast three seconds
      // long is exactly the wrong instrument for it.
      await showAppSuccessDialog(
        context,
        title: 'Password changed',
        message: 'Anywhere else you were signed in has been signed out. '
            'You will need the new password there.',
      );
    }
  }

  String _memberSinceLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
    final cancelled = widget.store.byStatus(SubscriptionStatus.cancelled);
    final active = widget.store.byStatus(SubscriptionStatus.active).length;
    final saved = cancelled.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);
    final profile = widget.profileStore.profile;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed custom header, like every other screen in the app. The
            // stock AppBar this used made Profile the one place that looked
            // like a different product.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  _BackButton(onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.profileStore.isInitialLoad
                  ? const Center(child: AppLoadingIndicator())
                  : profile == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Couldn't load your profile",
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppButton(
                                  label: 'Try again',
                                  onPressed: widget.profileStore.load,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.sm,
                            AppSpacing.xl,
                            AppSpacing.huge,
                          ),
                          children: [
                            _IdentityHero(
                              profile: profile,
                              memberSince: _memberSinceLabel(profile.memberSince),
                              uploading: _uploadingPhoto,
                              onChangePhoto: _quickChangePhoto,
                            ),
                            const SizedBox(height: AppSpacing.xxl),

                            // Only once there is something true to say. The
                            // strip this replaced always rendered, so a new
                            // account was met with "₦0 saved" — a number whose
                            // only job is to report that nothing has happened.
                            if (active > 0 || cancelled.isNotEmpty) ...[
                              _StatStrip(
                                active: active,
                                cancelled: cancelled.length,
                                savedMonthly: saved,
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                            ],

                            // Actions, not facts. The name and the email used
                            // to be listed again here under "Your details",
                            // directly below the block already showing both.
                            const _SectionLabel('Account'),
                            AppCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  _EditableRow(
                                    label: 'Name',
                                    value: profile.displayName ?? 'Not set',
                                    onTap: _openEditProfile,
                                  ),
                                  Divider(height: 1, color: AppColors.border(context)),
                                  _EditableRow(
                                    label: 'Password',
                                    value: '••••••••',
                                    onTap: _openChangePassword,
                                  ),
                                ],
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

/// Small caps section heading, matching Settings.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.mono(
          size: 10.5,
          weight: FontWeight.w700,
          color: AppColors.muted(context),
        ).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

/// Who you are, as one block.
///
/// The old version stacked a centred avatar, name, email and a pill, then
/// The account, said once and said large.
///
/// Centred, because there is one subject on this screen and it is you: a photo
/// you came here to change, the name the app greets you by, and the address
/// the account is keyed to. The facts that used to sit in a sentence under a
/// divider are a chip now, which is enough weight for "joined in August".
class _IdentityHero extends StatelessWidget {
  const _IdentityHero({
    required this.profile,
    required this.memberSince,
    required this.uploading,
    required this.onChangePhoto,
  });

  final Profile profile;
  final String memberSince;
  final bool uploading;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: AppAvatar(
                name: profile.displayLabel,
                imageUrl: profile.avatarUrl,
                size: 96,
              ),
            ),
            if (uploading)
              const Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                  ),
                ),
              ),
            Positioned(
              right: 2,
              bottom: 4,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: uploading ? null : onChangePhoto,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background(context), width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          profile.displayLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            height: 1.15,
            color: AppColors.ink(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profile.email,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.5, color: AppColors.muted(context)),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.track(context),
            borderRadius: AppRadius.fullBR,
          ),
          child: Text(
            memberSince,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Three numbers, and only the ones that are true.
///
/// Saved earns a tile once anything has been cancelled; before that it would
/// be a zero pretending to be a result.
class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.active,
    required this.cancelled,
    required this.savedMonthly,
  });

  final int active;
  final int cancelled;
  final double savedMonthly;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatTile(value: '$active', label: active == 1 ? 'Tracking' : 'Tracking'),
      if (cancelled > 0) _StatTile(value: '$cancelled', label: 'Cancelled'),
      if (savedMonthly > 0)
        _StatTile(value: formatNairaCompact(savedMonthly), label: 'Saved a month'),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              SizedBox(
                height: 34,
                child: VerticalDivider(width: 1, color: AppColors.border(context)),
              ),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.ink(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
        ),
      ],
    );
  }
}

/// Shared by the header's camera badge and the edit sheet — both change the
/// same photo, so they run the same picker and upload.
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
    return await ProfileService.uploadAvatar(
        bytes: bytes, filename: picked.name, mimeType: mimeType);
  } on ApiException catch (e) {
    if (!context.mounted) return null;
    showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    return null;
  }
}

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  bool _obscure = true;
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _current.addListener(() => setState(() {}));
    _next.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  String get _newValue => _next.text;
  bool get _longEnough => _newValue.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_newValue);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newValue);
  bool get _valid => _current.text.isNotEmpty && _longEnough && _hasLetter && _hasNumber;

  Future<void> _save() async {
    setState(() {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Signing in on other devices will need this new password.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
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
        const SizedBox(height: AppSpacing.md),
        // The same line the signup screen uses, and no confirm box: the eye
        // control shows the characters, which catches a typo better than
        // asking someone to reproduce it.
        AppPasswordRules(
          longEnough: _longEnough,
          hasLetter: _hasLetter,
          hasNumber: _hasNumber,
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
        AppButton(
          label: 'Update password',
          size: AppButtonSize.lg,
          expand: true,
          isLoading: _saving,
          onPressed: _saving || !_valid ? null : _save,
        ),
      ],
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
            child: Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.muted(context))),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink(context)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted(context)),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, child: row));
  }
}

/// The circle the auth screens use, so Profile's header matches the rest of
/// the app rather than being the one place with a bare Material icon button.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.track(context),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink(context)),
        ),
      ),
    );
  }
}
