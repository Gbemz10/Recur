import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/app_shell.dart';
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
    return MaterialApp(
      title: 'Recur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const _RootFlow(),
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

enum _Stage { splash, onboarding, app }

class _RootFlowState extends State<_RootFlow> {
  _Stage _stage = _Stage.splash;

  @override
  Widget build(BuildContext context) {
    // Splash owns a dark status bar; everything after it is light.
    final overlay = _stage == _Stage.splash
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        child: switch (_stage) {
          _Stage.splash => SplashScreen(
              key: const ValueKey('splash'),
              onComplete: () => setState(() => _stage = _Stage.onboarding),
            ),
          _Stage.onboarding => OnboardingScreen(
              key: const ValueKey('onboarding'),
              onFinished: () => setState(() => _stage = _Stage.app),
            ),
          _Stage.app => const AppShell(key: ValueKey('app')),
        },
      ),
    );
  }
}
