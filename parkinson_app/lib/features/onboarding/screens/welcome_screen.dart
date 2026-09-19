import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_mode_provider.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/parkin_trace_logo.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ParkinTraceLogo(size: 64),
                    const SizedBox(height: 16),
                    Text('ParkinTrace',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    Text("Typing patterns for Parkinson's monitoring",
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Text(
                      'Understand your typing patterns over time.',
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This app studies typing timing and movement patterns to support research-oriented monitoring. It does not diagnose Parkinson\'s disease.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Get Started',
                      icon: Icons.arrow_forward,
                      onPressed: () => context.go('/onboarding/how-it-works'),
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Continue as Guest — Demo',
                      onPressed: () async {
                        await ref.read(appModeProvider.notifier).enterDemo();
                        if (context.mounted) context.go('/onboarding/how-it-works');
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/onboarding/how-it-works'),
                      child: const Text('How it works →'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Demo includes sample data so Insights never looks empty. Clearly labeled “Sample / Demo Data”.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
