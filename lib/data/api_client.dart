import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../config/env.dart';
import 'device_id.dart';
import 'token_storage.dart';

/// `package:http` has no built-in request timeout — a request against a
/// dead host (a stale ngrok tunnel, a crashed dev server) can hang
/// indefinitely instead of failing fast. That's especially costly for
/// anything that polls in a loop (see LinkBankScreen's account-linking
/// poll): one hung request silently eats the whole polling budget instead
/// of failing and letting the loop try again.
const _requestTimeout = Duration(seconds: 15);

/// Thrown for any non-2xx response or network failure. `code` mirrors the
/// backend's `error.code` (see recur-backend's `AppError`) when available,
/// so UI can switch on a stable code instead of matching `message` text.
class ApiException implements Exception {
  ApiException(this.message, {this.code = 'UNKNOWN', this.statusCode});

  final String message;
  final String code;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code): $message';
}

/// Thin wrapper over the Node backend: attaches the bearer token, decodes
/// JSON, and turns the backend's `{ error: { code, message } }` shape into
/// a typed [ApiException] so screens don't each re-implement that parsing.
///
/// Access tokens expire in 15 minutes (see recur-backend's `env.ts`), so
/// every authed call here is wrapped to catch a 401, silently trade the
/// stored refresh token for a new access token via `/auth/refresh`, and
/// retry once — a screen that's been open a while never has to know its
/// token went stale mid-session.
class ApiClient {
  ApiClient({TokenStorage? tokenStorage, DeviceIdStorage? deviceIdStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage(),
        _deviceIdStorage = deviceIdStorage ?? DeviceIdStorage();

  final TokenStorage _tokenStorage;
  final DeviceIdStorage _deviceIdStorage;
  final http.Client _http = http.Client();

  // Several requests can 401 around the same moment (e.g. a screen that
  // fires off three calls on load) — without this they'd each kick off
  // their own refresh, racing to rotate the same refresh token and making
  // all but the first fail. Coalescing into one in-flight future means
  // everyone waits on, and shares, a single refresh.
  Future<String?>? _refreshInFlight;

  Uri _uri(String path) => Uri.parse('${Env.apiBaseUrl}$path');

  /// [hasBody] gates the `Content-Type` header — sending it on a bodyless
  /// request (e.g. `POST /banking/link/initiate`, which takes no payload)
  /// makes Fastify's default JSON parser choke with
  /// `FST_ERR_CTP_EMPTY_JSON_BODY` ("Body cannot be empty when content-type
  /// is set to 'application/json'"), since it tries to parse a body that
  /// was never sent.
  Future<Map<String, String>> _headers({
    required bool auth,
    bool hasBody = false,
    String? overrideAccessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Device-Id': await _deviceIdStorage.read(),
    };
    if (hasBody) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = overrideAccessToken ?? await _tokenStorage.readAccess();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Non-JSON body (e.g. a proxy error page) — fall through, treated
        // the same as an empty body below.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? const {};
    }

    final error = body?['error'];
    final message = error is Map ? error['message'] as String? : null;
    final code = error is Map ? error['code'] as String? : null;
    throw ApiException(
      message ?? 'Something went wrong (${response.statusCode})',
      code: code ?? 'HTTP_${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  Future<T> _guarded<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException("Couldn't reach the server — check your connection.", code: 'NETWORK_ERROR');
    }
  }

  /// Runs [send] with fresh headers; on a 401 from an authed call, tries
  /// exactly one silent refresh-and-retry before giving up. A 401 that
  /// survives the retry means the refresh token itself is dead (expired,
  /// revoked by a password change, or a sign-out on another device) —
  /// callers see that as a normal [ApiException] and the root flow in
  /// main.dart treats it as "not signed in".
  Future<Map<String, dynamic>> _authedRequest(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required bool auth,
    bool hasBody = false,
  }) {
    return _guarded(() async {
      var headers = await _headers(auth: auth, hasBody: hasBody);
      var response = await send(headers).timeout(_requestTimeout);

      if (response.statusCode == 401 && auth) {
        final refreshedToken = await _refreshAccessToken();
        if (refreshedToken != null) {
          headers = await _headers(auth: auth, hasBody: hasBody, overrideAccessToken: refreshedToken);
          response = await send(headers).timeout(_requestTimeout);
        }
      }

      return _decode(response);
    });
  }

  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefresh();
    if (refreshToken == null) return null;

    try {
      final response = await _http
          .post(
            _uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // The refresh token itself is dead — wipe local storage so the app
        // treats this as a real sign-out rather than retrying forever.
        await _tokenStorage.clear();
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccessToken = decoded['accessToken'] as String;
      final newRefreshToken = decoded['refreshToken'] as String;
      await _tokenStorage.writeTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);
      return newAccessToken;
    } catch (_) {
      // Network failure mid-refresh — leave storage alone, this was likely
      // transient and worth trying again on the next request.
      return null;
    }
  }

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) {
    return _authedRequest(
      (headers) => _http.get(_uri(path), headers: headers),
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true}) {
    return _authedRequest(
      (headers) => _http.post(_uri(path), headers: headers, body: body == null ? null : jsonEncode(body)),
      auth: auth,
      hasBody: body != null,
    );
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body, bool auth = true}) {
    return _authedRequest(
      (headers) => _http.patch(_uri(path), headers: headers, body: body == null ? null : jsonEncode(body)),
      auth: auth,
      hasBody: body != null,
    );
  }

  Future<Map<String, dynamic>> delete(String path, {Object? body, bool auth = true}) {
    return _authedRequest(
      (headers) => _http.delete(_uri(path), headers: headers, body: body == null ? null : jsonEncode(body)),
      auth: auth,
      hasBody: body != null,
    );
  }

  /// Single-file multipart upload (avatar photos, for now). Separate from
  /// [post] rather than trying to make one method handle both JSON and
  /// multipart bodies — the request-building is different enough
  /// (`http.MultipartRequest` vs. a plain `http.Request`) that forcing them
  /// together would just make both harder to read.
  Future<Map<String, dynamic>> postFile(
    String path, {
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String fieldName = 'file',
  }) {
    return _authedRequest(
      (headers) {
        final request = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(headers)
          ..files.add(
            http.MultipartFile.fromBytes(
              fieldName,
              bytes,
              filename: filename,
              contentType: MediaType.parse(mimeType),
            ),
          );
        return _http.send(request).then(http.Response.fromStream);
      },
      auth: true,
    );
  }

  /// Persists a fresh token pair — called right after login/signup/password
  /// change, whichever endpoint just issued one.
  Future<void> saveTokens({required String accessToken, required String refreshToken}) =>
      _tokenStorage.writeTokens(accessToken: accessToken, refreshToken: refreshToken);

  Future<String?> currentToken() => _tokenStorage.readAccess();

  /// Signs out: best-effort tells the server to revoke this device's
  /// refresh token, then wipes local storage either way. Local storage is
  /// cleared even if the network call fails — a user tapping "Sign out"
  /// should never be stuck signed in because a request timed out.
  Future<void> clearToken() async {
    final refreshToken = await _tokenStorage.readRefresh();
    await _tokenStorage.clear();
    if (refreshToken == null) return;
    try {
      await _http
          .post(
            _uri('/auth/logout'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      // Local session is already gone — a failed revoke just means this
      // refresh token lingers server-side until it naturally expires.
    }
  }
}

/// One client for the whole app — cheap to share, and keeping it a
/// singleton means every screen sees the same token without threading an
/// instance through every constructor.
final apiClient = ApiClient();
