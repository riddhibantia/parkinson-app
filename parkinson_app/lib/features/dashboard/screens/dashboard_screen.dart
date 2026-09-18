import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/session_repository.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../typing_test/providers/familiarization_provider.dart';

/// Dashboard home shell (Stage 7.1 structure, pre-analysis states).
/// Shows real local counts only — no screening statuses exist until the
/// backend analysis pipeline (Stage 6 + trained models) produces results,
/// so cards describe readiness instead of inventing outcomes.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fam = ref.watch(familiarizationProvider);
    final sessionsAsync = ref.watch(localSessionsProvider);
    final checkIns = ref.watch(checkInProvider);
    final sessions = sessionsAsync.valueOrNull ?? [];
    final screeningSessions =
        sessions.where((s) => !s.isFamiliarization).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_greeting()}!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text('$screeningSessions screening sessions stored on this device'),
          const SizedBox(height: 16),
          // Layer 1 card — readiness state only, never a result.
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('General comparison (Layer 1)'),
              subtitle: Text(
                fam.screeningReady
                    ? 'Practice complete — comparison activates with analysis.'
                    : 'Complete ${fam.requiredSessions} practice session(s) first. '
                        'Practice is never scored.',
              ),
            ),
          ),
          // Layer 2 card — building state only, never a result.
          Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up_outlined),
              title: const Text('Personal trend (Layer 2)'),
              subtitle: Text(
                'Building — needs 10+ sessions across at least 5 days '
                'on your usual keyboard '
                '($screeningSessions/${AppConstants.minimumSessionsForBaseline}+).',
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Quick stats row — real counts.
          Row(
            children: [
              _StatChip(
                label: 'Sessions',
                value: '$screeningSessions',
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Practice',
                value:
                    '${fam.completedPracticeSessions}/${fam.requiredSessions}',
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Check-ins',
                value: '${checkIns.length}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Next action card — contextual prompt.
          Card(
            child: ListTile(
              leading: const Icon(Icons.arrow_forward_outlined),
              title: Text(
                !fam.screeningReady
                    ? 'Finish practice to begin screening'
                    : 'Type today to keep your profile up to date',
              ),
              subtitle: const Text(
                'Baseline needs sessions across multiple days, not all at once.',
              ),
              onTap: () => context.go('/type'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Daily check-in'),
              subtitle: Text(
                checkIns.isEmpty
                    ? 'Takes about 20–30 seconds.'
                    : 'Last check-in recorded.',
              ),
              onTap: () => context.go('/checkin'),
            ),
          ),
          const SizedBox(height: 8),
          // Session history preview — last 3 real sessions.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent sessions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              TextButton(
                onPressed: () => context.go('/insights/history'),
                child: const Text('See all'),
              ),
            ],
          ),
          if (sessions.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No sessions yet'),
                subtitle: Text('Your completed sessions will appear here.'),
              ),
            )
          else
            for (final s in sessions.take(3))
              Card(
                child: ListTile(
                  title: Text(
                    '${s.mode} · ${s.isFamiliarization ? 'Practice' : 'Screening'}',
                  ),
                  subtitle: Text(
                    '${s.startTime.toLocal().toString().substring(0, 16)} · '
                    '${s.totalKeystrokes} keys',
                  ),
                ),
              ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'This is not a medical diagnosis. Results are for '
              'informational purposes only.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(value,
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
