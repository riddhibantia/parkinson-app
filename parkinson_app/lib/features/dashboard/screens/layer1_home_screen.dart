import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/services/demo_data_service.dart';
import '../../../core/providers/app_mode_provider.dart';

/// Layer1Home — dedicated page, not a conditional branch.
class Layer1HomeScreen extends ConsumerWidget {
  const Layer1HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(localSessionsProvider);
    final sessions = sessionsAsync.valueOrNull ?? [];
    final isDemo = ref.watch(appModeProvider).isDemo;
    final effectiveSessions = (isDemo && sessions.isEmpty) ? DemoDataService.demoSessions() : sessions;
    final count = effectiveSessions.where((s) => !s.isFamiliarization).length;
    return Scaffold(
      appBar: const AppTopBar(title: 'Hello', subtitle: 'Layer 1 · Quick Analysis'),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Layer 1 · Quick Analysis', style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Text('Compare a typing session with the research model.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ProgressCard(title: 'Session progress', progressText: '$count / 2', fraction: (count / 2).clamp(0, 1), caption: count >= 2 ? 'Analysis ready' : count == 1 ? 'Session 1 completed — Session 2 optional' : 'Start your first typing session'),
            const SizedBox(height: 12),
            PrimaryButton(label: count == 0 ? 'Start typing session' : 'Start next typing session', onPressed: () => context.go('/type/structured')),
            const SizedBox(height: 8),
            SecondaryButton(label: 'View Layer 1 insights', onPressed: () => context.go('/insights/layer1')),
            const SizedBox(height: 16),
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('What is Layer 1?', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              const Text('Layer 1 provides a quick research-oriented comparison using typing-pattern features.'),
            ])),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => context.go('/onboarding/layer-selection'), child: const Text('Explore Layer 2')),
            const SizedBox(height: 16),
            Text('Recent Layer 1 sessions', style: Theme.of(context).textTheme.titleSmall),
            for (final s in effectiveSessions.take(3))
              Card(child: ListTile(title: Text('Session ${effectiveSessions.indexOf(s) + 1} · ${s.mode}'), subtitle: Text('${s.startTime.toLocal().toString().substring(0, 16)} · ${s.totalKeystrokes} keys'))),
          ],
        ),
      ),
    );
  }
}
