import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'paired_router.dart';

abstract interface class PairedRouterStore {
  Future<PairedRouter?> load();
  Future<void> save(PairedRouter config);
  Future<void> clear();
}

/// Keeps the config, including the password, in the iOS Keychain or the
/// Android Keystore. On iOS it stays on this device: it isn't synced to
/// iCloud or restored to another phone.
class SecurePairedRouterStore implements PairedRouterStore {
  const SecurePairedRouterStore();

  static const _key = 'router';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  @override
  Future<PairedRouter?> load() async {
    final json = await _storage.read(key: _key);
    if (json == null) return null;
    return PairedRouter.fromJson(jsonDecode(json) as Map<String, Object?>);
  }

  @override
  Future<void> save(PairedRouter config) =>
      _storage.write(key: _key, value: jsonEncode(config.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
