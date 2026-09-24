import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/data/paired_router.dart';
import 'package:watchtower/data/session.dart';

import '../support/fakes.dart';

void main() {
  late MemoryRouterStore store;
  late FakeConnector connector;
  late FakePermission permission;
  late ProviderContainer container;
  var listening = false;

  setUp(() {
    listening = false;
    store = MemoryRouterStore();
    connector = FakeConnector();
    permission = FakePermission();
    container = ProviderContainer(
      overrides: fakeOverrides(
        store: store,
        connector: connector,
        permission: permission,
      ),
    );
    addTearDown(container.dispose);
  });

  // The first call starts listening, the way the UI keeps the session alive,
  // so each test can set up the store before the session is built.
  Future<SessionState> session() {
    if (!listening) {
      container.listen(sessionProvider, (_, _) {});
      listening = true;
    }
    return container.read(sessionProvider.future);
  }

  SessionNotifier notifier() => container.read(sessionProvider.notifier);
  Matcher connected({bool demo = false}) =>
      isA<Connected>().having((s) => s.isDemo, 'isDemo', demo);

  test('asks for setup when no router is paired', () async {
    expect(await session(), isA<NeedsSetup>());
  });

  test('connects to the paired router', () async {
    store.router = testRouter;
    expect(await session(), connected());
    expect(connector.connected, [testRouter]);
  });

  test('reports a changed certificate', () async {
    store.router = testRouter.withPin(otherFingerprint);
    expect(
      await session(),
      isA<CertificateChanged>().having(
        (s) => s.fingerprint,
        'fingerprint',
        testCertificate.fingerprint,
      ),
    );
  });

  test('reports a rejected password', () async {
    store.router = PairedRouter(
      host: testRouter.host,
      password: 'wrong',
      pin: testRouter.pin,
    );
    expect(await session(), isA<LoginFailed>());
  });

  test('reports an unreachable router', () async {
    store.router = testRouter;
    connector.error = const RouterOsException('Cannot reach the router');
    expect(
      await session(),
      isA<Unreachable>()
          .having((s) => s.reason, 'reason', 'Cannot reach the router')
          .having((s) => s.permissionDenied, 'permissionDenied', false),
    );
  });

  test('does not connect without local network access', () async {
    store.router = testRouter;
    permission.granted = false;
    expect(
      await session(),
      isA<Unreachable>().having(
        (s) => s.permissionDenied,
        'permissionDenied',
        true,
      ),
    );
    expect(connector.connected, isEmpty);
  });

  test('disconnects in the background and reconnects on return', () async {
    store.router = testRouter;
    await session();
    container.read(appActiveProvider.notifier).set(false);
    expect(await session(), isA<Paused>());
    await expectLater(connector.clients.single.done, completes);

    container.read(appActiveProvider.notifier).set(true);
    expect(await session(), connected());
    expect(connector.connected, hasLength(2));
  });

  test('reconnects when the router drops the connection', () async {
    store.router = testRouter;
    await session();
    await connector.clients.single.close();
    await Future<void>.delayed(Duration.zero);
    expect(await session(), connected());
    expect(connector.connected, hasLength(2));
  });

  test('pairing saves the router once signing in works', () async {
    await session();
    await notifier().pair(testRouter);
    expect(store.router, same(testRouter));
    expect(await session(), connected());
  });

  test('pairing with a wrong password saves nothing', () async {
    await session();
    final wrong = PairedRouter(
      host: testRouter.host,
      password: 'wrong',
      pin: testRouter.pin,
    );
    await expectLater(
      notifier().pair(wrong),
      throwsA(isA<AuthenticationException>()),
    );
    expect(store.router, isNull);
    expect(await session(), isA<NeedsSetup>());
  });

  test('trusting a new certificate pins it and reconnects', () async {
    store.router = testRouter.withPin(otherFingerprint);
    expect(await session(), isA<CertificateChanged>());
    await notifier().trustCertificate(testCertificate.fingerprint);
    expect(store.router!.pin, testCertificate.fingerprint);
    expect(await session(), connected());
  });

  test('forgetting the router asks for setup again', () async {
    store.router = testRouter;
    await session();
    await notifier().forget();
    expect(store.router, isNull);
    expect(await session(), isA<NeedsSetup>());
  });

  test('demo mode lasts until it is stopped', () async {
    notifier().startDemo();
    expect(await session(), connected(demo: true));
    notifier().stopDemo();
    expect(await session(), isA<NeedsSetup>());
  });
}
