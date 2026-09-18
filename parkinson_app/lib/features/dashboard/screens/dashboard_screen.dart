import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/analysis_mode_provider.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/services/demo_data_service.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../reminders/providers/reminder_prefs_provider.dart';
import '../../typing_test/providers/familiarization_provider.dart';
import '../providers/streak_provider.dart';
import '../widgets/baseline_progress.dart';
import '../widgets/layer_result_card.dart';
import '../widgets/recommendation_banner.dart';

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
    final loading = sessionsAsync.isLoading;
    final isDemo = ref.watch(appModeProvider).isDemo;
    final effectiveSessions = (isDemo && sessions.isEmpty) ? DemoDataService.demoSessions() : sessions;
    final effectiveScreeningCount = effectiveSessions.where((s) => !s.isFamiliarization).length;
    final effectiveResult = (isDemo && resultAsync.valueOrNull == null)
        ? {
            'layer1': DemoDataService.demoLayer1Result(),
            'layer2': DemoDataService.demoLayer2Result(),
            'primary_focus': 'layer1',
            'shap_status': 'completed',
            '_demo': true,
          }
        : resultAsync.valueOrNull;
    final effectiveCards = resultCardsFor(effectiveResult);
    final displayCards = effectiveCards ?? cards;
    final streak = ref.watch(streakProvider);
    final effectiveStreak = isDemo
        ? computeStreak(
            effectiveSessions
                .where((s) => !s.isFamiliarization)
                .map((s) => s.startTime.toLocal())
                .toList(),
            DateTime.now())
        : streak;
    final reminderHint = ref
        .watch(reminderPrefsProvider.notifier)
        .nextHint(
          now: DateTime.now(),
          typedToday: effectiveSessions.any(
            (s) =>
                !s.isFamiliarization &&
                _isSameDay(s.startTime.toLocal(), DateTime.now()),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${_greeting()}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (ref.watch(analysisModeProvider) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ref.watch(analysisModeProvider) == AnalysisMode.layer1
                        ? 'LAYER 1 · Quick Analysis'
                        : 'LAYER 2 · Personal Monitoring',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ),
            Text('Here\'s what you can do today.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            // Primary CTA per mode
            if (ref.watch(analysisModeProvider) == AnalysisMode.layer1) ...[
              PrimaryButton(
                label: effectiveScreeningCount >= 2 ? 'View results' : 'Start typing session',
                icon: Icons.keyboard_outlined,
                onPressed: () => context.go(effectiveScreeningCount >= 2 ? '/insights/layer1' : '/type/structured'),
              ),
              const SizedBox(height: 12),
              ProgressCard(
                title: 'Quick Analysis',
                progressText: '$effectiveScreeningCount / 2 sessions',
                fraction: (effectiveScreeningCount / 2).clamp(0, 1),
                caption: effectiveScreeningCount >= 2
                    ? 'Analysis ready — view your population comparison.'
                    : effectiveScreeningCount == 1
                        ? '1 of 2 sessions complete.'
                        : 'Complete 1–2 sessions to see your research comparison.',
              ),
            ] else if (ref.watch(analysisModeProvider) == AnalysisMode.layer2) ...[
              PrimaryButton(
                label: effectiveScreeningCount >= AppConstants.minimumSessionsForBaseline
                    ? 'Start today\'s session'
                    : 'Continue monitoring',
                icon: Icons.keyboard_outlined,
                onPressed: () => context.go('/type/structured'),
              ),
              const SizedBox(height: 8),
              SecondaryButton(label: "Today's check-in", onPressed: () => context.go('/checkin')),
              const SizedBox(height: 12),
              BaselineProgress(screeningSessions: effectiveScreeningCount),
              ProgressCard(
                title: 'Days collected',
                progressText: '${(effectiveScreeningCount / 2).ceil().clamp(0, 5)} / 5 days',
                fraction: ((effectiveScreeningCount / 2).ceil() / 5).clamp(0, 1),
                caption: effectiveScreeningCount >= AppConstants.minimumSessionsForBaseline
                    ? 'Personal monitoring active'
                    : 'Building your personal baseline',
              ),
            ] else ...[
              Text(
                  isDemo
                      ? '$effectiveScreeningCount screening sessions — Sample / Demo Data'
                      : '$screeningSessions screening sessions stored on this device'),
              BaselineProgress(screeningSessions: effectiveScreeningCount),
            ],
            if (latestMilestoneHit(effectiveScreeningCount) != null)
              GlassCard(
                tint: AppColors.statusNormal,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.celebration_outlined),
                  title: Text(
                    'Milestone: ${latestMilestoneHit(effectiveScreeningCount)} sessions — nice consistency!',
                  ),
                  subtitle: Text(
                    nextMilestone(effectiveScreeningCount) == null
                        ? 'You are at the top tier. Keep your rhythm steady.'
                        : '$effectiveScreeningCount/${nextMilestone(effectiveScreeningCount)} to the next milestone.',
                  ),
                ),
              ),
            GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  effectiveStreak > 0
                      ? Icons.local_fire_department_outlined
                      : Icons.snooze_outlined,
                  color: effectiveStreak > 0 ? AppColors.statusAttention : null,
                ),
                title: Text(effectiveStreak > 0 ? '$effectiveStreak-day streak' : 'No streak yet'),
                subtitle: Text(reminderHint),
                onTap: () => context.go('/profile/settings'),
              ),
            ),
            const SizedBox(height: 16),
          if (loading) ...[
            const CardShimmer(),
          ] else if (displayCards == null) ...[
            if (ref.watch(analysisModeProvider) == AnalysisMode.layer1) ...[
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Population comparison'),
                  subtitle: Text(
                    effectiveScreeningCount == 0
                        ? 'Complete 1–2 typing sessions to see your research comparison.'
                        : 'Session ${effectiveScreeningCount + 1} of 2 — start next session',
                  ),
                ),
              ),
            ] else if (ref.watch(analysisModeProvider) == AnalysisMode.layer2) ...[
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timeline_outlined),
                  title: const Text('Personal monitoring'),
                  subtitle: Text(
                    'Building — needs 10+ sessions across at least 5 days '
                    '($effectiveScreeningCount/${AppConstants.minimumSessionsForBaseline}+).',
                  ),
                ),
              ),
            ] else ...[
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('General comparison (Layer 1)'),
                  subtitle: const Text('Complete 1–2 typing sessions to see your research comparison.'),
                ),
              ),
              GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.trending_up_outlined),
                  title: const Text('Personal trend (Layer 2)'),
                  subtitle: Text(
                    'Building — needs 10+ sessions across at least 5 days '
                    '($effectiveScreeningCount/${AppConstants.minimumSessionsForBaseline}+).',
                  ),
                ),
              ),
            ],
          ] else ...[
            if (isDemo)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Sample / Demo Data — not medical findings',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.statusWatch, fontWeight: FontWeight.w600)),
              ),
            // Mode-aware layer cards: show only relevant layer per chosen mode
            if (ref.watch(analysisModeProvider) == AnalysisMode.layer1) ...[
              LayerResultCard(
                title: 'Population comparison',
                status: displayCards.layer1.status,
                message: displayCards.layer1.message,
                emphasized: true,
              ),
              RecommendationBanner(status: displayCards.layer1.status),
              _ShapContributors(result: effectiveResult),
            ] else if (ref.watch(analysisModeProvider) == AnalysisMode.layer2) ...[
              LayerResultCard(
                title: 'Personal change monitoring',
                status: displayCards.layer2.status,
                message: displayCards.layer2.building
                    ? 'Your personal baseline is being built from repeated sessions.'
                    : displayCards.layer2.message,
                building: displayCards.layer2.building,
                emphasized: true,
              ),
              RecommendationBanner(status: displayCards.layer2.status),
            ] else ...[
              LayerResultCard(
                title: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer2.title
                    : displayCards.layer1.title,
                status: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer2.status
                    : displayCards.layer1.status,
                message: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer2.message
                    : displayCards.layer1.message,
                building: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer2.building
                    : displayCards.layer1.building,
                emphasized: true,
              ),
              LayerResultCard(
                title: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer1.title
                    : displayCards.layer2.title,
                status: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer1.status
                    : displayCards.layer2.status,
                message: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer1.message
                    : displayCards.layer2.message,
              ),
              RecommendationBanner(
                status: displayCards.primaryFocus == 'layer2'
                    ? displayCards.layer2.status
                    : displayCards.layer1.status,
              ),
              if (displayCards.layer1.status != 'normal' || displayCards.layer2.status != 'normal')
                _ShapContributors(result: effectiveResult),
            ],
          ],
          if (ref.watch(analysisModeProvider) == null &&
              displayCards != null &&
              (displayCards.layer1.status != 'normal' ||
                  displayCards.layer2.status != 'normal'))
            _ShapContributors(result: effectiveResult),
          const SizedBox(height: 8),
          if (ref.watch(analysisModeProvider) == AnalysisMode.layer1) ...[
            Row(
              children: [
                _StatChip(label: 'Sessions', value: '$effectiveScreeningCount / 2'),
                const SizedBox(width: 8),
                _StatChip(label: 'Latest', value: displayCards?.layer1.status ?? '—'),
                const SizedBox(width: 8),
                _StatChip(label: 'Check-ins', value: '${checkIns.length}'),
              ],
            ),
          ] else if (ref.watch(analysisModeProvider) == AnalysisMode.layer2) ...[
            Row(
              children: [
                _StatChip(label: 'Sessions', value: '$effectiveScreeningCount / 10'),
                const SizedBox(width: 8),
                _StatChip(label: 'Days', value: '${(effectiveScreeningCount / 2).ceil().clamp(0, 5)} / 5'),
                const SizedBox(width: 8),
                _StatChip(label: 'Check-ins', value: '${checkIns.length}'),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _StatChip(label: 'Sessions', value: '$effectiveScreeningCount'),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Practice',
                  value: '${fam.completedPracticeSessions}/${fam.requiredSessions}',
                ),
                const SizedBox(width: 8),
                _StatChip(label: 'Check-ins', value: '${checkIns.length}'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (ref.watch(analysisModeProvider) == AnalysisMode.layer1)
            GlassCard(
              child: ListTile(
                leading: const Icon(Icons.arrow_forward_outlined),
                title: Text(effectiveScreeningCount == 0 ? 'Start typing session' : 'View Layer 1 insights'),
                subtitle: const Text('1–2 sessions for population comparison.'),
                onTap: () => context.go(effectiveScreeningCount == 0 ? '/type/structured' : '/insights/layer1'),
              ),
            )
          else
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
          if (ref.watch(analysisModeProvider) == AnalysisMode.layer1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: () => context.go('/onboarding/layer-selection'),
                child: const Text('Explore Layer 2 — Personal Monitoring'),
              ),
            ),
          if (ref.watch(analysisModeProvider) == AnalysisMode.layer2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: () => context.go('/onboarding/layer-selection'),
                child: const Text('Explore Layer 1 — Quick Analysis'),
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
          if (loading)
            const LoadingShimmer(height: 64)
          else if (effectiveSessions.isEmpty)
            EmptyState(
              icon: Icons.history_outlined,
              title: isDemo ? 'Sample sessions' : 'No sessions yet',
              subtitle: isDemo
                  ? 'Demo history — 8 sessions across 6 days (Sample Data).'
                  : 'Your completed sessions will appear here.',
              actionLabel: 'Start typing',
              onAction: () => context.go('/type'),
            )
          else
            for (final s in effectiveSessions.take(3))
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
