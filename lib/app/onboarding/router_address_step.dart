import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routeros/routeros.dart';

import '../../data/router_connector.dart';
import '../../data/session.dart';
import '../widgets/page_layout.dart';

/// Asks for the router's address and fetches its certificate. Nothing but
/// the TLS handshake is sent.
class RouterAddressStep extends ConsumerStatefulWidget {
  const RouterAddressStep({
    super.key,
    required this.initialHost,
    required this.onFound,
  });

  final String initialHost;
  final void Function(String host, CertificateInfo certificate) onFound;

  @override
  ConsumerState<RouterAddressStep> createState() => _RouterAddressStepState();
}

class _RouterAddressStepState extends ConsumerState<RouterAddressStep> {
  late final _host = TextEditingController(text: widget.initialHost);
  var _busy = false;
  var _permissionDenied = false;
  String? _error;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final host = _host.text.trim();
    if (host.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _permissionDenied = false;
    });
    final permission = ref.read(localNetworkPermissionProvider);
    final connector = ref.read(routerConnectorProvider);
    try {
      if (!await permission.request()) {
        setState(() {
          _permissionDenied = true;
          _error =
              'Watchtower needs permission to connect to devices on your '
              'local network, such as your router.';
        });
        return;
      }
      final certificate = await connector.fetchCertificate(host);
      widget.onFound(host, certificate);
    } on RouterOsException catch (e) {
      setState(() {
        _error =
            "Couldn't reach $host on port ${RouterOsConnection.defaultPort}. "
            "Check that this phone is on your home Wi-Fi and that the setup "
            'commands ran. If your phone asked to find devices on your local '
            'network, allow it and try again.\n\n${e.message}';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return PageLayout(
      title: 'Find your router',
      content: [
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _find(),
          decoration: const InputDecoration(
            labelText: 'Router address',
            border: OutlineInputBorder(),
          ),
        ),
        const Hint(
          "Your router's IP address on your home network. MikroTik routers "
          'use 192.168.88.1 unless it has been changed.',
        ),
        if (error != null)
          Hint(error, color: Theme.of(context).colorScheme.error),
      ],
      actions: [
        BusyButton(label: 'Next', busy: _busy, onPressed: _find),
        if (_permissionDenied)
          OutlinedButton(
            onPressed: ref.read(localNetworkPermissionProvider).openSettings,
            child: const Text('Open Settings'),
          ),
      ],
    );
  }
}
