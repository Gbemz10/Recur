import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One-time things the app has already asked this device about.
///
/// Local, like the theme choice and the read notices, and for the same reason:
/// it describes this install's history, not a fact about the account. Reusing
/// `flutter_secure_storage` rather than adding a preferences plugin for a
/// single boolean follows ThemeController's precedent.
class SetupFlags {
  SetupFlags._();

  static const _storage = FlutterSecureStorage();
  static const _pushAskedKey = 'recur_push_asked';

  /// Whether the notification screen has been shown. Asked once ever — an app
  /// that re-asks on every sign-in is one people learn to dismiss without
  /// reading, and iOS only grants one real prompt anyway.
  static Future<bool> pushAsked() async =>
      (await _storage.read(key: _pushAskedKey)) == 'true';

  static Future<void> markPushAsked() =>
      _storage.write(key: _pushAskedKey, value: 'true');
}
