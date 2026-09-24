import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/app/app.dart';
import 'package:watchtower/app/format.dart';
import 'package:watchtower/data/session.dart';

/// Pairs with a real router, end to end, and screenshots each step. Run it
/// on a simulator or phone on the router's network:
///
/// ```sh
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/pairing_test.dart \
///   --dart-define=ROUTER_PASSWORD=... --dart-define=ROUTER_PIN=...
/// ```
///
/// ROUTER_HOST defaults to 192.168.88.1. Screenshots go to
/// `build/screenshots/`.
const _password = String.fromEnvironment('ROUTER_PASSWORD');
const _pin = String.fromEnvironment('ROUTER_PIN');
const _host = String.fromEnvironment(
  'ROUTER_HOST',
  defaultValue: '192.168.88.1',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pairs with the router and shows its summary', (tester) async {
    if (_password.isEmpty || _pin.isEmpty) {
      markTestSkipped('Set ROUTER_PASSWORD and ROUTER_PIN.');
      return;
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(pairedRouterStoreProvider);
    await store.clear();
    addTearDown(store.clear);

    Future<void> tap(String text) async {
      final button = find.text(text);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // A tap on a list that's still moving only stops it.
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WatchtowerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('1-welcome');

    await tap('Connect your router');
    await binding.takeScreenshot('2-prepare');

    await tap('I know the password of an existing user');
    await tester.enterText(find.byType(TextField), _password);
    await tester.pump();
    await tap('Next');

    await tester.enterText(find.byType(TextField), _host);
    await binding.takeScreenshot('3-address');
    await tap('Next');

    expect(find.text(groupFingerprint(_pin)), findsOneWidget);
    await binding.takeScreenshot('4-certificate');

    await tap('It matches: connect');
    expect(find.textContaining('RouterOS 7.'), findsOneWidget);
    expect(find.text('Demo'), findsNothing);
    expect((await store.load())?.pin, normalizeFingerprint(_pin));
    await binding.takeScreenshot('5-connected');
  });
}
