import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session.dart';
import '../data/setup_commands.dart';
import 'router_menu.dart';
import 'widgets/command_list.dart';
import 'widgets/page_layout.dart';

/// Why the paired router can't be used right now, and what to do about it.
class ConnectionProblemScreen extends ConsumerWidget {
  const ConnectionProblemScreen({super.key, required this.problem});

  final ConnectionProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider.notifier);
    final permission = ref.read(localNetworkPermissionProvider);
    final config = problem.config;
    final retry = FilledButton(
      onPressed: session.retry,
      child: const Text('Try again'),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchtower'),
        actions: const [RouterMenuButton()],
      ),
      body: SafeArea(
        child: switch (problem) {
          Unreachable(permissionDenied: true) => PageLayout(
            icon: Icons.lan_outlined,
            title: 'Local network access is off',
            content: const [
              Text(
                'Watchtower needs permission to connect to devices on your '
                'local network, such as your router.',
              ),
            ],
            actions: [
              FilledButton(
                onPressed: permission.openSettings,
                child: const Text('Open Settings'),
              ),
              OutlinedButton(
                onPressed: session.retry,
                child: const Text('Try again'),
              ),
            ],
          ),
          Unreachable(:final reason) => PageLayout(
            icon: Icons.wifi_off_outlined,
            title: "Can't reach your router",
            content: [
              Text(
                'Watchtower connects to ${config.host} on port '
                '${config.port}. Check that this phone is on your home '
                'Wi-Fi.',
              ),
              if (defaultTargetPlatform == TargetPlatform.iOS)
                const Hint(
                  'If you turned off local network access for Watchtower, '
                  'turn it back on in Settings.',
                ),
              if (reason != null) Hint(reason),
            ],
            actions: [
              retry,
              if (defaultTargetPlatform == TargetPlatform.iOS)
                OutlinedButton(
                  onPressed: permission.openSettings,
                  child: const Text('Open Settings'),
                ),
              TextButton(
                onPressed: session.startDemo,
                child: const Text('Try the demo'),
              ),
            ],
          ),
          LoginFailed(:final reason) => PageLayout(
            icon: Icons.lock_outline,
            title: 'The router rejected the sign-in',
            content: [
              Text(
                'The "${config.user}" user or its password no longer works. '
                'If you changed or removed the user on the router, set up '
                'Watchtower again.',
              ),
              Hint(reason),
            ],
            actions: [
              retry,
              OutlinedButton(
                onPressed: session.forget,
                child: const Text('Set up again'),
              ),
            ],
          ),
          CertificateChanged(:final fingerprint) => PageLayout(
            icon: Icons.gpp_maybe_outlined,
            title: "The router's certificate has changed",
            content: [
              const Text(
                'This happens when the certificate is recreated on the '
                'router. It could also mean another device is pretending to '
                'be your router. Watchtower did not send your password.',
              ),
              const Hint(
                'If you recreated the certificate, check that the router '
                'shows this fingerprint:',
              ),
              FingerprintView(fingerprint),
              const CommandList([certificateCheckCommand]),
            ],
            actions: [
              FilledButton(
                onPressed: () => session.trustCertificate(fingerprint),
                child: const Text('Trust the new certificate'),
              ),
              OutlinedButton(
                onPressed: session.retry,
                child: const Text('Try again'),
              ),
            ],
          ),
        },
      ),
    );
  }
}
