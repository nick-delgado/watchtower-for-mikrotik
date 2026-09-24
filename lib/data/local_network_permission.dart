import 'package:flutter/services.dart';

/// Access to devices on the local network, such as the router.
///
/// Android 17 requires the runtime `ACCESS_LOCAL_NETWORK` permission. iOS
/// asks the user by itself on the first connection and has no API to check
/// the answer, so [request] always returns true there.
abstract interface class LocalNetworkPermission {
  /// Asks for access if needed. Returns false if it was denied.
  Future<bool> request();

  /// Opens this app's page in the system settings.
  Future<void> openSettings();
}

/// Implemented natively in `MainActivity.kt` and `AppDelegate.swift`.
class PlatformLocalNetworkPermission implements LocalNetworkPermission {
  const PlatformLocalNetworkPermission();

  static const _channel = MethodChannel('sh.nickd.watchtower/local_network');

  @override
  Future<bool> request() async =>
      await _channel.invokeMethod<bool>('request') ?? false;

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');
}
