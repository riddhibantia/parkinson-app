import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';
import '../screens/dashboard_screen.dart' show latestResultProvider;

class Layer1ResultScreen extends ConsumerWidget {
  const Layer1ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(latestResultProvider).valueOrNull;
    final layer1 = result?['layer1'];
    final shapStatus = '${result?['shap_status'] ?? ''}';
    final isDemo = result?['_demo'] == true;

    return Scaffold(
      appBar: const AppTopBar(title: 'Your typing-pattern comparison', subtitle: 'Layer 1 · Quick Analysis — Population comparison'),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (layer1 == null)
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Not enough data yet'),
                  const SizedBox(height: 8),
                  const Text('Complete 1–2 typing sessions to see your research comparison.'),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Start typing session', onPressed: () => context.go('/type/structured')),
                ]),
              )
            else ...[
              if (isDemo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Sample / Demo Data', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                ),
              StatusBadge(status: '${layer1['status']}'),
              const SizedBox(height: 12),
              Text('Your typing features were compared with patterns learned from research datasets.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${layer1['message']}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                    child: const Text('This is a research screening signal and should not be interpreted as a medical diagnosis.',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
                ]),
              ),
              if (layer1['top_contributors'] is List && (layer1['top_contributors'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('What stood out', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    for (final c in (layer1['top_contributors'] as List).take(3))
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${c is Map ? (c['text'] ?? c['feature']) : '$c'}')),
                  ]),
                ),
              ] else if (shapStatus == 'pending')
                const GlassCard(child: ListTile(leading: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), title: Text('Building explanation…'))),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('How this works'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• Typing timing features: hold time, flight time, inter-key latency, consistency, hand asymmetry, pauses.'),
                      const SizedBox(height: 6),
                      const Text('• Population model trained on Tappy + neuroQWERTY research datasets.'),
                      const SizedBox(height: 6),
                      const Text('• Limitations: cross-subject accuracy is modest; this is research support, not diagnosis.'),
                    ]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: 'Back to Home', onPressed: () => context.go('/home')),
            const SizedBox(height: 8),
            SecondaryButton(label: 'Try another session', onPressed: () => context.go('/type/structured')),
          ],
        ),
      ),
    );
  }
}
