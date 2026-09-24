import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/paired_router.dart';
import '../../data/router_connector.dart';
import '../../data/session.dart';
import '../../data/setup_commands.dart';
import 'certificate_step.dart';
import 'prepare_router_step.dart';
import 'router_address_step.dart';
import 'welcome_step.dart';

enum _Step { welcome, prepare, address, certificate }

/// Pairs the app with a router. When pairing succeeds the session becomes
/// connected and the root screen replaces this flow.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _generatedPassword = generatePassword();
  var _step = _Step.welcome;
  var _password = '';
  var _host = PairedRouter.defaultHost;
  CertificateInfo? _certificate;

  void _go(_Step step) => setState(() => _step = step);

  void _back() => _go(_Step.values[_step.index - 1]);

  @override
  Widget build(BuildContext context) {
    final certificate = _certificate;
    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: _step == _Step.welcome
            ? null
            : AppBar(
                leading: BackButton(onPressed: _back),
                title: Text(
                  'Step ${_step.index} of ${_Step.values.length - 1}',
                ),
              ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                _Step.welcome => WelcomeStep(
                  onConnect: () => _go(_Step.prepare),
                  onDemo: ref.read(sessionProvider.notifier).startDemo,
                ),
                _Step.prepare => PrepareRouterStep(
                  generatedPassword: _generatedPassword,
                  onNext: (password) {
                    _password = password;
                    _go(_Step.address);
                  },
                ),
                _Step.address => RouterAddressStep(
                  initialHost: _host,
                  onFound: (host, certificate) {
                    _host = host;
                    _certificate = certificate;
                    _go(_Step.certificate);
                  },
                ),
                _Step.certificate => CertificateStep(
                  host: _host,
                  certificate: certificate!,
                  password: _password,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
