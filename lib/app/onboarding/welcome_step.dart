import 'package:flutter/material.dart';

import '../widgets/page_layout.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onConnect, required this.onDemo});

  final VoidCallback onConnect;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    return PageLayout(
      icon: Icons.router_outlined,
      title: 'Welcome to Watchtower',
      content: const [
        Text(
          "See what's happening on your MikroTik home router: internet "
          "usage, the devices on your Wi-Fi and the router's log.",
        ),
        Hint(
          'Watchtower only reads from your router. It never changes its '
          'settings.',
        ),
      ],
      actions: [
        FilledButton(
          onPressed: onConnect,
          child: const Text('Connect your router'),
        ),
        TextButton(onPressed: onDemo, child: const Text('Try the demo')),
      ],
    );
  }
}
