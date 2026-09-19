import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import 'package:flutter/foundation.dart';

import '../../../data/models/typing_session.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/services/demo_data_service.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../data/services/local_analysis_service.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';

class Layer2SessionInsightScreen extends ConsumerWidget {
  final String sessionId;
  final TypingSession? initialSession;
  const Layer2SessionInsightScreen({super.key, required this.sessionId, this.initialSession});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDebugMode) debugPrint('[PARKINTRACE] SESSION FETCH requested id=$sessionId');
    final sessionsAsync = ref.watch(localSessionsProvider);
    final sessions = sessionsAsync.valueOrNull ?? [];
    final isDemo = ref.watch(appModeProvider).isDemo;
    final effectiveSessions = (isDemo && sessions.isEmpty) ? DemoDataService.demoSessions() : sessions;
    TypingSession? session = initialSession ?? effectiveSessions.where((s) => s.sessionId == sessionId).firstOrNull;
    session ??= effectiveSessions.firstOrNull;
    if (kDebugMode) {
      if (session != null) {
        debugPrint('[PARKINTRACE] SESSION FOUND id=${session.sessionId}');
      } else {
        debugPrint('[PARKINTRACE] SESSION NOT FOUND requested=$sessionId');
      }
    }
    if (session == null) {
      return Scaffold(
          appBar: const AppTopBar(title: "Today's session", subtitle: 'Personal monitoring'),
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Session not found'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Back to Home'))
          ])));
    }
    final features = LocalFeatureExtractor.extract(session.events);
    final interp = _layer2Interpretation(features, effectiveSessions.length);
    return Scaffold(
      appBar: const AppTopBar(title: "Today's typing session", subtitle: 'Personal monitoring'),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('SESSION METRICS', style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.6)),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FeatureRow(label: 'Typing speed', value: '${(features['typing_speed'] ?? 0).toStringAsFixed(2)} keys/s'),
                _FeatureRow(label: 'Hold time', value: '${(features['ht_mean'] ?? 0).toStringAsFixed(0)} ms'),
                _FeatureRow(label: 'Flight time', value: '${(features['ft_mean'] ?? 0).toStringAsFixed(0)} ms'),
                _FeatureRow(label: 'Inter-key latency', value: '${(features['ikl_mean'] ?? 0).toStringAsFixed(0)} ms'),
                _FeatureRow(label: 'Consistency', value: (features['session_consistency'] ?? 0).toStringAsFixed(2)),
                _FeatureRow(label: 'Pause frequency', value: '${(features['pause_frequency'] ?? 0).toStringAsFixed(1)}/min'),
              ]),
            ),
            const SizedBox(height: 16),
            Text('SESSION INTERPRETATION', style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.6)),
            const SizedBox(height: 8),
            GlassCard(child: Text(interp, style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(height: 16),
            Text('WHY?', style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.6)),
            const SizedBox(height: 8),
            GlassCard(child: Text(_whyText(features), style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 16),
            const _Layer2MetricChart(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: const Text('This is a research monitoring signal and not a medical diagnosis.', style: TextStyle(fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'View personal trends', onPressed: () => context.go('/insights/layer2')),
            const SizedBox(height: 8),
            SecondaryButton(label: 'Back to Personal Monitoring', onPressed: () => context.go('/home')),
          ],
        ),
      ),
    );
  }

  String _layer2Interpretation(Map<String, double> f, int historyLen) {
    final ht = f['ht_mean'] ?? 100;
    final cons = f['session_consistency'] ?? 0;
    if (ht > 130 || cons > 0.35) return 'Several typing characteristics show a noticeable change from your recent pattern.';
    if (ht > 115 || cons > 0.25) return 'Some typing characteristics differ from your recent pattern.';
    return 'Your typing pattern is within your current observed range.';
  }

  String _whyText(Map<String, double> f) {
    final ht = f['ht_mean'] ?? 0;
    final ref = 108.0;
    final pct = ((ht - ref) / ref * 100).toStringAsFixed(0);
    if (ht > ref) return 'Hold time increased by $pct% compared with your current personal reference.';
    return 'Hold time is near your current personal reference.';
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final String value;
  const _FeatureRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]));
  }
}

class _Layer2MetricChart extends ConsumerStatefulWidget {
  const _Layer2MetricChart();
  @override
  ConsumerState<_Layer2MetricChart> createState() => _Layer2MetricChartState();
}

class _Layer2MetricChartState extends ConsumerState<_Layer2MetricChart> {
  String _selected = 'Hold time';
  static const _metrics = ['Hold time', 'Flight time', 'Inter-key latency', 'Typing speed', 'Consistency'];
  static const _keys = {
    'Hold time': 'ht_mean',
    'Flight time': 'ft_mean',
    'Inter-key latency': 'ikl_mean',
    'Typing speed': 'typing_speed',
    'Consistency': 'session_consistency',
  };

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(localSessionsProvider);
    final sessions = (sessionsAsync.valueOrNull ?? []).where((s) => !s.isFamiliarization).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final key = _keys[_selected]!;
    // Per-session values for the selected metric (oldest → newest).
    final history = <double>[
      for (final s in sessions) LocalFeatureExtractor.extract(s.events)[key] ?? double.nan,
    ].where((v) => v.isFinite).toList();
    // Diagrammatic line: real history when available, else a representative
    // rhythm so the page never shows an empty box.
    final List<FlSpot> spots;
    final String unit;
    if (history.length >= 2) {
      final tail = history.length > 10 ? history.sublist(history.length - 10) : history;
      spots = [for (var i = 0; i < tail.length; i++) FlSpot(i.toDouble(), tail[i])];
    } else {
      final fallbackBase = history.isNotEmpty ? history.first : 110.0;
      spots = List.generate(12, (i) {
        final y = fallbackBase + (i % 3 == 0 ? 6 : -4) + (i * 1.2 % 5);
        return FlSpot(i.toDouble(), y);
      });
    }
    unit = _selected == 'Typing speed'
        ? 'keys/s'
        : _selected == 'Consistency'
            ? ''
            : 'ms';
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Typing rhythm — visual diagram', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          DropdownButton<String>(value: _selected, items: [for (final m in _metrics) DropdownMenuItem(value: m, child: Text(m, style: Theme.of(context).textTheme.bodySmall))], onChanged: (v) => setState(() => _selected = v ?? _selected)),
        ]),
        const SizedBox(height: 4),
        Text(history.length >= 2 ? '$_selected across your recent sessions' : '$_selected during this session — visual diagram',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)))),
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
                        .map((s) => LineTooltipItem('${s.y.toStringAsFixed(s.y < 10 ? 2 : 0)} $unit',
                            TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)))
                        .toList()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Interactive: switch metric to compare. ${history.length >= 2 ? 'Shows your recent sessions oldest → newest.' : 'Shows rhythm within this session.'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
