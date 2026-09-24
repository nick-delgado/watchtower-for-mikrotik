import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:routeros/routeros.dart';

/// Phase 0 probe: connects to the router the way the app will, checks which
/// data sources the read-only user can see, and records the live streams.
///
/// Raw captures contain private network details (MACs, hostnames, logs), so
/// they go to a git-ignored directory. Only field names and counts are printed.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('host', defaultsTo: '192.168.88.1')
    ..addOption('port', defaultsTo: '${RouterOsConnection.defaultPort}')
    ..addOption('user', defaultsTo: 'watchtower')
    ..addOption(
      'pin',
      help:
          'SHA-256 fingerprint of the router certificate. '
          'Without it, the probe only shows the certificate.',
    )
    ..addOption(
      'seconds',
      defaultsTo: '15',
      help: 'How long to record the live streams.',
    )
    ..addOption(
      'out',
      defaultsTo: 'probe-output',
      help: 'Where to write raw captures.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  if (args.flag('help')) {
    print(parser.usage);
    return;
  }

  try {
    await _probe(
      host: args.option('host')!,
      port: int.parse(args.option('port')!),
      user: args.option('user')!,
      pin: args.option('pin'),
      seconds: int.parse(args.option('seconds')!),
      outDir: args.option('out')!,
    );
  } on AuthenticationException catch (e) {
    stderr.writeln('✗ Login failed: ${e.message}');
    exitCode = 1;
  } on RouterOsException catch (e) {
    stderr.writeln('✗ ${e.message}');
    exitCode = 1;
  }
}

Future<void> _probe({
  required String host,
  required int port,
  required String user,
  required String? pin,
  required int seconds,
  required String outDir,
}) async {
  final certificate = await RouterOsConnection.fetchCertificate(
    host,
    port: port,
  );
  print(
    'Certificate  ${certificate.subject}  (issued by ${certificate.issuer})',
  );
  print(
    'Valid        ${_day(certificate.startValidity)} to '
    '${_day(certificate.endValidity)}',
  );
  print(
    'SHA-256      ${formatFingerprint(certificateFingerprint(certificate))}',
  );
  if (pin == null) {
    print(
      '\nNothing was sent to the router. Compare the fingerprint with '
      '`/certificate print detail where name=watchtower`, then re-run with --pin.',
    );
    return;
  }

  final connection = await RouterOsConnection.connect(
    host,
    port: port,
    pin: pin,
  );
  print('Certificate matches the pin.');
  try {
    await connection.login(user, await _password(user));
    print('Logged in as "$user".');
    await _explore(connection, host: host, seconds: seconds, outDir: outDir);
  } finally {
    await connection.close();
  }
}

