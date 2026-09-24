import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routeros/routeros.dart';
import 'package:watchtower/data/demo_router_client.dart';

void main() {
  final fixture = jsonDecode(
    File(DemoRouterClient.asset).readAsStringSync(),
  ) as Map<String, Object?>;
  late DemoRouterClient client;

  setUp(() => client = DemoRouterClient(fixture));

  test('answers one-off commands from the capture', () async {
    final identity = await client.call('/system/identity/print');
    expect(identity.single['name'], 'Home Router');
  });

  test('fails unknown commands the way a router does', () {
    expect(client.call('/nothing/print'), throwsA(isA<RouterOsTrap>()));
  });

  test('returns successive recorded polls of the Wi-Fi clients', () async {
    final polls = fixture['registrationPolls'] as List;
    List<Object?> macs(Object? rows) => [
      for (final row in rows as List) (row as Map)['mac-address'],
    ];

    for (var i = 0; i < polls.length + 1; i++) {
      final rows = await client.call(
        '/interface/wifi/registration-table/print',
      );
      final expected = (polls[i % polls.length] as Map)['rows'];
      expect(rows.map((r) => r['mac-address']), macs(expected));
      expect(rows.first.keys, isNot(contains('_ms')));
    }
  });

  test('streams recorded traffic once a second', () {
    fakeAsync((async) {
      final samples = <Map<String, String>>[];
      final subscription = client
          .stream('/interface/monitor-traffic', params: {'interface': 'ether1'})
          .listen(samples.add);
      async.elapse(const Duration(milliseconds: 3500));
      expect(samples, hasLength(3));
      expect(samples.first['rx-bits-per-second'], isNotNull);
      expect(samples.first.keys, isNot(contains('_ms')));
      subscription.cancel();
    });
  });

  test('emits log lines stamped like the router does', () {
    fakeAsync((async) {
      final lines = <Map<String, String>>[];
      final subscription = client.stream('/log/listen').listen(lines.add);
      async.elapse(const Duration(seconds: 13));
      expect(lines, hasLength(2));
      expect(lines.first['time'], matches(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$'));
      expect(lines.first['message'], isNotEmpty);
      expect(lines.map((l) => l['.id']).toSet(), hasLength(2));
      subscription.cancel();
    });
  });
}
