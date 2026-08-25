import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/profile_service.dart';
import '../ui/ui.dart';

/// The name Recur greets you by.
///
/// Asked once, here, rather than left to Settings — the dashboard opens with
/// "Good morning, <name>", and an app that greets you by an address you typed
/// two screens ago is worse than one that does not greet you at all.
///
/// Skippable on purpose. A name is a courtesy, not a credential, and the
/// greeting already handles its absence by standing alone.
///
/// Shown by the root flow whenever the signed-in profile has no name, rather
/// than as one step of the signup chain. That covers the three ways someone
/// arrives without one: a fresh signup, a signup abandoned after the password,
/// and an account made before this screen existed.
class ChooseNameScreen extends StatefulWidget {
  const ChooseNameScreen({super.key, required this.onDone});

  /// Called once the name is saved or skipped. A callback rather than a pop,
  /// because this is a stage in the root flow and has no route under it.
  final VoidCallback onDone;

  @override
  State<ChooseNameScreen> createState() => _ChooseNameScreenState();
}

class _ChooseNameScreenState extends State<ChooseNameScreen> {
  final TextEditingController _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (_error != null) setState(() => _error = null);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _value => _name.text.trim();

  Future<void> _save() async {
    if (_value.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ProfileService.updateDisplayName(_value);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xxl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's your name?",
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        controller: _name,
                        label: 'Your name',
                        hint: 'Ada',
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        errorText: _error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'This is what Recur will call you. Just a first name is '
                        'plenty — it only ever appears to you.',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.muted(context),
                          height: 1.45,
                        ),
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
                    AppButton(
                      label: 'Continue',
                      size: AppButtonSize.lg,
                      expand: true,
                      isLoading: _busy,
                      onPressed: _busy || _value.isEmpty ? null : _save,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Skip for now',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.lg,
                      expand: true,
                      onPressed: _busy ? null : widget.onDone,
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