Future<void> _explore(
  RouterOsConnection connection, {
  required String host,
  required int seconds,
  required String outDir,
}) async {
  final capture = <String, Object?>{
    'capturedAt': DateTime.now().toIso8601String(),
    'host': host,
  };
  final problems = <String>[];

  Future<List<Map<String, String>>> snapshot(
    String command, {
    List<String> queries = const [],
  }) async {
    try {
      final rows = await connection
          .call(command, queries: queries)
          .timeout(const Duration(seconds: 20));
      capture[command] = rows;
      print('✓ $command  (${rows.length})');
      final fields = {for (final row in rows) ...row.keys}.toList()..sort();
      if (fields.isNotEmpty) print('    ${fields.join(', ')}');
      return rows;
    } on RouterOsTrap catch (e) {
      problems.add('$command: ${e.message}');
      print('✗ $command  ${e.message}');
    } on TimeoutException {
      problems.add('$command: timed out');
      print('✗ $command  timed out');
    }
    return const [];
  }

  print('\n— Snapshots');
  final resource = await snapshot('/system/resource/print');
  await snapshot('/system/identity/print');
  await snapshot('/system/routerboard/print');
  await snapshot('/system/package/print');
  await snapshot('/interface/print');
  final wanMembers = await snapshot(
    '/interface/list/member/print',
    queries: ['?list=WAN'],
  );
  final defaultRoutes = await snapshot(
    '/ip/route/print',
    queries: ['?dst-address=0.0.0.0/0'],
  );
  await snapshot('/interface/wifi/print');
  await snapshot('/interface/wifi/registration-table/print');
  await snapshot('/ip/dhcp-server/lease/print');
  await snapshot('/ip/arp/print');
  await snapshot('/log/print');

  if (resource.isNotEmpty) {
    print(
      '\nRouterOS ${resource.first['version']} on '
      '${resource.first['board-name']}',
    );
  }
  final wan = _wanInterface(wanMembers, defaultRoutes);
  print(
    wan == null
        ? 'Could not determine the WAN interface.'
        : 'WAN interface: $wan',
  );

  print('\n— Live streams for ${seconds}s');
  final clock = Stopwatch()..start();
  final live = <String, List<Map<String, String>>>{};
  final subscriptions = <StreamSubscription<Map<String, String>>>[];

  void record(String command, {Map<String, String> params = const {}}) {
    final events = live[command] = [];
    subscriptions.add(
      connection
          .stream(command, params: params)
          .listen(
            (event) =>
                events.add({'_ms': '${clock.elapsedMilliseconds}', ...event}),
            onError: (Object e) => problems.add(
              '$command: ${e is RouterOsException ? e.message : e}',
            ),
          ),
    );
  }

  if (wan != null) {
    record('/interface/monitor-traffic', params: {'interface': wan});
  }
  record('/log/listen');
  record('/interface/wifi/registration-table/listen');

  // Per-client speeds come from polling the registration table's byte counters.
  final polls = <Map<String, Object>>[];
  final poller = Timer.periodic(const Duration(seconds: 2), (_) async {
    final ms = clock.elapsedMilliseconds;
    try {
      final rows = await connection.call(
        '/interface/wifi/registration-table/print',
      );
      polls.add({'_ms': ms, 'rows': rows});
    } on RouterOsException catch (e) {
      problems.add('registration-table poll: ${e.message}');
    }
  });

  await Future<void>.delayed(Duration(seconds: seconds));
  poller.cancel();
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }

  for (final MapEntry(key: command, value: events) in live.entries) {
    print('✓ $command  (${events.length} events)');
    final fields = {for (final e in events) ...e.keys}.toList()..sort();
    if (fields.isNotEmpty) print('    ${fields.join(', ')}');
  }
  final traffic = live['/interface/monitor-traffic'] ?? const [];
  for (final sample in traffic.take(3)) {
    print(
      '    rx ${_mbps(sample['rx-bits-per-second'])}  '
      'tx ${_mbps(sample['tx-bits-per-second'])}',
    );
  }
  print('✓ registration-table polls  (${polls.length})');
  _printClientRates(polls);

  capture['live'] = live;
  capture['registrationPolls'] = polls;
  final file = File('$outDir/capture-${_fileStamp()}.json');
  file
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(capture));
  print('\nRaw capture (private data): ${file.path}');

  if (problems.isNotEmpty) {
    print('\n— Problems');
    for (final problem in problems) {
      print('  $problem');
    }
  }
}

/// First enabled member of the WAN interface list, else the interface the
/// active default route goes out of.
String? _wanInterface(
  List<Map<String, String>> wanMembers,
  List<Map<String, String>> defaultRoutes,
) {
  for (final member in wanMembers) {
    final name = member['interface'];
    if (name != null && member['disabled'] != 'true') return name;
  }
  for (final route in defaultRoutes) {
    if (route['active'] != 'true') continue;
    final gateway = route['immediate-gw'] ?? route['gateway'] ?? '';
    final percent = gateway.indexOf('%');
    if (percent != -1) return gateway.substring(percent + 1);
  }
  return null;
}

/// Prints each client's speed from the last poll. The router's own rate
/// fields are used because its `bytes` counters only refresh every ~4 s.
/// `tx` is router → client, so it's the client's download.
void _printClientRates(List<Map<String, Object>> polls) {
  if (polls.isEmpty) return;
  for (final row in polls.last['rows'] as List<Map<String, String>>) {
    final mac = row['mac-address'] ?? '?????';
    print(
      '    ${row['interface']}  …${mac.substring(mac.length - 5)}  '
      'down ${_mbps(row['tx-bits-per-second'])}  '
      'up ${_mbps(row['rx-bits-per-second'])}  '
      'signal ${row['signal'] ?? '?'}',
    );
  }
}

/// Reads the password from WATCHTOWER_PASSWORD, or from the macOS Keychain
/// item created during setup (service "watchtower-router").
Future<String> _password(String user) async {
  final fromEnv = Platform.environment['WATCHTOWER_PASSWORD'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final result = await Process.run('security', [
    'find-generic-password',
    '-s',
    'watchtower-router',
    '-a',
    user,
    '-w',
  ]);
  if (result.exitCode != 0) {
    throw const RouterOsException(
      'No password found: set WATCHTOWER_PASSWORD '
      'or add the "watchtower-router" Keychain item',
    );
  }
  return (result.stdout as String).trim();
}

String _mbps(String? bitsPerSecond) {
  final value = double.tryParse(bitsPerSecond ?? '');
  return value == null ? '?' : '${(value / 1e6).toStringAsFixed(2)} Mbps';
}

String _day(DateTime time) => time.toIso8601String().substring(0, 10);

String _fileStamp() =>
    DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
