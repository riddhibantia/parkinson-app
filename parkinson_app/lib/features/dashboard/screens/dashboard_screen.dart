import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/session_repository.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../reminders/providers/reminder_prefs_provider.dart';
import '../../typing_test/providers/familiarization_provider.dart';
import '../providers/streak_provider.dart';

/// View-model for one result card. Pure mapping from a stored result
/// document — unit-tested, no widgets involved.
class LayerCardData {
  final String title;
  final String status;
  final String message;
  final bool building;

  const LayerCardData({
    required this.title,
    required this.status,
    required this.message,
    this.building = false,
  });

  Color get color {
    switch (status) {
      case 'attention':
        return AppColors.statusAttention;
      case 'watch':
      case 'device_mismatch':
        return AppColors.statusWatch;
      default:
        return AppColors.statusNormal;
    }
  }
}

class DualCards {
  final LayerCardData layer1;
  final LayerCardData layer2;
  final String primaryFocus;

  const DualCards({
    required this.layer1,
    required this.layer2,
    required this.primaryFocus,
  });
}

/// Map a stored result document to cards. Returns null when there is no
/// result yet (caller shows readiness shells). Never invents a status:
/// unknown shapes fall back to readiness text.
DualCards? resultCardsFor(Map<String, dynamic>? result) {
  if (result == null) return null;
  final layer1raw = result['layer1'];
  final layer2raw = result['layer2'];
  if (layer1raw is Map && layer2raw is Map) {
    final layer1 = Map<String, dynamic>.from(layer1raw);
    final layer2 = Map<String, dynamic>.from(layer2raw);
    final building = layer2['confidence'] == 'building';
    return DualCards(
      layer1: LayerCardData(
        title: 'General comparison (Layer 1)',
        status: '${layer1['status']}',
        message: '${layer1['message']}',
      ),
      layer2: LayerCardData(
        title: 'Personal trend (Layer 2)',
        status: '${layer2['status']}',
        message: building
            ? 'Still learning your pattern — check back as more sessions '
                  'come in.'
            : '${layer2['message']}',
        building: building,
      ),
      primaryFocus: '${result['primary_focus'] ?? 'layer1'}',
    );
  }
  if (layer1raw is Map) {
    final layer1 = Map<String, dynamic>.from(layer1raw);
    return DualCards(
      layer1: LayerCardData(
        title: 'General comparison (Layer 1)',
        status: '${layer1['status']}',
        message: '${layer1['message']}',
      ),
      layer2: const LayerCardData(
        title: 'Personal trend (Layer 2)',
        status: 'normal',
        message: 'Your personal baseline is still building.',
        building: true,
      ),
      primaryFocus: 'layer1',
    );
  }
  return null;
}

final latestResultProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.watch(sessionRepositoryProvider).watchLatestResult();
});

/// Dashboard home (Stage 7.1): live dual cards when a stored result
/// exists, readiness shells otherwise. Counts are always real.
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
    final resultAsync = ref.watch(latestResultProvider);
    final sessions = sessionsAsync.valueOrNull ?? [];
    final screeningSessions = sessions
        .where((s) => !s.isFamiliarization)
        .length;
    final cards = resultCardsFor(resultAsync.valueOrNull);
    final streak = ref.watch(streakProvider);
    final reminderHint = ref
        .watch(reminderPrefsProvider.notifier)
        .nextHint(
          now: DateTime.now(),
          typedToday: sessions.any(
            (s) =>
                !s.isFamiliarization &&
                _isSameDay(s.startTime.toLocal(), DateTime.now()),
          ),
        );
    final milestone = latestMilestoneHit(screeningSessions);
    final next = nextMilestone(screeningSessions);

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
          if (milestone != null)
            Card(
              color: AppColors.statusNormal.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.celebration_outlined),
                title: Text(
                  'Milestone: $milestone sessions — nice consistency!',
                ),
                subtitle: Text(
                  next == null
                      ? 'You are at the top tier. Keep your rhythm steady.'
                      : '$screeningSessions/$next to the next milestone.',
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: Icon(
                streak > 0
                    ? Icons.local_fire_department_outlined
                    : Icons.snooze_outlined,
                color: streak > 0 ? AppColors.statusAttention : null,
              ),
              title: Text(streak > 0 ? '$streak-day streak' : 'No streak yet'),
              subtitle: Text(reminderHint),
              onTap: () => context.go('/profile/settings'),
            ),
          ),
          const SizedBox(height: 16),
          if (cards == null) ...[
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
          ] else ...[
            if (cards.primaryFocus == 'layer2') ...[
              _ResultCard(data: cards.layer2, big: true),
              _ResultCard(data: cards.layer1, big: false),
            ] else ...[
              _ResultCard(data: cards.layer1, big: true),
              _ResultCard(data: cards.layer2, big: false),
            ],
          ],
          if (cards != null &&
              (cards.layer1.status != 'normal' ||
                  cards.layer2.status != 'normal'))
            _ShapContributors(result: resultAsync.valueOrNull),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatChip(label: 'Sessions', value: '$screeningSessions'),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Practice',
                value:
                    '${fam.completedPracticeSessions}/${fam.requiredSessions}',
              ),
              const SizedBox(width: 8),
              _StatChip(label: 'Check-ins', value: '${checkIns.length}'),
            ],
          ),
          const SizedBox(height: 16),
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

class _ResultCard extends StatelessWidget {
  final LayerCardData data;
  final bool big;
  const _ResultCard({required this.data, required this.big});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          data.building ? Icons.hourglass_empty_outlined : Icons.circle,
          color: data.color,
          size: big ? 32 : 24,
        ),
        title: Text(
          data.title,
          style: big ? Theme.of(context).textTheme.headlineSmall : null,
        ),
        subtitle: Text(data.message),
        isThreeLine: true,
      ),
    );
  }
}

class _ShapContributors extends StatelessWidget {
  final Map<String, dynamic>? result;
  const _ShapContributors({required this.result});
  @override
  Widget build(BuildContext context) {
    final l1 = result?['layer1'];
    final shapStatus = '${result?['shap_status'] ?? ''}';
    final contributors = l1 is Map ? l1['top_contributors'] : null;
    if (contributors is List && contributors.isNotEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What stood out',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final c in contributors.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${c is Map ? (c['text'] ?? c['feature']) : '$c'}',
                  ),
                ),
              Text(
                'For context only — not a diagnosis.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    if (shapStatus == 'pending') {
      return const Card(
        child: ListTile(
          leading: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Building explanation…'),
          subtitle: Text('Your pattern is ready; details will appear shortly.'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
