import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/api_client.dart';
import 'data/auth_service.dart';
import 'data/banking_service.dart';
import 'data/theme_controller.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/link_bank_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'ui/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecurApp());
}

class RecurApp extends StatelessWidget {
  const RecurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Recur',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeController.flutterThemeMode,
        home: const _RootFlow(),
      ),
    );
  }
}

/// Owns the top-level flow: splash → onboarding → app shell.
/// Kept deliberately dumb for v1; swap for a real router once auth and
/// deep links exist.
class _RootFlow extends StatefulWidget {
  const _RootFlow();

  @override
  State<_RootFlow> createState() => _RootFlowState();
}

enum _Stage { splash, onboarding, auth, linkBank, app }

class _RootFlowState extends State<_RootFlow> {
  _Stage _stage = _Stage.splash;

  /// A returning user who signs back in (after being logged out, e.g. by
  /// the session-storage key change or a genuinely expired refresh token)
  /// should never be walked back through bank-linking if they already have
  /// an active linked bank — that was the bug: every successful auth used
  /// to route straight to LinkBankScreen unconditionally, which looked like
  /// "all my data is gone" even though nothing was actually deleted, it was
  /// just hidden behind a link-bank screen the user had already completed.
  Future<void> _afterAuth() async {
    var hasActiveBank = false;
    try {
      final banks = await BankingService.listAccounts();
      hasActiveBank = banks.any((b) => b.status == 'ACTIVE');
    } on ApiException {
      // Can't tell either way — fall through to the link-bank screen rather
      // than silently dropping a genuinely new user onto an empty app shell
      // with no way to link a bank from onboarding.
    }
    if (!mounted) return;
    setState(() => _stage = hasActiveBank ? _Stage.app : _Stage.linkBank);
  }

  @override
  Widget build(BuildContext context) {
    // The pre-auth flow (splash/onboarding/auth/link-bank) is intentionally
    // light-only regardless of theme preference — status bar icons stay
    // dark. Once inside the app (post sign-in), match the resolved
    // brightness so icons stay legible against a dark scaffold too.
    final overlay = _stage == _Stage.app && Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        child: switch (_stage) {
          _Stage.splash => SplashScreen(
              key: const ValueKey('splash'),
              // A returning user with a stored token skips straight past
              // onboarding/auth/bank-linking — those are strictly a
              // first-run flow. This doesn't verify the token is still
              // valid server-side; if it's expired, the first
              // authenticated request inside AppShell will fail and
              // should be handled there (see SubscriptionStore).
              onComplete: () async {
                final signedIn = await AuthService.hasSession();
                if (!mounted) return;
                setState(() => _stage = signedIn ? _Stage.app : _Stage.onboarding);
              },
            ),
          _Stage.onboarding => OnboardingScreen(
              key: const ValueKey('onboarding'),
              onFinished: () => setState(() => _stage = _Stage.auth),
            ),
          _Stage.auth => AuthScreen(
              key: const ValueKey('auth'),
              onAuthenticated: _afterAuth,
            ),
          _Stage.linkBank => LinkBankScreen(
              key: const ValueKey('link'),
              onDone: () => setState(() => _stage = _Stage.app),
            ),
          _Stage.app => AppShell(
              key: const ValueKey('app'),
              onSignOut: () => setState(() => _stage = _Stage.auth),
            ),
        },
      ),
    );
  }
}
