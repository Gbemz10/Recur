import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../ui/ui.dart';

/// Password creation, shown after the emailed code has been verified.
///
/// The requirements are listed up front and tick live as they're met,
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
  final TextEditingController _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  bool _submitted = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _value => _password.text;

  bool get _longEnough => _value.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_value);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_value);
  bool get _matches => _value.isNotEmpty && _value == _confirm.text;

  bool get _valid => _longEnough && _hasLetter && _hasNumber && _matches;

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
    setState(() {
      _submitted = true;
      _serverError = null;
    });
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
    final confirmError =
        _submitted && !_matches && _confirm.text.isNotEmpty ? 'Passwords do not match' : null;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            0,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isReset ? 'Set a new password' : 'Choose a password',
                style: text.headlineSmall?.copyWith(letterSpacing: -0.4),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.muted(context),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'This is how you will sign in to '),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink(context),
                      ),
                    ),
                    const TextSpan(text: ' from now on.'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                controller: _password,
                label: 'Password',
                hint: 'At least 8 characters',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffixIcon: _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                onSuffixIconTap: () => setState(() => _obscure = !_obscure),
              ),
              if (_value.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _StrengthMeter(strength: _strength),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                hint: 'Type it again',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                errorText: confirmError,
              ),
              const SizedBox(height: AppSpacing.xl),
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
                        style: text.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: widget.isReset ? 'Update password' : 'Finish setup',
                size: AppButtonSize.lg,
                expand: true,
                isLoading: _busy,
                onPressed: _busy || !_valid ? null : _submit,
              ),
            ],
          ),
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
              color:
                  met ? AppColors.success : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              met ? Icons.check_rounded : Icons.remove_rounded,
              size: 11,
              color: met ? Colors.white : AppColors.muted(context),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: met ? AppColors.inkSoft(context) : AppColors.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}
