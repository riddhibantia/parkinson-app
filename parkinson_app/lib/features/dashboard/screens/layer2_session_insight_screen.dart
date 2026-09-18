import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/services/demo_data_service.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../data/services/local_analysis_service.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';

class Layer2SessionInsightScreen extends ConsumerWidget {
  final String sessionId;
  const Layer2SessionInsightScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(localSessionsProvider);
    final sessions = sessionsAsync.valueOrNull ?? [];
    final isDemo = ref.watch(appModeProvider).isDemo;
    final effectiveSessions = (isDemo && sessions.isEmpty) ? DemoDataService.demoSessions() : sessions;
    final session = effectiveSessions.where((s) => s.sessionId == sessionId).firstOrNull ??
        effectiveSessions.firstOrNull;
    if (session == null) {
      return Scaffold(appBar: const AppTopBar(title: "Today's session", subtitle: 'Personal monitoring'), body: const Center(child: Text('Session not found')));
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
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Interactive chart', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          DropdownButton<String>(value: _selected, items: [for (final m in _metrics) DropdownMenuItem(value: m, child: Text(m, style: Theme.of(context).textTheme.bodySmall))], onChanged: (v) => setState(() => _selected = v ?? _selected)),
        ]),
        const SizedBox(height: 12),
        Container(height: 100, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('$_selected — Session value vs personal range', style: Theme.of(context).textTheme.bodySmall))),
        const SizedBox(height: 8),
        Text('Tap metric to switch. Chart helps understand $_selected.', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
