import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../ui/ui.dart';
import '../widgets/recur_logo.dart';
import 'create_password_screen.dart';
import 'otp_screen.dart';

/// Sign in and sign up, on one screen with an explicit mode switch.
///
/// Email only, on purpose. SMS costs money per send, which turns an
/// unauthenticated OTP endpoint into a way for someone to run up a bill, and
/// Nigerian SMS delivery is unreliable enough that "I never got the code"
/// becomes a standing support burden. Email is free to send and it arrives.
///
/// Sign up is email → emailed code → set a password. The code proves the
/// address is real before we let anyone attach a bank account to it; the
/// password is what they use from then on, so we're not emailing a code
/// every single time they open the app.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { signUp, signIn }

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  _Mode _mode = _Mode.signUp;
  bool _obscure = true;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _email.addListener(_clearErrors);
    _password.addListener(_clearErrors);
  }

  void _clearErrors() {
    if (_emailError != null || _passwordError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  /// Lowercased, so the same person typing Gbemiga@… and gbemiga@… doesn't
  /// end up with two accounts.
  String get _normalisedEmail => _email.text.trim().toLowerCase();

  Future<void> _submit() async {
    if (!_emailValid) {
      setState(() => _emailError = 'That does not look like an email address');
      return;
    }
    if (_mode == _Mode.signIn && _password.text.isEmpty) {
      setState(() => _passwordError = 'Enter your password');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      if (_mode == _Mode.signIn) {
        await AuthService.login(email: _normalisedEmail, password: _password.text);
        if (!mounted) return;
        setState(() => _busy = false);
        widget.onAuthenticated();
        return;
      }

      // Sign up: request a code, verify it, then set a password.
      await AuthService.signup(_normalisedEmail);
      if (!mounted) return;
      setState(() => _busy = false);

      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: _normalisedEmail, isReset: false),
        ),
      );
      if (verified != true || !mounted) return;

      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CreatePasswordScreen(email: _normalisedEmail, isReset: false),
        ),
      );
      if (done == true) widget.onAuthenticated();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // Sign-in failures land on the password field (most likely cause is
      // a wrong password); signup failures (e.g. email already taken) get
      // a snackbar since there's no single field to blame.
      if (_mode == _Mode.signIn) {
        setState(() => _passwordError = e.message);
      } else {
        showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (!_emailValid) {
      setState(() => _emailError = 'Enter your email first');
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.forgotPassword(_normalisedEmail);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpScreen(email: _normalisedEmail, isReset: true),
      ),
    );
    if (verified != true || !mounted) return;

    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePasswordScreen(
          email: _normalisedEmail,
          isReset: true,
        ),
      ),
    );
    if (done == true && mounted) {
      showAppSnackbar(
        context,
        message: 'Password updated',
        variant: AppAlertVariant.success,
      );
      setState(() => _mode = _Mode.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Forces the light theme regardless of the user's actual dark/light
    // preference — this screen, like the rest of the pre-auth flow, is
    // deliberately light-only always (see _RootFlow in main.dart). Without
    // this, the Scaffold's own background stayed hardcoded white while
    // every Theme.of(context) lookup inside it (this method's own `text`,
    // plus every AppButton/AppTextField instance below) still followed the
    // app's real theme — so with dark mode on, near-white text rendered on
    // that white background, and AppTextField's dark-mode fill color
    // painted the input boxes black. Wrapping in a fresh Builder means
    // every Theme.of(context) call below this point resolves against this
    // forced-light Theme instead.
    return Theme(
      data: AppTheme.light,
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          final signUp = _mode == _Mode.signUp;

          return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                const RecurWordmark(),
                const SizedBox(height: AppSpacing.xxxl),

                Text(
                  signUp ? 'Create your account' : 'Welcome back',
                  style: text.headlineSmall?.copyWith(letterSpacing: -0.4),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  signUp
                      ? 'We will email you a 6-digit code to confirm it is '
                          'you, then you pick a password.'
                      : 'Sign in to pick up where you left off.',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.neutral600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                AppTextField(
                  controller: _email,
                  label: 'Email address',
                  hint: 'you@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),

                if (!signUp) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _password,
                    label: 'Password',
                    hint: 'Your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscure,
                    suffixIcon: _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onSuffixIconTap: () =>
                        setState(() => _obscure = !_obscure),
                    errorText: _passwordError,
                  ),
                  // Sits tight under the field it belongs to. A full ghost
                  // button here floated it away from the password input and
                  // read as a second primary action.
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _forgotPassword,
                      // Padding is the tap target, not visual spacing, so
                      // the label still looks snug against the field.
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: signUp ? 'Send me a code' : 'Sign in',
                  size: AppButtonSize.lg,
                  expand: true,
                  isLoading: _busy,
                  onPressed: _busy ? null : _submit,
                ),

                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        signUp
                            ? 'Already have an account?'
                            : 'New to Recur?',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.neutral500),
                      ),
                      AppButton(
                        label: signUp ? 'Sign in' : 'Create one',
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        onPressed: () => setState(() {
                          _mode = signUp ? _Mode.signIn : _Mode.signUp;
                          _password.clear();
                          _emailError = null;
                          _passwordError = null;
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: AppColors.neutral400,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Recur never stores your bank password and can never '
                        'move money out of your account.',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.neutral500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
          );
        },
      ),
    );
  }
}
