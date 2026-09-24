import 'dart:convert';

import 'package:test/test.dart';

import '../bin/anonymize.dart';

void main() {
  final capture = <String, Object?>{
    'host': '192.168.88.1',
    '/system/identity/print': [
      {'name': 'Smith Family Router'},
    ],
    '/system/routerboard/print': [
      {'serial-number': 'HGX12345ABC', 'model': 'C53UiG+5HPaxD2HPaxD'},
    ],
    '/interface/wifi/print': [
      {
        'name': 'wifi1',
        'configuration.ssid': 'Smith Home',
        'mac-address': 'AA:BB:CC:11:22:33',
      },
    ],
    '/ip/route/print': [
      {'gateway': '73.12.34.1', 'immediate-gw': '73.12.34.1%ether1'},
    ],
    '/ip/dhcp-server/lease/print': [
      {
        'address': '192.168.88.20',
        'mac-address': 'AA:BB:CC:44:55:66',
        'host-name': 'Johns-iPhone',
        'client-id': '1:aa:bb:cc:44:55:66',
        'comment': 'John phone',
        'server': 'defconf',
      },
    ],
    '/log/print': [
      {
        '.id': '*1',
        'time': '2026-09-24 09:00:00',
        'topics': 'dhcp,info',
        'message':
            'defconf assigned 192.168.88.20 for AA:BB:CC:44:55:66 Johns-iPhone',
      },
      {
        '.id': '*2',
        'time': '2026-09-24 09:00:01',
        'topics': 'system,info,account',
        'message': 'user john logged in from 192.168.88.20 via winbox',
      },
      {
        '.id': '*3',
        'time': '2026-09-24 09:00:02',
        'topics': 'dhcp,info',
        'message': 'defconf deassigned 192.168.88.30 for AA:BB:CC:77:88:99 Marias-Laptop',
      },
      {
        '.id': '*4',
        'time': '2026-09-24 09:00:03',
        'topics': 'wireless,info',
        'message': 'AA:BB:CC:77:88:99@wifi2(Smith Old Network) disconnected',
      },
      {
        '.id': '*5',
        'time': '2026-09-24 09:00:04',
        'topics': 'container,error,debug',
        'message': 'pull failed for smith-app',
      },
    ],
    'live': {
      '/log/listen': [
        {'.dead': 'true', '.id': '*0'},
      ],
    },
    'registrationPolls': [
      {
        '_ms': 2000,
        'rows': [
          {'mac-address': 'AA:BB:CC:44:55:66', 'ssid': 'Smith Home'},
        ],
      },
    ],
  };

  late Anonymizer anonymizer;
  late Map<String, Object?> fixture;
  late String json;

  setUp(() {
    anonymizer = Anonymizer(capture);
    fixture = anonymizer.fixture;
    json = jsonEncode(fixture);
  });

  List<Map<String, Object?>> rows(String command) => [
    for (final row in fixture[command] as List) row as Map<String, Object?>,
  ];

  test('removes every private value', () {
    for (final original in [
      'smith',
      'john',
      'maria',
      'AA:BB:CC',
      'aa:bb:cc',
      '73.12.34.1',
      '192.168.88.20',
      'HGX12345ABC',
    ]) {
      expect(json.toLowerCase(), isNot(contains(original.toLowerCase())));
    }
    expect(anonymizer.leaks(), isEmpty);
    expect(fixture.containsKey('host'), isFalse);
  });

  test('replaces values consistently across commands', () {
    final lease = rows('/ip/dhcp-server/lease/print').single;
    final polled =
        ((fixture['registrationPolls'] as List).single as Map)['rows'] as List;
    expect((polled.single as Map)['mac-address'], lease['mac-address']);
    expect(
      (polled.single as Map)['ssid'],
      rows('/interface/wifi/print').single['configuration.ssid'],
    );
    final message = rows('/log/print').first['message'] as String;
    expect(
      message,
      'defconf assigned ${lease['address']} for ${lease['mac-address']} '
      '${lease['host-name']}',
    );
  });

  test('keeps generic values and structure', () {
    expect(rows('/system/identity/print').single['name'], 'Home Router');
    expect(
      rows('/system/routerboard/print').single['model'],
      'C53UiG+5HPaxD2HPaxD',
    );
    expect(rows('/ip/route/print').single['immediate-gw'], endsWith('%ether1'));
    expect(rows('/log/print').first['time'], '2026-09-24 09:00:00');
    expect(rows('/ip/dhcp-server/lease/print').single['server'], 'defconf');
  });

  test('keeps product names that contain the router identity', () {
    final anonymizer = Anonymizer({
      '/system/identity/print': [
        {'name': 'hAP'},
      ],
      '/system/resource/print': [
        {'board-name': 'hAP ax^3'},
      ],
    });
    final fixture = anonymizer.fixture;
    expect(
      ((fixture['/system/identity/print'] as List).single as Map)['name'],
      'Home Router',
    );
    expect(
      ((fixture['/system/resource/print'] as List).single as Map)['board-name'],
      'hAP ax^3',
    );
    expect(anonymizer.leaks(), isEmpty);
  });

  test('blanks client ids and drops container, debug and .dead logs', () {
    expect(rows('/ip/dhcp-server/lease/print').single['client-id'], '');
    expect(rows('/log/print').map((e) => e['.id']), ['*1', '*2', '*3', '*4']);
    expect((fixture['live'] as Map)['/log/listen'], isEmpty);
    expect(rows('/log/print')[1]['message'], startsWith('user admin '));
  });
}
