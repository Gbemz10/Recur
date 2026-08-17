import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../ui/ui.dart';

/// Six-digit code entry.
///
/// One hidden text field sits behind six drawn boxes. That's deliberate:
/// six separate fields means six focus nodes, broken backspace, and paste
/// that only fills the first box. A single field gets SMS autofill, paste,
/// and backspace for free, and the boxes are purely presentational.
///
/// Performance notes, because a laggy code field is the worst place to have
/// one — the user is typing fast and watching closely:
///
///   * The boxes rebuild off an [AnimatedBuilder] listening to the
///     controller and focus node directly. Rebuilding the whole screen via
///     setState on every keystroke is what makes these feel mushy.
///   * The resend countdown owns its own state, so its once-a-second tick
///     doesn't rebuild the input at all.
///   * The hidden field is made invisible with transparent colours rather
///     than an [Opacity] widget, which would force a saveLayer every frame.
///   * Box styling is instant, not animated. A 180ms transition on every
///     keystroke reads as input lag even when nothing is actually slow.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email, required this.isReset});

  final String email;

  /// Which flow this code belongs to — must match the `purpose` the
  /// backend hashed the code under (`SIGNUP` vs `RESET_PASSWORD`), or
  /// verification fails even for the right code.
  final bool isReset;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _length = 6;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // No setState here on purpose — the boxes listen to the controller
    // themselves. This callback only handles side effects.
    if (_error != null) setState(() => _error = null);
    if (_controller.text.length == _length && !_busy) _verify();
  }

  Future<void> _verify() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      await AuthService.verifyOtp(email: widget.email, code: _controller.text, isReset: widget.isReset);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      _controller.clear();
      _focus.requestFocus();
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _onResend() async {
    _controller.clear();
    _focus.requestFocus();
    try {
      if (widget.isReset) {
        await AuthService.forgotPassword(widget.email);
      } else {
        await AuthService.signup(widget.email);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
      return;
    }
    if (!mounted) return;
    showAppSnackbar(
      context,
      message: 'New code sent',
      variant: AppAlertVariant.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    // See auth_screen.dart's build() for why this is forced light — same
    // pre-auth-flow-is-always-light reasoning, same fix.
    return Theme(
      data: AppTheme.light,
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;

          return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
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
                'Enter your code',
                style: text.headlineSmall?.copyWith(letterSpacing: -0.4),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.neutral600,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'We emailed 6 digits to '),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const TextSpan(
                      text: '. Check your spam folder if it has not arrived.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Boxes + the real field behind them.
              Stack(
                children: [
                  // Rebuilds on text or focus change only, not on every
                  // parent setState.
                  AnimatedBuilder(
                    animation: Listenable.merge([_controller, _focus]),
                    builder: (context, _) => _CodeBoxes(
                      value: _controller.text,
                      length: _length,
                      hasError: _error != null,
                      focused: _focus.hasFocus,
                    ),
                  ),
                  Positioned.fill(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_length),
                      ],
                      showCursor: false,
                      enableInteractiveSelection: false,
                      // Invisible without an Opacity layer.
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 1,
                      ),
                      cursorColor: Colors.transparent,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        fillColor: Colors.transparent,
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style:
                            text.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              if (_busy)
                const AppLoadingIndicator()
              else
                Center(child: _ResendCountdown(onResend: _onResend)),
            ],
          ),
        ),
      ),
          );
        },
      ),
    );
  }
}

class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.value,
    required this.length,
    required this.hasError,
    required this.focused,
  });

  final String value;
  final int length;
  final bool hasError;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(length, (i) {
        final filled = i < value.length;
        final isNext = i == value.length && focused;

        final borderColor = hasError
            ? AppColors.danger
            : isNext
                ? AppColors.primary
                : filled
                    ? AppColors.neutral300
                    : AppColors.neutral200;

        // Plain Container, not AnimatedContainer: transitions on keystroke
        // are exactly what makes a code field feel like it's lagging.
        return Container(
          width: 48,
          height: 58,
          decoration: BoxDecoration(
            color: filled ? AppColors.white : AppColors.neutral50,
            borderRadius: AppRadius.lgBR,
            border: Border.all(
              color: borderColor,
              width: isNext || hasError ? 1.8 : 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            filled ? value[i] : '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.neutral900,
            ),
          ),
        );
      }),
    );
  }
}

/// Owns its own ticking state so the once-a-second rebuild stays local and
/// never touches the code input.
class _ResendCountdown extends StatefulWidget {
  const _ResendCountdown({required this.onResend});

  final VoidCallback onResend;

  @override
  State<_ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends State<_ResendCountdown> {
  /// Shorter than the backend's OTP_EXPIRE_MINUTES, so resend unlocks
  /// before the code actually dies.
  static const int _start = 45;

  int _left = _start;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _run() {
    _timer?.cancel();
    setState(() => _left = _start);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_left > 0) {
      return Text(
        'Resend code in ${_left}s',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.neutral400),
      );
    }
    return AppButton(
      label: 'Resend code',
      variant: AppButtonVariant.ghost,
      onPressed: () {
        _run();
        widget.onResend();
      },
    );
  }
}
