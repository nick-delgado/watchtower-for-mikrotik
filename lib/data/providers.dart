import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routeros/routeros.dart';

import 'demo_router_client.dart';
import 'router_summary.dart';

/// The router session the app talks to. Always the demo router until
/// pairing and real connections are built.
final routerClientProvider = FutureProvider<RouterClient>((ref) async {
  final client = await DemoRouterClient.load();
  ref.onDispose(client.close);
  return client;
});

final routerSummaryProvider = FutureProvider<RouterSummary>((ref) async {
  final client = await ref.watch(routerClientProvider.future);
  return RouterSummary.fetch(client);
});
