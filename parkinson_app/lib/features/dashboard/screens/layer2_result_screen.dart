import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../data/repositories/session_repository.dart';
import '../screens/dashboard_screen.dart' show latestResultProvider;
import '../screens/detailed_metrics_screen.dart' show baselineProvider;

class Layer2ResultScreen extends ConsumerWidget {
  const Layer2ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(latestResultProvider).valueOrNull;
    final layer2 = result?['layer2'];
    final baseline = ref.watch(baselineProvider).valueOrNull;
    final sessions = ref.watch(localSessionsProvider).valueOrNull ?? [];
    final screeningCount = sessions.where((s) => !s.isFamiliarization).length;
    final isBuilding = layer2?['confidence'] == 'building' || baseline == null;
    final status = '${layer2?['status'] ?? 'building'}';

    return Scaffold(
      appBar: const AppTopBar(title: 'Your personal typing patterns', subtitle: 'Layer 2 · Personal Monitoring'),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  StatusBadge(status: isBuilding ? 'building' : status),
                  const SizedBox(width: 8),
                  Text(isBuilding ? 'BUILDING' : 'ESTABLISHED', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text(isBuilding
                    ? 'Your personal baseline is being built from repeated sessions.'
                    : 'Your baseline is ready. New sessions are compared with your usual typing pattern.'),
                const SizedBox(height: 12),
                ProgressCard(title: 'Baseline progress', progressText: '$screeningCount / 10 sessions', fraction: (screeningCount / 10).clamp(0, 1), caption: isBuilding ? 'Need 10 sessions across 5 days' : 'Baseline established'),
              ]),
            ),
            const SizedBox(height: 16),
            if (isBuilding)
              const GlassCard(child: ListTile(leading: Icon(Icons.hourglass_empty_outlined), title: Text('Building your baseline'), subtitle: Text('Keep typing on the same keyboard across multiple days.')))
            else ...[
              Text('Current pattern', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              StatusBadge(status: status),
              const SizedBox(height: 8),
              GlassCard(
                child: Text(
                  status == 'attention'
                      ? 'Several features have shown a persistent change from your personal baseline.'
                      : status == 'watch'
                          ? 'Some typing features are different from your usual pattern. More sessions are needed before interpreting this as a sustained change.'
                          : 'Your recent typing pattern is within your usual personal range.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: const Text('This is a monitoring signal, not a medical diagnosis.',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: 'Back to Home', onPressed: () => context.go('/home')),
            const SizedBox(height: 8),
            SecondaryButton(label: 'View Insights', onPressed: () => context.go('/insights')),
          ],
        ),
      ),
    );
  }
}


