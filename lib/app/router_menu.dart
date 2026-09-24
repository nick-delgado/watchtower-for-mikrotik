import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session.dart';

/// App bar menu: "Exit demo" in demo mode, otherwise "Forget this router".
class RouterMenuButton extends ConsumerWidget {
  const RouterMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final isDemo = session is Connected && session.isDemo;
    final notifier = ref.read(sessionProvider.notifier);
    return PopupMenuButton<VoidCallback>(
      tooltip: 'More',
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        if (isDemo)
          PopupMenuItem(
            value: notifier.stopDemo,
            child: const Text('Exit demo'),
          )
        else
          PopupMenuItem(
            value: () => _confirmForget(context, notifier),
            child: const Text('Forget this router'),
          ),
      ],
    );
  }

  Future<void> _confirmForget(
    BuildContext context,
    SessionNotifier notifier,
  ) async {
    final forget = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this router?'),
        content: const Text(
          'Watchtower deletes the saved address, password and certificate '
          'fingerprint from this phone. The "watchtower" user stays on the '
          'router.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (forget ?? false) await notifier.forget();
  }
}
