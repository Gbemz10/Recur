import 'api_client.dart';

/// Wraps the `/auth/*` endpoints so screens call one function each instead
/// of building request bodies inline — matches the backend's schemas
/// (`src/modules/auth/schemas.ts`) exactly, including the uppercase
/// `SIGNUP` / `RESET_PASSWORD` purpose values.
class AuthService {
  AuthService._();

  static Future<void> signup(String email) => apiClient.post('/auth/signup', body: {'email': email}, auth: false);

  static Future<void> forgotPassword(String email) =>
      apiClient.post('/auth/forgot-password', body: {'email': email}, auth: false);

  static Future<void> verifyOtp({
    required String email,
    required String code,
    required bool isReset,
  }) {
    return apiClient.post(
      '/auth/otp/verify',
      body: {'email': email, 'code': code, 'purpose': isReset ? 'RESET_PASSWORD' : 'SIGNUP'},
      auth: false,
    );
  }

  /// Sets the account's password (initial signup or reset) and persists
  /// the token pair the backend hands back — from this point on the user
  /// is signed in.
  static Future<void> setPassword({
    required String email,
    required String password,
    required bool isReset,
  }) async {
    final response = await apiClient.post(
      '/auth/password',
      body: {'email': email, 'password': password, 'purpose': isReset ? 'RESET_PASSWORD' : 'SIGNUP'},
      auth: false,
    );
    await apiClient.saveTokens(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
    );
  }

  static Future<void> login({required String email, required String password}) async {
    final response = await apiClient.post('/auth/login', body: {'email': email, 'password': password}, auth: false);
    await apiClient.saveTokens(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
    );
  }

  /// True if a token is already stored — used at app launch to skip
  /// straight past onboarding/auth for a returning user. Doesn't verify
  /// the token is still valid server-side; the first authenticated
  /// request will surface that if it's expired (and silently refresh —
  /// see ApiClient — or, if the refresh token itself is dead, fail and
  /// send the user back to sign-in).
  static Future<bool> hasSession() async => (await apiClient.currentToken()) != null;

  static Future<void> logout() => apiClient.clearToken();

  /// Changes the signed-in user's password. On success the backend has
  /// already signed every *other* device out (see recur-backend's
  /// changePassword) and handed back a fresh token pair for this one, which
  /// gets saved so this session stays signed in without interruption.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await apiClient.post('/auth/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    await apiClient.saveTokens(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
    );
  }

  /// Permanently deletes the account (password-confirmed). Local session
  /// storage isn't explicitly cleared here — the account, and therefore
  /// every refresh token tied to it, no longer exists server-side, so the
  /// caller should immediately treat this the same as a sign-out.
  static Future<void> deleteAccount(String password) =>
      apiClient.delete('/auth/me', body: {'password': password});
}
