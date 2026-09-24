import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/app/app.dart';
import 'package:watchtower/app/format.dart';
import 'package:watchtower/data/demo_router_client.dart';
import 'package:watchtower/data/session.dart';

import '../support/fakes.dart';

void main() {
  Future<void> pumpDemo(WidgetTester tester, RouterClient demo) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(
            store: MemoryRouterStore(),
            connector: FakeConnector(),
            permission: FakePermission(),
            demo: demo,
          ),
          demoModeProvider.overrideWith(() => Toggle(true)),
        ],
        child: const WatchtowerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the demo router summary', (tester) async {
    await pumpDemo(tester, demoClient());

    expect(find.text('Home Router'), findsOneWidget);
    expect(find.text('hAP ax³ · RouterOS 7.24.4 (stable)'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    for (final label in ['Uptime', 'CPU', 'Memory']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('offers a retry when the router fails', (tester) async {
    await pumpDemo(tester, DemoRouterClient({}));

    expect(find.textContaining('Could not load the router'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  test('formats durations compactly', () {
    expect(formatDuration(const Duration(days: 3, hours: 4)), '3d 4h');
    expect(formatDuration(const Duration(hours: 4, minutes: 12)), '4h 12m');
    expect(formatDuration(const Duration(minutes: 12, seconds: 5)), '12m');
    expect(formatDuration(const Duration(seconds: 45)), '45s');
  });

  test('groups fingerprints the way RouterOS prints them', () {
    expect(
      groupFingerprint(
        'B1:89:A5:AB:67:71:30:CF:19:70:B9:A8:8B:9F:96:13:'
        '46:88:C1:CE:A0:72:D9:C8:BB:EA:03:63:A3:00:F0:74',
      ),
      'b189a5ab 677130cf\n'
      '1970b9a8 8b9f9613\n'
      '4688c1ce a072d9c8\n'
      'bbea0363 a300f074',
    );
    expect(distinguishedName('/CN=watchtower'), 'CN=watchtower');
    expect(formatBoardName('hAP ax^3'), 'hAP ax³');
    expect(formatBoardName('hAP ac^2'), 'hAP ac²');
  });
}
