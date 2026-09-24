import 'package:routeros/routeros.dart';

import 'routeros_values.dart';

/// Headline facts about the router, shown at the top of the dashboard.
class RouterSummary {
  const RouterSummary({
    required this.identity,
    required this.board,
    required this.version,
    this.uptime,
    this.cpuLoad,
    this.memoryUsed,
  });

  factory RouterSummary.fromReplies({
    required Map<String, String> identity,
    required Map<String, String> resource,
    Map<String, String> routerboard = const {},
  }) {
    final total = int.tryParse(resource['total-memory'] ?? '');
    final free = int.tryParse(resource['free-memory'] ?? '');
    return RouterSummary(
      identity: identity['name'] ?? 'MikroTik',
      board: resource['board-name'] ?? routerboard['model'] ?? 'MikroTik',
      version: resource['version'] ?? '?',
      uptime: parseRouterOsDuration(resource['uptime']),
      cpuLoad: int.tryParse(resource['cpu-load'] ?? ''),
      memoryUsed: total == null || free == null || total == 0
          ? null
          : (total - free) / total,
    );
  }

  static Future<RouterSummary> fetch(RouterClient client) async {
    final [identity, resource, routerboard] = await Future.wait([
      client.call('/system/identity/print'),
      client.call('/system/resource/print'),
      client.call('/system/routerboard/print'),
    ]);
    return RouterSummary.fromReplies(
      identity: identity.firstOrNull ?? const {},
      resource: resource.firstOrNull ?? const {},
      routerboard: routerboard.firstOrNull ?? const {},
    );
  }

  /// The router's name (`/system identity`).
  final String identity;

  /// Model, e.g. `hAP ax^3`.
  final String board;

  /// RouterOS version, e.g. `7.24.4 (stable)`.
  final String version;

  final Duration? uptime;

  /// CPU load in percent.
  final int? cpuLoad;

  /// Share of memory in use, 0–1.
  final double? memoryUsed;
}
