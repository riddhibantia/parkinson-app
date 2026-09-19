import 'package:flutter/material.dart';

/// Non-alarming recommendation band (Stage 9.4) — appears only for
/// watch/attention results, calm language, no red.
class RecommendationBanner extends StatelessWidget {
  final String status;
  const RecommendationBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'normal' || status == 'building') return const SizedBox.shrink();
    final isAttention = status == 'attention';
    return Card(
      color: isAttention
          ? const Color(0xFFFFF3E0)
          : const Color(0xFFFFF8E1),
      child: ListTile(
        leading: Icon(
            isAttention ? Icons.medical_information_outlined : Icons.info_outline,
            color: Theme.of(context).colorScheme.primary),
        title: Text(isAttention
            ? 'Consider discussing this with a clinician'
            : 'Keep typing regularly — we are tracking changes'),
        subtitle: const Text(
            'This is not a diagnosis. Results are for information only.'),
      ),
    );
  }
}
