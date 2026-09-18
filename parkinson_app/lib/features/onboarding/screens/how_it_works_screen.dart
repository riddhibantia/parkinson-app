import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../shared/widgets/gradient_background.dart';

/// Clean vertical list — replaces the three large horizontal bars.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'How it works'),
      body: GradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('This app learns from the way you type — not from what you type.',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  const _Bullet(icon: Icons.keyboard_outlined, text: 'Type naturally using your regular keyboard'),
                  const _Bullet(icon: Icons.timer_outlined, text: 'The app measures timing patterns such as hold time and flight time'),
                  const _Bullet(icon: Icons.layers_outlined, text: 'You can choose a quick Layer 1 analysis or long-term Layer 2 monitoring'),
                  const _Bullet(icon: Icons.insights_outlined, text: 'Layer 2 builds a personal baseline from repeated sessions'),
                  const _Bullet(icon: Icons.privacy_tip_outlined, text: 'Your typed content is not used as the analysis target'),
                  const _Bullet(icon: Icons.verified_outlined, text: 'Results are intended for research and monitoring, not diagnosis'),
                  const Spacer(),
                  PrimaryButton(label: 'Continue', onPressed: () => context.go('/onboarding/consent')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
