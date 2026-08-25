import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Which notices have been read.
///
/// Reuses `flutter_secure_storage` rather than adding a preferences plugin for
/// a list of ids — the same call ThemeController makes, and for the same
/// reason: it is already a linked native plugin here, and a new one would mean
/// another "stop the app and re-run, hot reload will not pick it up" for
/// something this small.
///
/// Read state is local on purpose. It describes this device's relationship to
/// a notice, not a fact about the account, and the notices themselves are
/// derived rather than stored — there is no row on the server to mark.
class NoticeReadStore extends ChangeNotifier {
  NoticeReadStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _load();
  }

  final FlutterSecureStorage _storage;
  static const _key = 'recur_read_notices';

  /// Newest last, so the cap below drops the oldest first.
  ///
  /// Capped because notice ids are derived from live data and change as that
  /// data changes: every week of charges is a new id, and without a ceiling
  /// this list would grow for the life of the install to remember things that
  /// stopped existing months ago.
  static const _cap = 200;

  List<String> _read = [];
  Set<String> _readSet = {};

  /// Ids read on this device. A set, because the only question ever asked of
  /// it is membership.
  Set<String> get read => _readSet;

  bool isRead(String id) => _readSet.contains(id);

  Future<void> _load() async {
    final stored = await _storage.read(key: _key);
    if (stored == null || stored.isEmpty) return;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return;
      _read = decoded.whereType<String>().toList();
      _readSet = _read.toSet();
      notifyListeners();
    } catch (_) {
      // A value we cannot parse is a value we can throw away: the cost is one
      // notice showing as unread again, which is a great deal better than a
      // store that refuses to load for the life of the install.
      await _storage.delete(key: _key);
    }
  }

  Future<void> markRead(String id) async {
    if (_readSet.contains(id)) return;
    _read = [..._read, id];
    if (_read.length > _cap) _read = _read.sublist(_read.length - _cap);
    _readSet = _read.toSet();
    notifyListeners();

    // Written after the notifier fires. The badge should drop the moment the
    // row is tapped, not once the keychain has been round-tripped.
    await _storage.write(key: _key, value: jsonEncode(_read));
  }
}
