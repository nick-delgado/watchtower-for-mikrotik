import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/app/app.dart';
import 'package:watchtower/app/format.dart';

import '../support/fakes.dart';

void main() {
  late MemoryRouterStore store;
  late FakeConnector connector;
  late FakePermission permission;

  setUp(() {
    store = MemoryRouterStore();
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

  Future<void> useExistingPassword(WidgetTester tester, String password) async {
    await tap(tester, 'Connect your router');
    await tap(tester, 'I know the password of an existing user');
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
    await tap(tester, 'Next');
  }

  testWidgets('pairs using the password in the setup commands', (tester) async {
    await pumpApp(tester);
    await tap(tester, 'Connect your router');

    final userCommand = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((text) => text.data!)
        .singleWhere((command) => command.startsWith('/user add'));
    final password = RegExp(r'password="(\w+)"').firstMatch(userCommand)![1]!;
    connector.password = password;
    await tap(tester, "I've run the commands");

    final address = tester.widget<TextField>(find.byType(TextField));
    expect(address.controller!.text, '192.168.88.1');
    await tap(tester, 'Next');

    expect(
      find.text(groupFingerprint(testCertificate.fingerprint)),
      findsOneWidget,
    );
    await tap(tester, 'It matches: connect');

    expect(find.text('Home Router'), findsOneWidget);
    expect(find.text('Demo'), findsNothing);
    expect(store.router?.password, password);
    expect(store.router?.pin, testCertificate.fingerprint);
  });

  testWidgets('pairs using the password of an existing user', (tester) async {
    await pumpApp(tester);
    await useExistingPassword(tester, 'secret');
    await tap(tester, 'Next');
    await tap(tester, 'It matches: connect');

    expect(find.text('Home Router'), findsOneWidget);
    expect(store.router?.password, 'secret');
  });

  testWidgets('explains a rejected password and saves nothing', (tester) async {
    await pumpApp(tester);
    await useExistingPassword(tester, 'wrong');
    await tap(tester, 'Next');
    await tap(tester, 'It matches: connect');

    expect(find.textContaining('rejected the password'), findsOneWidget);
    expect(store.router, isNull);
  });

  testWidgets('explains an unreachable router', (tester) async {
    connector.error = const RouterOsException('No route to host');
    await pumpApp(tester);
    await useExistingPassword(tester, 'secret');
    await tap(tester, 'Next');

    expect(
      find.textContaining("Couldn't reach 192.168.88.1 on port 8729"),
      findsOneWidget,
    );
    expect(find.text('Find your router'), findsOneWidget);
  });

  testWidgets('asks for local network access', (tester) async {
    permission.granted = false;
    await pumpApp(tester);
    await useExistingPassword(tester, 'secret');
    await tap(tester, 'Next');

    expect(find.textContaining('needs permission'), findsOneWidget);
    await tap(tester, 'Open Settings');
    expect(permission.settingsOpened, 1);
    expect(connector.connected, isEmpty);
  });

  testWidgets('goes back a step', (tester) async {
    await pumpApp(tester);
    await tap(tester, 'Connect your router');
    expect(find.text('Prepare your router'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Watchtower'), findsOneWidget);
  });

  testWidgets('opens and exits the demo', (tester) async {
    await pumpApp(tester);
    await tap(tester, 'Try the demo');
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Home Router'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tap(tester, 'Exit demo');
    expect(find.text('Welcome to Watchtower'), findsOneWidget);
  });
}
