import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../core/theme/app_colors.dart';

import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../features/typing_test/providers/last_result_provider.dart';
import '../screens/dashboard_screen.dart' show latestResultProvider;

class Layer1ResultScreen extends ConsumerWidget {
  const Layer1ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(latestResultProvider).valueOrNull;
    final local = ref.watch(lastLocalLayer1ResultProvider);
    final layer1 = result?['layer1'] ?? local;
    final shapStatus = '${result?['shap_status'] ?? ''}';
    final isDemo = result?['_demo'] == true;
    final features = ref.watch(lastLocalFeaturesProvider);

    return Scaffold(
      appBar: const AppTopBar(
        title: 'Your typing-pattern comparison',
        subtitle: 'Layer 1 · Quick Analysis — Population comparison',
      ),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (layer1 == null)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Not enough data yet'),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete 1–2 typing sessions to see your research comparison.',
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Start typing session',
                      onPressed: () => context.go('/type/structured'),
                    ),
                  ],
                ),
              )
            else ...[
              if (isDemo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Sample / Demo Data',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Text('YOUR LAYER 1 RESULT',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.6, color: Theme.of(context).textTheme.bodySmall?.color)),
                    const SizedBox(height: 8),
                    Text('Model output', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      (layer1['pd_probability'] is num) ? (layer1['pd_probability'] as num).toStringAsFixed(2) : '—',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 48, height: 1),
                    ),
                    Text('Output from the population-level research model',
                        style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor('${layer1['status']}', context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_interpretation('${layer1['status']}'), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your typing features were compared with patterns learned from research datasets.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layer1['message'] as String,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'This is a research screening signal and should not be interpreted as a medical diagnosis.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
              if (features != null && features.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your typing pattern — summary',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _FeatureRow(
                        label: 'Typing speed',
                        value:
                            '${(features['typing_speed'] ?? 0).toStringAsFixed(2)} keys/s',
                      ),
                      _FeatureRow(
                        label: 'Hold time',
                        value:
                            '${(features['ht_mean'] ?? 0).toStringAsFixed(0)} ms',
                      ),
                      _FeatureRow(
                        label: 'Flight time',
                        value:
                            '${(features['ft_mean'] ?? 0).toStringAsFixed(0)} ms',
                      ),
                      _FeatureRow(
                        label: 'Inter-key latency',
                        value:
                            '${(features['ikl_mean'] ?? 0).toStringAsFixed(0)} ms',
                      ),
                      _FeatureRow(
                        label: 'Consistency',
                        value: (features['session_consistency'] ?? 0)
                            .toStringAsFixed(2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _InteractiveMetricChart(),
              ],
              if (layer1['top_contributors'] is List &&
                  (layer1['top_contributors'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
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
              ] else if (shapStatus == 'pending')
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
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('How this works'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• Typing timing features: hold time, flight time, inter-key latency, consistency, hand asymmetry, pauses.',
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• Population model trained on Tappy + neuroQWERTY research datasets.',
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• Limitations: cross-subject accuracy is modest; this is research support, not diagnosis.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Back to Home',
              onPressed: () => context.go('/home'),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Try another session',
              onPressed: () => context.go('/type/structured'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final String value;
  const _FeatureRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status, BuildContext context) {
  switch (status) {
    case 'attention':
      return AppColors.statusAttention;
    case 'watch':
      return AppColors.statusWatch;
    default:
      return AppColors.statusNormal;
  }
}

String _interpretation(String status) {
  switch (status) {
    case 'attention':
      return 'MORE DISTINCTLY DIFFERENT — The model identified a stronger difference from the reference typing patterns.';
    case 'watch':
      return 'DEVIATED FROM REFERENCE — Your typing pattern differs from the reference patterns used by the model.';
    default:
      return 'WITHIN EXPECTED RESEARCH RANGE — Your typing pattern is broadly within the range represented by the reference data.';
  }
}

class _InteractiveMetricChart extends ConsumerStatefulWidget {
  const _InteractiveMetricChart();

  @override
  ConsumerState<_InteractiveMetricChart> createState() => _InteractiveMetricChartState();
}

class _InteractiveMetricChartState extends ConsumerState<_InteractiveMetricChart> {
  String _selected = 'Hold time';
  static const _metrics = ['Hold time', 'Flight time', 'Inter-key latency', 'Typing speed', 'Consistency'];
  static const _ref = {
    'Hold time': 108.0,
    'Flight time': 85.0,
    'Inter-key latency': 210.0,
    'Typing speed': 4.2,
    'Consistency': 0.26,
  };
  static const _keys = {
    'Hold time': 'ht_mean',
    'Flight time': 'ft_mean',
    'Inter-key latency': 'ikl_mean',
    'Typing speed': 'typing_speed',
    'Consistency': 'session_consistency',
  };

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(lastLocalFeaturesProvider);
    final yourVal = features?[_keys[_selected]!] ?? 0.0;
    final refVal = _ref[_selected] ?? 1.0;
    final ratio = (yourVal / (refVal == 0 ? 1 : refVal)).clamp(0.3, 1.7);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Feature profile', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              DropdownButton<String>(
                value: _selected,
                items: [for (final m in _metrics) DropdownMenuItem(value: m, child: Text(m, style: Theme.of(context).textTheme.bodySmall))],
                onChanged: (v) => setState(() => _selected = v ?? _selected),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Your session vs Research reference', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 4),
                    Text('Your: ${yourVal.toStringAsFixed(yourVal < 10 ? 2 : 0)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Container(height: 14, width: 60 + ratio * 40, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 4),
                    Text('Ref: ${refVal.toStringAsFixed(refVal < 10 ? 2 : 0)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Interactive: switch metric to compare. Bars scaled for display.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
