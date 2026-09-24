import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/app/app.dart';
import 'package:watchtower/app/format.dart';
import 'package:watchtower/data/demo_router_client.dart';
import 'package:watchtower/data/providers.dart';

void main() {
  final fixture = jsonDecode(
    File(DemoRouterClient.asset).readAsStringSync(),
  ) as Map<String, Object?>;

  Widget app(RouterClient client) => ProviderScope(
    overrides: [routerClientProvider.overrideWith((ref) => client)],
    child: const WatchtowerApp(),
  );

  testWidgets('shows the demo router summary', (tester) async {
    await tester.pumpWidget(app(DemoRouterClient(fixture)));
    await tester.pumpAndSettle();

    expect(find.text('Home Router'), findsOneWidget);
    expect(find.text('hAP ax^3 · RouterOS 7.24.4 (stable)'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    for (final label in ['Uptime', 'CPU', 'Memory']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('offers a retry when the router fails', (tester) async {
    await tester.pumpWidget(app(DemoRouterClient({})));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load the router'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
  });

  test('formats durations compactly', () {
    expect(formatDuration(const Duration(days: 3, hours: 4)), '3d 4h');
    expect(formatDuration(const Duration(hours: 4, minutes: 12)), '4h 12m');
    expect(formatDuration(const Duration(minutes: 12, seconds: 5)), '12m');
    expect(formatDuration(const Duration(seconds: 45)), '45s');
  });
}
