import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/typing_session.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../providers/familiarization_provider.dart';
import '../../dashboard/screens/dashboard_screen.dart'
    show latestResultProvider;
import '../../dashboard/widgets/layer_result_card.dart';

/// Immediate post-typing report (Stage 2 flow close the loop).
/// Shows local session summary + live Layer1/Layer2 cards from latest result.
/// Never invents a status — honest collecting/building copy when no result.
class SessionCompleteScreen extends ConsumerWidget {
  final TypingSession session;
  const SessionCompleteScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fam = ref.watch(familiarizationProvider);
    final result = ref.watch(latestResultProvider).valueOrNull;
    final layer1 = result?['layer1'];
    final layer2 = result?['layer2'];
    final shapStatus = '${result?['shap_status'] ?? ''}';
    final isPractice = session.isFamiliarization;

    return Scaffold(
      appBar: AppBar(title: const Text('Session complete')),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPractice ? 'Practice saved' : 'Session saved',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.totalKeystrokes} keys · ${session.endTime.difference(session.startTime).inSeconds}s · ${session.deviceId}',
                  ),
                  if (isPractice)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Practice is never scored. '
                        '${fam.completedPracticeSessions}/${fam.requiredSessions} practice done.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            if (isPractice) ...[
              GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Not scored — keep practicing'),
                  subtitle: Text(
                    fam.screeningReady
                        ? 'Screening is now unlocked — type for insights.'
                        : 'Complete practice to unlock screening.',
                  ),
                ),
              ),
            ] else if (result == null) ...[
              const GlassCard(
                child: ListTile(
                  leading: Icon(Icons.hourglass_empty_outlined),
                  title: Text('Analyzing…'),
                  subtitle: Text(
                    'Your report will appear on Home once analysis completes.',
                  ),
                ),
              ),
            ] else ...[
              if (layer1 is Map)
                LayerResultCard(
                  title: 'General comparison (Layer 1)',
                  status: '${layer1['status']}',
                  message: '${layer1['message']}',
                  emphasized: result['primary_focus'] == 'layer1',
                ),
              if (layer2 is Map)
                LayerResultCard(
                  title: 'Personal trend (Layer 2)',
                  status: '${layer2['status']}',
                  message: layer2['confidence'] == 'building'
                      ? 'Still learning your pattern — check back as more sessions come in.'
                      : '${layer2['message']}',
                  building: layer2['confidence'] == 'building',
                  emphasized: result['primary_focus'] == 'layer2',
                ),
              if (shapStatus == 'pending')
                const GlassCard(
                  child: ListTile(
                    leading: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Building explanation…'),
                  ),
                ),
              if (layer1 is Map && layer1['top_contributors'] is List)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What stood out',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      for (final c in (layer1['top_contributors'] as List).take(
                        3,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '• ${c is Map ? (c['text'] ?? c['feature']) : '$c'}',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/insights'),
                    child: const Text('View insights'),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go('/type'),
              child: const Text('Type again'),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This is not a medical diagnosis. For information only.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
