import 'package:flutter/material.dart';

/// A scrolling page with an icon, a title, content and full-width actions,
/// used for onboarding and connection problems.
class PageLayout extends StatelessWidget {
  const PageLayout({
    super.key,
    this.icon,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  final IconData? icon;
  final String title;
  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = this.icon;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        if (icon != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(icon, size: 40, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
        ],
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        for (final child in content)
          Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
        const SizedBox(height: 8),
        for (final action in actions)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: action),
      ],
    );
  }
}

/// Secondary explanatory text.
class Hint extends StatelessWidget {
  const Hint(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A button that shows a spinner while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
