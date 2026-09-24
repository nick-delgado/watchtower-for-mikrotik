import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/app/app.dart';
import 'package:watchtower/app/format.dart';
import 'package:watchtower/data/paired_router.dart';

import '../support/fakes.dart';

void main() {
  late MemoryRouterStore store;
  late FakeConnector connector;
  late FakePermission permission;

  setUp(() {
    store = MemoryRouterStore()..router = testRouter;
    connector = FakeConnector();
    permission = FakePermission();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          store: store,
          connector: connector,
          permission: permission,
        ),
        child: const WatchtowerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // A tap on a list that's still moving only stops it.
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('connects straight to a paired router', (tester) async {
    await pumpApp(tester);
    expect(find.text('Home Router'), findsOneWidget);
  });

  testWidgets('retries an unreachable router', (tester) async {
    connector.error = const RouterOsException('No route to host');
    await pumpApp(tester);
    expect(find.text("Can't reach your router"), findsOneWidget);
    expect(find.text('No route to host'), findsOneWidget);

    connector.error = null;
    await tap(tester, 'Try again');
    expect(find.text('Home Router'), findsOneWidget);
  });

  testWidgets('trusts a recreated certificate after showing it', (
    tester,
  ) async {
    store.router = testRouter.withPin(otherFingerprint);
    await pumpApp(tester);
    expect(find.text("The router's certificate has changed"), findsOneWidget);
    expect(
      find.text(groupFingerprint(testCertificate.fingerprint)),
      findsOneWidget,
    );

    await tap(tester, 'Trust the new certificate');
    expect(find.text('Home Router'), findsOneWidget);
    expect(store.router!.pin, testCertificate.fingerprint);
  });

  testWidgets('sets up again after a rejected sign-in', (tester) async {
    store.router = PairedRouter(
      host: testRouter.host,
      password: 'wrong',
      pin: testRouter.pin,
    );
    await pumpApp(tester);
    expect(find.text('The router rejected the sign-in'), findsOneWidget);

    await tap(tester, 'Set up again');
    expect(find.text('Welcome to Watchtower'), findsOneWidget);
    expect(store.router, isNull);
  });

  testWidgets('sends the user to Settings without network access', (
    tester,
  ) async {
    permission.granted = false;
    await pumpApp(tester);
    expect(find.text('Local network access is off'), findsOneWidget);

    await tap(tester, 'Open Settings');
    expect(permission.settingsOpened, 1);
  });

  testWidgets('forgets the router from the menu', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tap(tester, 'Forget this router');
    await tap(tester, 'Forget');

    expect(find.text('Welcome to Watchtower'), findsOneWidget);
    expect(store.router, isNull);
  });
}
