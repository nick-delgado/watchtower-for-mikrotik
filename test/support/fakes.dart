import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/data/demo_router_client.dart';
import 'package:watchtower/data/local_network_permission.dart';
import 'package:watchtower/data/paired_router.dart';
import 'package:watchtower/data/paired_router_store.dart';
import 'package:watchtower/data/router_connector.dart';
import 'package:watchtower/data/session.dart';

final demoFixture = jsonDecode(
  File(DemoRouterClient.asset).readAsStringSync(),
) as Map<String, Object?>;

DemoRouterClient demoClient() => DemoRouterClient(demoFixture);

const testCertificate = CertificateInfo(
  fingerprint:
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  subject: '/CN=watchtower',
  issuer: '/CN=watchtower-ca',
);

const otherFingerprint =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

final testRouter = PairedRouter(
  host: PairedRouter.defaultHost,
  password: 'secret',
  pin: testCertificate.fingerprint,
);

class MemoryRouterStore implements PairedRouterStore {
  PairedRouter? router;

  @override
  Future<PairedRouter?> load() async => router;

  @override
  Future<void> save(PairedRouter router) async => this.router = router;

  @override
  Future<void> clear() async => router = null;
}

class FakePermission implements LocalNetworkPermission {
  var granted = true;
  var settingsOpened = 0;

  @override
  Future<bool> request() async => granted;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// A router that presents [certificate], accepts [password] and serves the
/// demo capture.
class FakeConnector implements RouterConnector {
  var certificate = testCertificate;
  var password = 'secret';

  /// Thrown instead of connecting, e.g. to simulate an unreachable router.
  Object? error;

  final connected = <PairedRouter>[];
  final clients = <DemoRouterClient>[];

  @override
  Future<CertificateInfo> fetchCertificate(
    String host, {
    int port = RouterOsConnection.defaultPort,
  }) async {
    if (error case final error?) throw error;
    return certificate;
  }

  @override
  Future<RouterClient> connect(PairedRouter router) async {
    connected.add(router);
    if (error case final error?) throw error;
    if (normalizeFingerprint(router.pin) != certificate.fingerprint) {
      throw CertificateMismatchException(
        expected: router.pin,
        actual: certificate.fingerprint,
      );
    }
    if (router.password != password) {
      throw const AuthenticationException('invalid user name or password (6)');
    }
    final client = demoClient();
    clients.add(client);
    return client;
  }
}

List<Override> fakeOverrides({
  required PairedRouterStore store,
  required RouterConnector connector,
  required LocalNetworkPermission permission,
  RouterClient? demo,
}) => [
  pairedRouterStoreProvider.overrideWithValue(store),
  routerConnectorProvider.overrideWithValue(connector),
  localNetworkPermissionProvider.overrideWithValue(permission),
  demoClientProvider.overrideWith((ref) => demo ?? demoClient()),
];

/// A phone-width screen tall enough that whole pages are built, so tests
/// can tap buttons below the fold.
void useTallScreen(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1170, 4000)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
