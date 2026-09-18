import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/feature_card.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How it works')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const FeatureCard(
              icon: Icons.keyboard_outlined,
              title: 'Type naturally',
              description: 'Complete short typing sessions on your own keyboard.',
            ),
            const SizedBox(height: 12),
            const FeatureCard(
              icon: Icons.timeline_outlined,
              title: 'We study timing',
              description:
                  'Only key-press timing is analyzed — never the words you type.',
            ),
            const SizedBox(height: 12),
            const FeatureCard(
              icon: Icons.insights_outlined,
              title: 'Get insights over time',
              description:
                  'Your personal trend is tracked across sessions once your baseline is ready.',
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/onboarding/consent'),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
