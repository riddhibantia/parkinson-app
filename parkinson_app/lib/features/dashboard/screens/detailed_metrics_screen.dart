import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/session_repository.dart';
import 'dashboard_screen.dart' show latestResultProvider;

final baselineProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
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
    final result = ref.watch(latestResultProvider).valueOrNull;
    final baseline = ref.watch(baselineProvider).valueOrNull;
    final layer2 = result?['layer2'];
    final signals = layer2 is Map
        ? Map<String, dynamic>.from(layer2['drift_result']?['drift_signals'] ?? {})
        : <String, dynamic>{};
    final baselineFeatures = baseline?['features'] is Map
        ? Map<String, dynamic>.from(baseline!['features'] as Map)
        : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (signals.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No analyzed sessions yet'),
                subtitle: Text(
                    'Per-feature trends appear once Layer 2 monitoring is active.'),
              ),
            )
          else
            for (final entry in signals.entries)
              _MetricCard(
                name: entry.key,
                signal: Map<String, dynamic>.from(entry.value as Map),
                baselineEntry: baselineFeatures[entry.key] is Map
                    ? Map<String, dynamic>.from(
                        baselineFeatures[entry.key] as Map)
                    : null,
              ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Session history'),
              onTap: () => context.go('/insights/history'),
            ),
          ),
        ],
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
    final robustZ =
        (signal['robust_z_current'] as num?)?.toDouble() ?? 0.0;
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
