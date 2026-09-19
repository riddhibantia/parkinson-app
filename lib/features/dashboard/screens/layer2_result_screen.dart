import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/services/local_analysis_service.dart';
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
            const _Layer2TrendChart(),
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

/// Diagrammatic line chart for Layer 2: hold-time trend across recent
/// screening sessions (oldest → newest). Falls back to a representative
/// rhythm so the page is never an empty box.
class _Layer2TrendChart extends ConsumerWidget {
  const _Layer2TrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = (ref.watch(localSessionsProvider).valueOrNull ?? []).where((s) => !s.isFamiliarization).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final history = <double>[
      for (final s in sessions) LocalFeatureExtractor.extract(s.events)['ht_mean'] ?? double.nan,
    ].where((v) => v.isFinite).toList();
    final List<FlSpot> spots;
    final String subtitle;
    if (history.length >= 2) {
      final tail = history.length > 10 ? history.sublist(history.length - 10) : history;
      spots = [for (var i = 0; i < tail.length; i++) FlSpot(i.toDouble(), tail[i])];
      subtitle = 'Hold time across your recent sessions — visual diagram';
    } else {
      spots = List.generate(10, (i) => FlSpot(i.toDouble(), 108 + (i % 3 == 0 ? 5 : -3) + (i * 0.8 % 4)));
      subtitle = 'Baseline rhythm preview (illustrative) — visual diagram';
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal trend', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (v, m) => Text('${v.toInt()}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)))),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) => Text('${v.toInt() + 1}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touched) => touched
                          .map((s) => LineTooltipItem('${s.y.toStringAsFixed(0)} ms',
                              TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)))
                          .toList()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


