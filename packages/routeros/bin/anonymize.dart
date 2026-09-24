import 'dart:convert';
import 'dart:io';

/// Turns a raw probe capture into a fixture that is safe to commit and to
/// ship in demo mode.
///
/// MAC and IP addresses, hostnames, SSIDs, comments, the router's identity
/// and serial number, and usernames in logs are replaced consistently across
/// the whole capture. Free-text DHCP fields are blanked and only generic log
/// topics are kept. Nothing is written if any original value would remain.
///
/// Usage: `dart run bin/anonymize.dart <capture.json> <fixture.json>`
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run bin/anonymize.dart <capture.json> <fixture.json>',
    );
    exitCode = 64;
    return;
  }
  final capture =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, Object?>;
  final anonymizer = Anonymizer(capture);
  final json = const JsonEncoder.withIndent('  ').convert(anonymizer.fixture);
  final leaks = anonymizer.leaks();
  if (leaks.isNotEmpty) {
    stderr.writeln('✗ Not written. Still present: ${leaks.join(', ')}');
    exitCode = 1;
    return;
  }
  File(args[1])
    ..createSync(recursive: true)
    ..writeAsStringSync('$json\n');
  print('✓ Wrote ${args[1]}: ${anonymizer.summary}');
}

class Anonymizer {
  Anonymizer(Map<String, Object?> capture) {
    _collect(capture, null);
    _assignNames();
    fixture = _transform(capture, null) as Map<String, Object?>;
  }

  /// The anonymized capture.
  late final Map<String, Object?> fixture;

  final _originals = <String, Set<String>>{};
  final _seenIpv4 = <String>{};
  final _names = <String, String>{};
  final _macs = <String, String>{};
  final _ipv4 = <String, String>{};
  final _ipv6 = <String, String>{};
  late final List<(RegExp, String)> _namePatterns;
  var _logsKept = 0;
  var _logsDropped = 0;

  String get summary =>
      'replaced ${_macs.length} MACs, ${_ipv4.length + _ipv6.length} IPs, '
      '${_names.length} names; kept $_logsKept log entries, '
      'dropped $_logsDropped';

  /// Describes original values still present in the fixture, without
  /// revealing them. Product fields are skipped: a name that also appears
  /// in the board name (e.g. identity "hAP") isn't private there.
  List<String> leaks() {
    final output = jsonEncode(_withoutProductFields(fixture));
    final found = <String>[];
    void check(String label, Iterable<String> originals) {
      final count = originals.where((o) => _word(o).hasMatch(output)).length;
      if (count > 0) found.add('$count $label');
    }

    check('MAC addresses', _macs.keys);
    check('IP addresses', [..._ipv4.keys, ..._ipv6.keys]);
    check('names', _names.keys);
    return found;
  }

  static Object? _withoutProductFields(Object? value) => switch (value) {
    Map() => {
      for (final MapEntry(:key, :value) in value.entries)
        if (!_productKeys.contains(key)) key: _withoutProductFields(value),
    },
    List() => [for (final item in value) _withoutProductFields(item)],
    _ => value,
  };

  // Values that aren't private and would be mangled if replaced everywhere.
  static const _generic = {
    'mikrotik',
    'admin',
    'watchtower',
    'localhost',
    'defconf',
  };

  // Describe the hardware and software, never the owner. Names are not
  // replaced inside them.
  static const _productKeys = {
    'board-name',
    'model',
    'platform',
    'cpu',
    'architecture-name',
    'firmware-type',
    'version',
    'default-name',
    'type',
  };

