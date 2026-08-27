import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../ui/ui.dart';
import 'create_password_screen.dart';
import 'otp_screen.dart';

/// Sign in and sign up, on one screen with an explicit mode switch.
///
/// Email first, and nothing else on the screen. The title asks for one thing,
/// the field under it is that thing, and the button sits on top of the
/// keyboard where the thumb already is. The wordmark that used to head this
/// screen is gone: three onboarding slides have just finished saying whose app
/// this is.
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
  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.onBack,
    this.startInSignIn = false,
  });

  /// [isNewAccount] tells the root flow it is looking at an account created
  /// seconds ago, which cannot have a name yet — so it can move on without
  /// asking the server what it already knows.
  final void Function({bool isNewAccount}) onAuthenticated;

  /// Opens on sign-in rather than sign-up.
  ///
  /// For anyone arriving from a sign-out: they demonstrably have an account,
  /// and showing them a registration form asks them to notice a mode switch
  /// before they can do the one thing they came to do.
  final bool startInSignIn;

  /// Returns to the onboarding carousel. This screen is a *stage* rather than
  /// a pushed route, so there is no route to pop — without this the close
  /// control would have nowhere to go, and the app would be a one-way door
  /// from the last onboarding slide.
  final VoidCallback? onBack;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { signUp, signIn }

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  late _Mode _mode = widget.startInSignIn ? _Mode.signIn : _Mode.signUp;
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

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

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
          builder: (_) => CreatePasswordScreen(
            email: _normalisedEmail,
            isReset: false,
            onFinished: () => widget.onAuthenticated(isNewAccount: true),
          ),
        ),
      );
      // Nothing to do here on success: CreatePasswordScreen already told the
      // root flow, before it popped, so that the pop reveals the next step
      // rather than this screen.
      if (done != true) return;
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
    final text = Theme.of(context).textTheme;
    final signUp = _mode == _Mode.signUp;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      // Managed here rather than by the Scaffold. The footer has to sit on top
      // of the keyboard — the button you are reaching for should not be behind
      // the thing you are typing on — and doing that by hand is one padding,
      // where letting the Scaffold resize would leave the footer pinned to a
      // screen bottom the keyboard is covering.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, 0, 0),
                  child: _CloseButton(onPressed: widget.onBack!),
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
                        signUp ? 'Enter your email address' : 'Welcome back',
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        controller: _email,
                        label: 'Your email',
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                      ),
                      if (!signUp) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _password,
                          label: 'Your password',
                          obscureText: _obscure,
                          suffixIcon:
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixIconTap: () => setState(() => _obscure = !_obscure),
                          errorText: _passwordError,
                        ),
                        // Sits tight under the field it belongs to. A full
                        // ghost button here floated it away from the password
                        // input and read as a second primary action.
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _forgotPassword,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                      const SizedBox(height: AppSpacing.lg),
                      // Under the field, not stranded at the bottom of the
                      // screen. Someone who already has an account knows it
                      // before they start typing, and this is where they are
                      // looking when they find out they are on the wrong one.
                      _ModeSwitch(
                        question: signUp ? 'Already have an account?' : 'New to Recur?',
                        action: signUp ? 'Sign in' : 'Create one',
                        onTap: () => setState(() {
                          _mode = signUp ? _Mode.signIn : _Mode.signUp;
                          _password.clear();
                          _emailError = null;
                          _passwordError = null;
                        }),
                      ),
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
                child: Column(
                  children: [
                    if (signUp) ...[
                      const _LegalLine(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppButton(
                      label: signUp ? 'Continue' : 'Sign in',
                      size: AppButtonSize.lg,
                      expand: true,
                      isLoading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small, quiet, and on its own plate — the same control the sheets use, in
/// the corner the thumb is not resting in.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

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
          child: Icon(Icons.close_rounded, size: 20, color: AppColors.ink(context)),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.question, required this.action, required this.onTap});

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted(context));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // The row is the tap target, so the words stay snug under the field
        // while the thing you actually hit is a comfortable height.
        padding: const EdgeInsets.symmetric(vertical: 6),
        // One rich text rather than a Row of two, so the line wraps instead of
        // overflowing. A Row of fixed Texts fits until someone turns their
        // text size up, and then it does not.
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$question '),
              TextSpan(
                text: action,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          style: muted,
        ),
      ),
    );
  }
}

/// The registration terms, sitting with the button that agrees to them rather
/// than at the top where nobody reads them.
///
/// The two documents are named but not linked: there is no terms page and no
/// privacy page to send anyone to yet — Settings' own Privacy policy row is an
/// empty callback for the same reason. Emphasis without an underline, so it
/// does not offer a tap that goes nowhere.
class _LegalLine extends StatelessWidget {
  const _LegalLine();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.muted(context),
          height: 1.45,
        );
    final strong = muted?.copyWith(
      color: AppColors.ink(context),
      fontWeight: FontWeight.w700,
    );

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'By registering, you accept our '),
          TextSpan(text: 'Terms of Use', style: strong),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: strong),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: muted,
    );
  }
}
