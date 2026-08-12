import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// System defers to the OS setting — the sane default, and the one most
/// users never touch. Light/Dark are explicit overrides.
enum AppThemeMode { system, light, dark }

/// Persists the user's theme choice and exposes it as a [ChangeNotifier] so
/// `MaterialApp` (and anything else that cares) rebuilds the moment it
/// changes. Reuses `flutter_secure_storage` rather than adding a new
/// dependency for what's really just a three-value preference — it's
/// already a linked native plugin in this app, and adding a *new* one would
/// mean yet another "fully stop and re-run, hot reload won't pick it up"
/// gotcha for a preference this small doesn't warrant.
class ThemeController extends ChangeNotifier {
  ThemeController({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    _load();
  }

  final FlutterSecureStorage _storage;
  static const _key = 'recur_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  ThemeMode get flutterThemeMode => switch (_mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  Future<void> _load() async {
    final stored = await _storage.read(key: _key);
    for (final candidate in AppThemeMode.values) {
      if (candidate.name == stored) {
        _mode = candidate;
        notifyListeners();
        break;
      }
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _storage.write(key: _key, value: mode.name);
  }
}

/// One controller for the whole app — same singleton pattern as
/// `apiClient` in api_client.dart.
final themeController = ThemeController();
