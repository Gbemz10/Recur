import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps the platform keychain (iOS) / keystore (Android) for the session's
/// two tokens — deliberately not SharedPreferences, which stores as
/// plaintext on both platforms and is trivially readable by anything with
/// filesystem access to a rooted/jailbroken device.
///
/// Two tokens, two lifetimes: the access token is short-lived (15 min) and
/// sent on every request; the refresh token is long-lived (30 days) and
/// only ever sent to `/auth/refresh` to mint a new access token. Splitting
/// them is what makes server-side sign-out possible at all — a stateless
/// JWT alone can't be revoked, only a stored, checkable token can.
class TokenStorage {
  TokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accessKey = 'recur_access_token';
  static const _refreshKey = 'recur_refresh_token';

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> writeAccess(String accessToken) => _storage.write(key: _accessKey, value: accessToken);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
