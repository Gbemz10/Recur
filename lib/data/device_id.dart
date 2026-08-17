import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A random id generated once per install and persisted in the platform
/// keychain, sent to the backend as `X-Device-Id` on every request.
///
/// Deliberately not derived from any hardware identifier (IMEI, MAC
/// address, etc.) — those require extra permissions/packages on some
/// platforms and raise privacy questions this app has no need to take on.
/// A locally-generated random id does the one job the backend actually
/// needs it for (recognising "this is a device we've seen before" for the
/// new-sign-in email, see recur-backend's deviceTrust.ts) without being
/// traceable to real-world hardware or reusable across apps.
///
/// Lives in secure storage rather than SharedPreferences for the same
/// reason tokens do (see token_storage.dart) — not because the id itself
/// is sensitive, but because keychain storage already survives a plain
/// reinstall-without-restore the same way SharedPreferences would be wiped
/// anyway, so there's no reason to reach for a second storage mechanism
/// just for this one value.
class DeviceIdStorage {
  DeviceIdStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'recur_device_id';

  String? _cached;

  Future<String> read() async {
    final cached = _cached;
    if (cached != null) return cached;

    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }

    final generated = _generate();
    await _storage.write(key: _key, value: generated);
    _cached = generated;
    return generated;
  }

  /// 128 bits from a CSPRNG, hex-encoded — plenty of entropy for a
  /// correlation id with no cryptographic role (it's never a secret; the
  /// worst outcome of someone guessing it is one false "known device").
  String _generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// One instance for the whole app, same pattern as [apiClient] in
/// api_client.dart.
final deviceIdStorage = DeviceIdStorage();
