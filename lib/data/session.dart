import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routeros/routeros.dart';

import 'demo_router_client.dart';
import 'local_network_permission.dart';
import 'paired_router.dart';
import 'paired_router_store.dart';
import 'router_connector.dart';

sealed class SessionState {
  const SessionState();
}

/// No router has been paired yet.
final class NeedsSetup extends SessionState {
  const NeedsSetup();
}

/// The app is in the background, so the connection is closed.
final class Paused extends SessionState {
  const Paused();
}

final class Connected extends SessionState {
  const Connected(this.client, {this.config});

  final RouterClient client;

  /// Null in demo mode.
  final PairedRouter? config;

  bool get isDemo => config == null;
}

/// A router is paired but can't be used right now.
sealed class ConnectionProblem extends SessionState {
  const ConnectionProblem(this.config);

  final PairedRouter config;
}

final class Unreachable extends ConnectionProblem {
  const Unreachable(super.config, {this.reason, this.permissionDenied = false});

  final String? reason;

  /// The user denied access to the local network.
  final bool permissionDenied;
}

final class LoginFailed extends ConnectionProblem {
  const LoginFailed(super.config, this.reason);

  final String reason;
}

/// The router presents a different certificate from the pinned one. Nothing
/// was sent to it.
final class CertificateChanged extends ConnectionProblem {
  const CertificateChanged(super.config, this.fingerprint);

  /// Fingerprint of the certificate the router presents now.
  final String fingerprint;
}

final pairedRouterStoreProvider = Provider<PairedRouterStore>(
  (ref) => const SecurePairedRouterStore(),
);

final routerConnectorProvider = Provider<RouterConnector>(
  (ref) => const RouterOsConnector(),
);

final localNetworkPermissionProvider = Provider<LocalNetworkPermission>(
  (ref) => const PlatformLocalNetworkPermission(),
);

final demoClientProvider = FutureProvider<RouterClient>(
  (ref) => DemoRouterClient.load(),
);

class Toggle extends Notifier<bool> {
  Toggle(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  void set(bool value) => state = value;
}

/// Whether the app is visible. Connections stay open only while it is.
final appActiveProvider = NotifierProvider<Toggle, bool>(() => Toggle(true));

final demoModeProvider = NotifierProvider<Toggle, bool>(() => Toggle(false));

final sessionProvider = AsyncNotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final active = ref.watch(appActiveProvider);
    final demo = ref.watch(demoModeProvider);
    final store = ref.watch(pairedRouterStoreProvider);
    if (!active) return const Paused();
    if (demo) return Connected(await ref.watch(demoClientProvider.future));

    final config = await store.load();
    if (config == null) return const NeedsSetup();
    return _connect(config);
  }

  Future<SessionState> _connect(PairedRouter config) async {
    final permission = ref.read(localNetworkPermissionProvider);
    final connector = ref.read(routerConnectorProvider);
    if (!await permission.request()) {
      return Unreachable(config, permissionDenied: true);
    }
    final RouterClient client;
    try {
      client = await connector.connect(config);
    } on CertificateMismatchException catch (e) {
      return CertificateChanged(config, e.actual);
    } on AuthenticationException catch (e) {
      return LoginFailed(config, e.message);
    } on RouterOsException catch (e) {
      return Unreachable(config, reason: e.message);
    } on TimeoutException {
      return Unreachable(config, reason: 'The router did not answer in time.');
    }
    if (!ref.mounted) {
      await client.close();
      return Unreachable(config);
    }
    var current = true;
    ref.onDispose(() {
      current = false;
      client.close();
    });
    // If the router drops the connection, reconnect or report why not.
    client.done.then((_) {
      if (current) ref.invalidateSelf();
    });
    return Connected(client, config: config);
  }

  /// Checks [config] by signing in, then saves it and connects. Throws the
  /// connection error (e.g. [AuthenticationException]) and saves nothing if
  /// signing in fails.
  Future<void> pair(PairedRouter config) async {
    final client = await ref.read(routerConnectorProvider).connect(config);
    await client.close();
    await ref.read(pairedRouterStoreProvider).save(config);
    ref.read(demoModeProvider.notifier).set(false);
    ref.invalidateSelf();
  }

  /// Pins the certificate the router presents now, then reconnects.
  Future<void> trustCertificate(String fingerprint) async {
    final store = ref.read(pairedRouterStoreProvider);
    final config = await store.load();
    if (config == null) return;
    await store.save(config.withPin(fingerprint));
    ref.invalidateSelf();
  }

  /// Deletes the saved router. The user stays on the router.
  Future<void> forget() async {
    await ref.read(pairedRouterStoreProvider).clear();
    ref.invalidateSelf();
  }

  void retry() => ref.invalidateSelf();

  void startDemo() => ref.read(demoModeProvider.notifier).set(true);

  void stopDemo() => ref.read(demoModeProvider.notifier).set(false);
}
