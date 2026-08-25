import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../ui/ui.dart';

/// Password creation, shown after the emailed code has been verified.
///
/// One field, not two. A confirm box exists to catch a typo you cannot see,
/// and the eye control already solves that — better, because it shows you the
/// actual characters instead of asking you to reproduce the same mistake
/// twice. Typing a long password a second time is also where people give up.
///
/// The requirements are stated up front and strike through as they're met,
/// rather than being revealed as errors after a failed submit. Telling
/// someone their password is wrong only once they've committed to it is a
/// pointless bit of cruelty, and it's the main reason people abandon signup
/// forms.
///
/// The rules themselves are deliberately modest — length does more for
/// security than forcing a symbol, and heavy-handed composition rules push
/// people towards `Password1!` and a sticky note.
class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({
    super.key,
    required this.email,
    this.isReset = false,
  });

  final String email;

  /// Reset flow reached via "forgot password" rather than initial signup.
  final bool isReset;

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
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

  String get _value => _password.text;

  bool get _longEnough => _value.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_value);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_value);

  bool get _valid => _longEnough && _hasLetter && _hasNumber;

  /// 0–3. Deliberately coarse: a precise-looking strength meter implies a
  /// precision it doesn't have.
  int get _strength {
    if (_value.isEmpty) return 0;
    var score = 0;
    if (_value.length >= 8) score++;
    if (_value.length >= 12) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(_value)) score++;
    if (_hasLetter && _hasNumber && _value.length >= 10) score++;
    return score.clamp(0, 3);
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    // The button is disabled until this holds, so this is a guard rather than
    // a branch anyone reaches.
    if (!_valid) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await AuthService.setPassword(email: widget.email, password: _value, isReset: widget.isReset);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      // The footer sits on the keyboard rather than behind it — same as the
      // email and code screens.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, 0, 0),
                child: _BackButton(onPressed: () => Navigator.of(context).pop(false)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isReset ? 'Set a new password' : 'Create your password',
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        controller: _password,
                        label: 'Choose a password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        suffixIcon:
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixIconTap: () => setState(() => _obscure = !_obscure),
                      ),
                      if (_value.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _StrengthMeter(strength: _strength),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppPasswordRules(
                        longEnough: _longEnough,
                        hasLetter: _hasLetter,
                        hasNumber: _hasNumber,
                      ),
                      if (_serverError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 15, color: AppColors.danger),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _serverError!,
                                style: text.bodySmall?.copyWith(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: AppButton(
                  label: widget.isReset ? 'Update password' : 'Done',
                  size: AppButtonSize.lg,
                  expand: true,
                  isLoading: _busy,
                  onPressed: _busy || !_valid ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circle the email and code screens use.
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

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});

  final int strength;

  static const _labels = ['Too weak', 'Weak', 'Good', 'Strong'];
  static const _colors = [
    AppColors.danger,
    AppColors.warning,
    AppColors.info,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[strength];

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 4,
              decoration: BoxDecoration(
                color: i < strength ? color : AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: 5),
        ],
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 62,
          child: Text(
            _labels[strength],
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
