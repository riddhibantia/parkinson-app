import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/analysis_mode_provider.dart';
import '../../../core/layout/top_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';

/// Layer selection after onboarding context — two large options.
class LayerSelectionScreen extends ConsumerWidget {
  const LayerSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AppTopBar(title: 'How would you like to use the app?', subtitle: 'Choose the experience that matches what you want to do.'),
      body: GradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _LayerCard(mode: AnalysisMode.layer1, ref: ref)),
                        const SizedBox(width: 16),
                        Expanded(child: _LayerCard(mode: AnalysisMode.layer2, ref: ref)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/about'),
                    child: const Text('Learn about both →'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final AnalysisMode mode;
  final WidgetRef ref;
  const _LayerCard({required this.mode, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isLayer1 = mode == AnalysisMode.layer1;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(mode.badge, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
          ),
          const SizedBox(height: 12),
          Text(isLayer1 ? 'QUICK ANALYSIS' : 'PERSONAL MONITORING',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(mode == AnalysisMode.layer1 ? 'Layer 1' : 'Layer 2',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
              isLayer1
                  ? 'Try 1–2 typing sessions'
                  : 'Track changes over time',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
              isLayer1
                  ? 'Compare your current typing pattern with the population-level research model.'
                  : 'Build your personal typing baseline and monitor how your patterns change over time.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final bullet in (isLayer1
              ? [
                  'Takes only a few typing sessions',
                  'No long-term baseline required',
                  'Shows a research-based population comparison',
                  'Useful for exploring the application',
                ]
              : [
                  'Requires repeated sessions',
                  'Builds your own personal baseline',
                  'Tracks typing-pattern changes over time',
                  'Shows trends and monitoring signals',
                ]))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(child: Text(bullet, style: Theme.of(context).textTheme.bodySmall)),
              ]),
            ),
          const Spacer(),
          PrimaryButton(
            label: isLayer1 ? 'Choose Quick Analysis' : 'Choose Personal Monitoring',
            onPressed: () async {
              await ref.read(analysisModeProvider.notifier).setMode(mode);
              ref.read(hasOnboardedProvider.notifier).state = true;
              if (context.mounted) context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}
