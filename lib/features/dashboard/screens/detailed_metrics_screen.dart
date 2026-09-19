import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/analysis_mode_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/layout/top_bar.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../typing_test/providers/last_result_provider.dart';
import '../widgets/metric_trend_chart.dart';
import 'dashboard_screen.dart' show latestResultProvider;

final baselineProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.watch(sessionRepositoryProvider).fetchBaseline();
});

/// Deep-dive metrics (Stage 7.3): per-feature personal-drift cards from
/// the latest Layer 2 result, with baseline context. Labels describe
/// statistical ranges (within usual range / unusual / strongly unusual),
/// never medical normal/abnormal.
class DetailedMetricsScreen extends ConsumerWidget {
  const DetailedMetricsScreen({super.key});

  static String rangeLabel(double robustZ) {
    final magnitude = robustZ.abs();
    if (magnitude >= 3) return 'strongly unusual';
    if (magnitude >= 2) return 'unusual';
    return 'within usual range';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(analysisModeProvider);
    // Layer 1: show immediate typing result in Insights tab (per user request)
    if (mode == AnalysisMode.layer1) {
      final result = ref.watch(latestResultProvider).valueOrNull;
      final local = ref.watch(lastLocalLayer1ResultProvider);
      final layer1 = result?['layer1'] ?? local;
      final features = ref.watch(lastLocalFeaturesProvider);
      if (layer1 == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Insights')),
          body: GradientBackground(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const EmptyState(
                icon: Icons.science_outlined,
                title: 'No Layer 1 analysis yet',
                subtitle: 'Complete a typing session to see your population comparison here. Insights shows the same result as the dedicated analysis page.',
              ),
              Card(child: ListTile(leading: const Icon(Icons.history_outlined), title: const Text('Session history'), onTap: () => context.go('/insights/history'))),
            ]),
          ),
        );
      }
      return Scaffold(
        appBar: const AppTopBar(title: 'Insights', subtitle: 'Layer 1 · Quick Analysis'),
        body: GradientBackground(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your typing-pattern comparison', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(layer1['message'] as String? ?? '', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('This is a research screening signal and not a medical diagnosis.', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  if (layer1['pd_probability'] is num) ...[
                    const SizedBox(height: 8),
                    Text('Model output: ${(layer1['pd_probability'] as num).toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
            if (features != null && features.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Session metrics', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text('Typing speed: ${(features['typing_speed'] ?? 0).toStringAsFixed(2)} keys/s', style: Theme.of(context).textTheme.bodySmall),
                    Text('Hold time: ${(features['ht_mean'] ?? 0).toStringAsFixed(0)} ms', style: Theme.of(context).textTheme.bodySmall),
                    Text('Flight time: ${(features['ft_mean'] ?? 0).toStringAsFixed(0)} ms', style: Theme.of(context).textTheme.bodySmall),
                    Text('Inter-key latency: ${(features['ikl_mean'] ?? 0).toStringAsFixed(0)} ms', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            Card(child: ListTile(leading: const Icon(Icons.history_outlined), title: const Text('Session history'), onTap: () => context.go('/insights/history'))),
            Card(child: ListTile(leading: const Icon(Icons.open_in_new), title: const Text('View dedicated Layer 1 insights'), onTap: () => context.go('/insights/layer1'))),
          ]),
        ),
      );
    }

    final resultAsync = ref.watch(latestResultProvider);
    final baselineAsync = ref.watch(baselineProvider);
    if (resultAsync.isLoading || baselineAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const GradientBackground(
          child: Padding(padding: EdgeInsets.all(16), child: CardShimmer()),
        ),
      );
    }
    final result = resultAsync.valueOrNull;
    final baseline = baselineAsync.valueOrNull;
    final layer2 = result?['layer2'];
    final signals = layer2 is Map
        ? Map<String, dynamic>.from(
            layer2['drift_result']?['drift_signals'] ?? {},
          )
        : <String, dynamic>{};
    final baselineFeatures = baseline?['features'] is Map
        ? Map<String, dynamic>.from(baseline!['features'] as Map)
        : <String, dynamic>{};
    // Local history for sparkline: last 10 screening sessions' per-feature values
    final sessions = ref.watch(localSessionsProvider).valueOrNull ?? [];
    final recent = sessions.where((s) => !s.isFamiliarization).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final tail = recent.length > 10
        ? recent.sublist(recent.length - 10)
        : recent;

    List<double> series(String name) {
      return [for (final s in tail) (s.events.isNotEmpty ? 0.0 : 0.0)];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (signals.isEmpty)
              const EmptyState(
                icon: Icons.insights_outlined,
                title: 'No analyzed sessions yet',
                subtitle:
                    'Per-feature trends appear once Layer 2 monitoring is active.',
              )
            else ...[
              for (final entry in signals.entries) ...[
                _MetricCard(
                  name: entry.key,
                  signal: Map<String, dynamic>.from(entry.value as Map),
                  baselineEntry: baselineFeatures[entry.key] is Map
                      ? Map<String, dynamic>.from(
                          baselineFeatures[entry.key] as Map,
                        )
                      : null,
                ),
                // Interactive sparkline placeholder — real per-session feature series
                // becomes meaningful once we persist per-session feature docs; until
                // then we show the robust-z + trend as the primary signal.
                MetricTrendChart(
                  featureLabel: entry.key,
                  values: series(entry.key),
                  baselineMedian:
                      (baselineFeatures[entry.key] as Map?)?['median'] is num
                      ? ((baselineFeatures[entry.key] as Map)['median'] as num)
                            .toDouble()
                      : null,
                ),
              ],
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Session history'),
                onTap: () => context.go('/insights/history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String name;
  final Map<String, dynamic> signal;
  final Map<String, dynamic>? baselineEntry;
  const _MetricCard({
    required this.name,
    required this.signal,
    required this.baselineEntry,
  });

  @override
  Widget build(BuildContext context) {
    final robustZ = (signal['robust_z_current'] as num?)?.toDouble() ?? 0.0;
    final trend = '${signal['trend'] ?? 'stable'}';
    final median = baselineEntry?['median'];
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          '${DetailedMetricsScreen.rangeLabel(robustZ)} · trend: $trend'
          '${median == null ? '' : ' · your usual: $median'}',
        ),
        trailing: Icon(
          Icons.circle,
          color: robustZ.abs() >= 3
              ? AppColors.statusAttention
              : robustZ.abs() >= 2
              ? AppColors.statusWatch
              : AppColors.statusNormal,
        ),
      ),
    );
  }
}
