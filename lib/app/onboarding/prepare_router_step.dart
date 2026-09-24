import 'package:flutter/material.dart';

import '../../data/setup_commands.dart';
import '../widgets/command_list.dart';
import '../widgets/page_layout.dart';

/// Shows the commands that create the certificate and the read-only user,
/// or takes the password of a user created earlier.
class PrepareRouterStep extends StatefulWidget {
  const PrepareRouterStep({
    super.key,
    required this.generatedPassword,
    required this.onNext,
  });

  final String generatedPassword;

  /// Called with the password the router's user has.
  final ValueChanged<String> onNext;

  @override
  State<PrepareRouterStep> createState() => _PrepareRouterStepState();
}

class _PrepareRouterStepState extends State<PrepareRouterStep> {
  final _password = TextEditingController();
  var _existing = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _existing ? _existingUser(context) : _commands(context);
  }

  Widget _commands(BuildContext context) {
    final password = widget.generatedPassword;
    return PageLayout(
      title: 'Prepare your router',
      content: [
        const Text(
          'Watchtower signs in as its own read-only user over an encrypted '
          "connection. Run these commands once in your router's terminal "
          '(WinBox or WebFig → Terminal, or SSH).',
        ),
        const Hint(
          'Paste them one line at a time: signing a certificate takes a few '
          'seconds.',
        ),
        CommandList(
          setupCommands(password),
          shareSubject: 'Watchtower router setup',
        ),
        const Hint(
          'They add a certificate for the encrypted connection and a user '
          'named "watchtower" that can only read. Nothing else on the router '
          'changes. If a line says something already exists, that part is '
          'already done.',
        ),
        const Hint(
          'Already have a "watchtower" user from an earlier setup? Run this '
          'instead of the last line:',
        ),
        CommandList([resetPasswordCommand(password)]),
      ],
      actions: [
        FilledButton(
          onPressed: () => widget.onNext(password),
          child: const Text("I've run the commands"),
        ),
        TextButton(
          onPressed: () => setState(() => _existing = true),
          child: const Text('I know the password of an existing user'),
        ),
      ],
    );
  }

  Widget _existingUser(BuildContext context) {
    return PageLayout(
      title: 'Enter the password',
      content: [
        const Text(
          'Enter the password of the "watchtower" user on your router.',
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
      actions: [
        FilledButton(
          onPressed: _password.text.isEmpty
              ? null
              : () => widget.onNext(_password.text),
          child: const Text('Next'),
        ),
        TextButton(
          onPressed: () => setState(() => _existing = false),
          child: const Text('Show the setup commands'),
        ),
      ],
    );
  }
}