  static const _pools = {
    'identity': ['Home Router'],
    'serial': ['HF0000001'],
    'ssid': ['Home-WiFi', 'Home-WiFi-2G', 'Guest-WiFi', 'IoT-WiFi'],
    'host': [
      'Living-Room-TV', 'iPhone-15', 'Galaxy-S24', 'MacBook-Air', 'Pixel-9',
      'Kitchen-Speaker', 'Nest-Thermostat', 'Ring-Doorbell', 'Office-Printer',
      'Kids-iPad', 'Xbox-Series-X', 'Roku-Ultra', 'Echo-Dot', 'Work-Laptop',
      'Desktop-PC', 'Garage-Camera', 'Smart-Plug', 'Chromecast',
      'Robot-Vacuum', 'Hue-Bridge', 'Sonos-One', 'Galaxy-Tab', 'Kindle',
      'Apple-TV', //
    ],
    'comment': [
      'Family Laptop', "Kid's Tablet", 'Smart TV', 'Printer', 'Thermostat',
      'Game Console', //
    ],
    'user': ['admin'],
  };

  static const _blankedKeys = {
    'extra-info',
    'client-id',
    'active-client-id',
    'agent-circuit-id',
    'agent-remote-id',
    'active-agent-circuit-id',
    'active-agent-remote-id',
  };

  static const _droppedKeys = {'host'};

  // Only these log topics are kept, and never debug output.
  static const _logTopics = {'system', 'wireless', 'dhcp', 'interface'};

  static final _macPattern = RegExp(
    r'(?<![0-9A-Fa-f])(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f])',
  );
  static final _ipv4Pattern = RegExp(
    r'(?<![\d.])\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(?!\d)(?!\.\d)',
  );
  // Candidates only; _v6 accepts those with '::' or 7 colons, which rules
  // out times like 09:51:40.
  static final _ipv6Pattern = RegExp(
    r'(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}(?![0-9A-Fa-f:])',
  );
  // Names that can appear only in logs, e.g. a device that has since left.
  static final _userPattern = RegExp(r'\buser (\S+)');
  static final _dhcpHostPattern = RegExp(
    r'\b(?:de)?assigned \S+ (?:for|to) \S+ (\S+)',
  );
  static final _wifiSsidPattern = RegExp(r'@[\w-]+\(([^)]+)\)');
  static final _ddnsPattern = RegExp(r'[0-9a-f]{12}\.sn\.mynetname\.net');

  static RegExp _word(String value) => RegExp(
    '(?<![\\w-])${RegExp.escape(value)}(?![\\w-])',
    caseSensitive: false,
  );

  void _collect(Object? value, String? key) {
    if (value is Map) {
      value.forEach((k, v) => _collect(v, k as String));
    } else if (value is List) {
      for (final item in value) {
        _collect(item, key);
      }
    } else if (value is String) {
      _seenIpv4.addAll(_ipv4Pattern.allMatches(value).map((m) => m[0]!));
      switch (key) {
        case 'host-name':
          _original('host', value);
        case 'ssid' || 'configuration.ssid':
          _original('ssid', value);
        case 'comment':
          _original('comment', value);
        case 'serial-number':
          _original('serial', value);
        case 'message':
          for (final match in _userPattern.allMatches(value)) {
            _original('user', match[1]!);
          }
          for (final match in _dhcpHostPattern.allMatches(value)) {
            _original('host', match[1]!);
          }
          for (final match in _wifiSsidPattern.allMatches(value)) {
            _original('ssid', match[1]!);
          }
      }
    }
    if (key == '/system/identity/print' && value is List) {
      for (final row in value) {
        _original('identity', (row as Map)['name']);
      }
    }
  }

  void _original(String category, Object? value) {
    if (value is! String || value.trim().length < 3) return;
    if (_generic.contains(value.toLowerCase())) return;
    (_originals[category] ??= {}).add(value);
  }

  void _assignNames() {
    final taken = {
      for (final values in _originals.values)
        for (final value in values) value.toLowerCase(),
    };
    _pools.forEach((category, pool) {
      Iterable<String> candidates() sync* {
        yield* pool;
        for (var i = 2; ; i++) {
          yield '${pool.first}-$i';
        }
      }

      final fresh = candidates()
          .where((c) => !taken.contains(c.toLowerCase()))
          .iterator;
      for (final original in _originals[category] ?? const <String>{}) {
        if (_names.containsKey(original)) continue;
        fresh.moveNext();
        _names[original] = fresh.current;
      }
    });
    // Longest first, so a hostname is replaced before a username inside it.
    _namePatterns = [
      for (final original
          in _names.keys.toList()..sort((a, b) => b.length - a.length))
        (_word(original), _names[original]!),
    ];
  }

