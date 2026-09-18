import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Per-feature sparkline using last 10 sessions.
/// Expects values oldest-first. Empty -> placeholder.
class MetricTrendChart extends StatelessWidget {
  final String featureLabel;
  final List<double> values;
  final double? baselineMedian;
  const MetricTrendChart({
    super.key,
    required this.featureLabel,
    required this.values,
    this.baselineMedian,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$featureLabel — not enough history yet'),
        ),
      );
    }
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final median = baselineMedian;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(featureLabel, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.teal.withValues(alpha: 0.08),
                      ),
                    ),
                    if (median != null)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, median),
                          FlSpot(values.length - 1.0, median),
                        ],
                        isCurved: false,
                        dotData: const FlDotData(show: false),
                        dashArray: [6, 4],
                      ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: median == null
                        ? []
                        : [
                            HorizontalLine(
                              y: median,
                              color: Colors.grey.withValues(alpha: 0.4),
                              strokeWidth: 1,
                              dashArray: [6, 4],
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
