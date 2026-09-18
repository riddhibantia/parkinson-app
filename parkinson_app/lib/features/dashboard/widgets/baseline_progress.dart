import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class BaselineProgress extends StatelessWidget {
  final int screeningSessions;
  const BaselineProgress({super.key, required this.screeningSessions});

  @override
  Widget build(BuildContext context) {
    final total = AppConstants.minimumSessionsForBaseline;
    final fraction = (screeningSessions / total).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Baseline progress',
                    style: Theme.of(context).textTheme.titleSmall),
                Text('$screeningSessions / $total+'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 6),
            Text(
              fraction >= 1
                  ? 'Baseline ready — personal trend active'
                  : 'Keep typing on the same keyboard across multiple days.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