  Object? _transform(Object? value, String? key) {
    if (value is Map) {
      return <String, Object?>{
        for (final MapEntry(key: k as String, value: v) in value.entries)
          if (!_droppedKeys.contains(k)) k: _transform(_filterLogs(k, v), k),
      };
    }
    if (value is List) return [for (final item in value) _transform(item, key)];
    if (value is String) return _text(value, key);
    return value;
  }

  Object? _filterLogs(String key, Object? value) {
    if ((key != '/log/print' && key != '/log/listen') || value is! List) {
      return value;
    }
    return value.where((entry) {
      final topics = ((entry as Map)['topics'] as String? ?? '').split(',');
      final keep =
          entry['.dead'] == null &&
          _logTopics.contains(topics.first) &&
          !topics.contains('container') &&
          !topics.contains('debug');
      keep ? _logsKept++ : _logsDropped++;
      return keep;
    }).toList();
  }

  String _text(String value, String? key) {
    if (_blankedKeys.contains(key)) return '';
    var text = value.replaceAllMapped(_macPattern, (m) => _mac(m[0]!));
    text = text.replaceAllMapped(_ipv6Pattern, (m) => _v6(m[0]!));
    text = text.replaceAllMapped(_ipv4Pattern, (m) => _v4(m[0]!));
    text = text.replaceAll(_ddnsPattern, 'example.sn.mynetname.net');
    if (_productKeys.contains(key)) return text;
    for (final (pattern, replacement) in _namePatterns) {
      text = text.replaceAll(pattern, replacement);
    }
    return text;
  }

  String _mac(String original) {
    final fake = _macs.putIfAbsent(
      original.toUpperCase().replaceAll('-', ':'),
      () {
        final n = _macs.length + 1;
        return '02:57:54:00:${_hex(n >> 8)}:${_hex(n & 0xFF)}';
      },
    );
    return original == original.toLowerCase() ? fake.toLowerCase() : fake;
  }

  String _v4(String original) {
    final octets = original.split('.').map(int.parse).toList();
    if (octets.any((o) => o > 255)) return original;
    final [a, b, c, d] = octets;
    // Unspecified, broadcast/netmasks, loopback and the router's own
    // default LAN address are generic.
    if (a == 0 || a == 255 || a == 127) return original;
    final lan = a == 192 && b == 168 && c == 88;
    if (lan && (d == 0 || d == 1 || d == 255)) return original;
    return _ipv4.putIfAbsent(original, () {
      if (lan) return _unused('192.168.88.', 20);
      final private =
          a == 10 ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a == 100 && b >= 64 && b <= 127);
      return private ? _unused('10.99.0.', 1) : _unused('203.0.113.', 1);
    });
  }

  // Next address in [prefix] that's neither in the capture nor handed out.
  String _unused(String prefix, int start) {
    for (var host = start; host < 255; host++) {
      final candidate = '$prefix$host';
      if (!_seenIpv4.contains(candidate) && !_ipv4.containsValue(candidate)) {
        return candidate;
      }
    }
    throw StateError('Ran out of addresses in $prefix');
  }

  String _v6(String original) {
    final colons = ':'.allMatches(original).length;
    if (!original.contains('::') && colons != 7) return original;
    if (original == '::' || original == '::1') return original;
    return _ipv6.putIfAbsent(
      original.toLowerCase(),
      () => '2001:db8::${(_ipv6.length + 1).toRadixString(16)}',
    );
  }

  static String _hex(int byte) =>
      byte.toRadixString(16).padLeft(2, '0').toUpperCase();
}
