import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/data/demo_router_client.dart';
import 'package:watchtower/data/router_summary.dart';
import 'package:watchtower/data/routeros_values.dart';

void main() {
  test('reads the summary from a router', () async {
    final client = DemoRouterClient(
      jsonDecode(File(DemoRouterClient.asset).readAsStringSync())
          as Map<String, Object?>,
    );
    final summary = await RouterSummary.fetch(client);
    expect(summary.identity, 'Home Router');
    expect(summary.board, 'hAP ax^3');
    expect(summary.version, '7.24.4 (stable)');
    expect(summary.uptime, isNotNull);
    expect(summary.cpuLoad, inInclusiveRange(0, 100));
    expect(summary.memoryUsed, inExclusiveRange(0, 1));
  });

  test('leaves out values the router did not send', () {
    final summary = RouterSummary.fromReplies(identity: {}, resource: {});
    expect(summary.identity, 'MikroTik');
    expect(summary.uptime, isNull);
    expect(summary.cpuLoad, isNull);
    expect(summary.memoryUsed, isNull);
  });

  group('parseRouterOsDuration', () {
    const cases = {
      '1w2d3h4m5s': Duration(days: 9, hours: 3, minutes: 4, seconds: 5),
      '6h50m49s': Duration(hours: 6, minutes: 50, seconds: 49),
      '15s20ms': Duration(seconds: 15, milliseconds: 20),
      '5m': Duration(minutes: 5),
    };
    cases.forEach((text, duration) {
      test(text, () => expect(parseRouterOsDuration(text), duration));
    });

    test('rejects anything else', () {
      for (final text in [null, '', 'never', '5x', '1h 2m', '00:05:00']) {
        expect(parseRouterOsDuration(text), isNull, reason: '$text');
      }
    });
  });
}
