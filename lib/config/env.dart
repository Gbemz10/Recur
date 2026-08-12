import 'dart:io' show Platform;

/// Where the Node backend lives. Override at build/run time with
/// `--dart-define=API_BASE_URL=https://your-real-host` — e.g. once this is
/// deployed, or when testing against a tunnel (ngrok) instead of a local
/// server.
///
/// The platform-based defaults below only matter for local development
/// against `npm run dev` on this same machine:
///   - Android emulator can't see the host machine as `localhost` — `10.0.2.2`
///     is the documented emulator-to-host loopback alias.
///   - iOS simulator shares the host's network namespace, so `localhost`
///     works directly.
///   - A physical device (either platform) can't reach `localhost` *or*
///     `10.0.2.2` — it needs the host machine's real LAN IP, which varies
///     per network. There's no safe default for that case, so it's left to
///     `--dart-define` rather than guessed.
class Env {
  Env._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    return 'http://localhost:4000';
  }
}
