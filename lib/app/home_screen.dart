import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_router_client.dart';
import '../data/providers.dart';
import '../data/router_summary.dart';
import 'format.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(routerClientProvider).value is DemoRouterClient;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchtower'),
        actions: [
          if (isDemo)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(label: Text('Demo')),
            ),
        ],
      ),
      body: ref
          .watch(routerSummaryProvider)
          .when(
            data: (summary) => RefreshIndicator(
              onRefresh: () => ref.refresh(routerSummaryProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [RouterSummaryCard(summary: summary)],
              ),
            ),
            error: (error, _) => _LoadError(
              error: error,
              onRetry: () => ref.invalidate(routerSummaryProvider),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }
}

class RouterSummaryCard extends StatelessWidget {
  const RouterSummaryCard({super.key, required this.summary});

  final RouterSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uptime = summary.uptime;
    final cpuLoad = summary.cpuLoad;
    final memoryUsed = summary.memoryUsed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.router_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.identity, style: theme.textTheme.titleLarge),
                      Text(
                        '${summary.board} · RouterOS ${summary.version}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(
                  label: 'Uptime',
                  value: uptime == null ? '–' : formatDuration(uptime),
                ),
                _Stat(label: 'CPU', value: cpuLoad == null ? '–' : '$cpuLoad%'),
                _Stat(
                  label: 'Memory',
                  value: memoryUsed == null
                      ? '–'
                      : '${(memoryUsed * 100).round()}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load the router.\n$error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
