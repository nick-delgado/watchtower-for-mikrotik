import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';

TextStyle? monospace(TextStyle? style) => style?.copyWith(
  fontFamily: 'monospace',
  fontFamilyFallback: const ['Menlo', 'Courier New'],
);

/// RouterOS commands to paste one at a time. Each wraps onto as many lines
/// as it needs and has its own copy button. Several commands also get Copy
/// all and, with [shareSubject], Share, e.g. to send them to a laptop.
class CommandList extends StatelessWidget {
  const CommandList(this.commands, {super.key, this.shareSubject});

  final List<String> commands;
  final String? shareSubject;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numbered = commands.length > 1;
    final shareSubject = this.shareSubject;
    final all = commands.join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final (i, command) in commands.indexed) ...[
                if (i > 0)
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
                  child: Row(
                    children: [
                      if (numbered)
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}',
                            style: monospace(theme.textTheme.bodySmall)
                                ?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      Expanded(
                        child: SelectableText(
                          command,
                          style: monospace(theme.textTheme.bodySmall),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy',
                        onPressed: () => _copy(context, command),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (numbered)
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Copy all'),
                onPressed: () => _copy(context, all),
              ),
              if (shareSubject != null)
                TextButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    SharePlus.instance.share(
                      ShareParams(
                        text: all,
                        subject: shareSubject,
                        sharePositionOrigin: box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// A certificate fingerprint, laid out for comparing by eye.
class FingerprintView extends StatelessWidget {
  const FingerprintView(this.fingerprint, {super.key});

  final String fingerprint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          groupFingerprint(fingerprint),
          textAlign: TextAlign.center,
          style: monospace(theme.textTheme.titleMedium)
              ?.copyWith(letterSpacing: 1, height: 1.5),
        ),
      ),
    );
  }
}
