import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routeros/routeros.dart';

import 'router_summary.dart';
import 'session.dart';

/// The current session's client, or null when there isn't a connection.
final routerClientProvider = Provider<RouterClient?>(
  (ref) => switch (ref.watch(sessionProvider).value) {
    Connected(:final client) => client,
    _ => null,
  },
);

final routerSummaryProvider = FutureProvider<RouterSummary>((ref) async {
  final client = ref.watch(routerClientProvider);
  if (client == null) throw StateError('Not connected to a router');
  return RouterSummary.fetch(client);
});
