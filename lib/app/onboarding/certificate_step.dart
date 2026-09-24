import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routeros/routeros.dart';

import '../../data/paired_router.dart';
import '../../data/router_connector.dart';
import '../../data/session.dart';
import '../../data/setup_commands.dart';
import '../format.dart';
import '../widgets/command_list.dart';
import '../widgets/page_layout.dart';

/// Shows the router's certificate fingerprint for the user to compare, then
/// pins it and signs in.
class CertificateStep extends ConsumerStatefulWidget {
  const CertificateStep({
    super.key,
    required this.host,
    required this.certificate,
    required this.password,
  });

  final String host;
  final CertificateInfo certificate;
  final String password;

  @override
  ConsumerState<CertificateStep> createState() => _CertificateStepState();
}

class _CertificateStepState extends ConsumerState<CertificateStep> {
  var _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final config = PairedRouter(
      host: widget.host,
      password: widget.password,
      pin: widget.certificate.fingerprint,
    );
    try {
      await ref.read(sessionProvider.notifier).pair(config);
    } on AuthenticationException {
      _fail(
        'The router rejected the password for the "watchtower" user. Check '
        'that all the setup commands ran, or go back and enter the password '
        'you set before.',
      );
    } on CertificateMismatchException {
      _fail(
        "The router's certificate changed while connecting. Go back and "
        'try again.',
      );
    } on RouterOsException catch (e) {
      _fail("Couldn't connect to the router. ${e.message}");
    } on TimeoutException {
      _fail('The router did not answer in time.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _doesNotMatch() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Don't connect"),
      content: const Text(
        'A different fingerprint means Watchtower may not be talking to your '
        'router. Check the address and that this phone is on your own '
        'network. If the certificate was recreated on the router, its '
        'fingerprint changes too: go back and try again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final certificate = widget.certificate;
    final error = _error;
    return PageLayout(
      title: 'Check the certificate',
      content: [
        const Text(
          'To be sure Watchtower is talking to your router, compare this '
          'fingerprint with the one the router shows:',
        ),
        FingerprintView(certificate.fingerprint),
        Hint(
          'Issued to ${distinguishedName(certificate.subject)} by '
          '${distinguishedName(certificate.issuer)}. Run this on the router '
          'and look for "fingerprint":',
        ),
        const CommandList([certificateCheckCommand]),
        if (error != null)
          Hint(error, color: Theme.of(context).colorScheme.error),
      ],
      actions: [
        BusyButton(
          label: 'It matches: connect',
          busy: _busy,
          onPressed: _connect,
        ),
        TextButton(
          onPressed: _busy ? null : _doesNotMatch,
          child: const Text("It doesn't match"),
        ),
      ],
    );
  }
}
