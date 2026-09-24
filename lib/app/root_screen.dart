import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session.dart';
import 'connection_problem_screen.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_flow.dart';

/// Shows pairing, the dashboard or a connection problem, depending on the
/// session.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(sessionProvider)
        .when(
          data: (state) => switch (state) {
            NeedsSetup() => const OnboardingFlow(),
            Connected() => const HomeScreen(),
            Paused() => const _Connecting(),
            ConnectionProblem problem => ConnectionProblemScreen(
              problem: problem,
            ),
          },
          error: (error, _) => _UnexpectedError(error),
          loading: () => const _Connecting(),
        );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to your router…'),
          ],
        ),
      ),
    );
  }
}

class _UnexpectedError extends ConsumerWidget {
  const _UnexpectedError(this.error);

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Something went wrong.\n$error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(sessionProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
