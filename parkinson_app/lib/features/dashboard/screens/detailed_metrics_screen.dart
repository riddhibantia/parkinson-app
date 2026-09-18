import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Deep-dive metrics shell (Stage 7.3 structure).
/// Trend charts render here once analyzed session series exist; until
/// then each card states plainly that there is nothing to show yet.
class DetailedMetricsScreen extends StatelessWidget {
  const DetailedMetricsScreen({super.key});

  static const _metrics = [
    ('Hold time trend', 'Average key-press duration per session.'),
    ('Flight time trend', 'Finger transition speed per session.'),
    ('Hand asymmetry', 'Left/right timing balance per session.'),
    ('Session consistency', 'Rhythm regularity per session.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, subtitle) in _metrics)
            Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text('$subtitle\nNo analyzed sessions yet.'),
                isThreeLine: true,
              ),
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
