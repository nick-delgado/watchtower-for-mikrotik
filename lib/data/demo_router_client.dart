import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:routeros/routeros.dart';

/// A [RouterClient] that replays an anonymized capture from a real router.
/// Powers demo mode and tests.
///
/// The capture is made with `packages/routeros/bin/probe.dart` and
/// `bin/anonymize.dart`.
class DemoRouterClient implements RouterClient {
  DemoRouterClient(this._fixture);

  static const asset = 'assets/demo/router.json';

  static Future<DemoRouterClient> load([AssetBundle? bundle]) async {
    final json = await (bundle ?? rootBundle).loadString(asset);
    return DemoRouterClient(jsonDecode(json) as Map<String, Object?>);
  }

  final Map<String, Object?> _fixture;
  var _poll = 0;

  @override
  Future<List<Map<String, String>>> call(
    String command, {
    Map<String, String> params = const {},
    List<String> queries = const [],
  }) async {
    // Successive polls of the Wi-Fi clients return successive recordings, so
    // speeds change the way they would on a real router.
    final polls = _fixture['registrationPolls'] as List? ?? const [];
    if (command == '/interface/wifi/registration-table/print' &&
        polls.isNotEmpty) {
      return _rows((polls[_poll++ % polls.length] as Map)['rows']);
    }
    final rows = _fixture[command];
    if (rows == null) {
      throw RouterOsTrap('no such command ($command)', category: 0);
    }
    return _rows(rows);
  }

  @override
  Stream<Map<String, String>> stream(
    String command, {
    Map<String, String> params = const {},
    List<String> queries = const [],
  }) {
    if (command == '/log/listen') return _logLines();
    final recorded = _rows((_fixture['live'] as Map?)?[command]);
    if (recorded.isEmpty) return _quiet();
    return Stream.periodic(
      const Duration(seconds: 1),
      (i) => recorded[i % recorded.length],
    );
  }

  @override
  Future<void> close() async {}

  // Replays the log backlog as new lines, one every few seconds.
  Stream<Map<String, String>> _logLines() {
    final backlog = _rows(_fixture['/log/print']);
    if (backlog.isEmpty) return _quiet();
    return Stream.periodic(
      const Duration(seconds: 6),
      (i) => {
        ...backlog[i % backlog.length],
        '.id': '*D${i.toRadixString(16).toUpperCase()}',
        'time': _routerTime(DateTime.now()),
      },
    );
  }

  // Like `listen` on a list that doesn't change: open, but quiet.
  Stream<Map<String, String>> _quiet() =>
      StreamController<Map<String, String>>().stream;

  // Recording metadata such as `_ms` starts with an underscore.
  static List<Map<String, String>> _rows(Object? rows) => [
    for (final row in rows as List? ?? const [])
      {
        for (final MapEntry(:key, :value)
            in (row as Map).cast<String, Object?>().entries)
          if (!key.startsWith('_')) key: '$value',
      },
  ];

  static String _routerTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
