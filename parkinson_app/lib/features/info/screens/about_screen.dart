import 'package:flutter/material.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';

/// How it works — visual 3-step, plain language (Section 25).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'How it works'),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'What this app does',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'This app studies typing timing and a short tapping task to build a personal picture of your motor patterns over time. It compares new sessions against your own history and, separately, against timing ranges from Parkinson\'s typing research data.',
            ),
            const SizedBox(height: 24),
            const _StepCard(
              number: '1',
              title: 'TYPE',
              subtitle: 'The app captures timing from your keyboard.',
              desc:
                  'Hold time, flight time, and key rhythm — not what you write. Your typed words are never stored as content.',
            ),
            const _StepCard(
              number: '2',
              title: 'ANALYZE',
              subtitle: 'The system extracts timing features.',
              desc:
                  'Timing patterns are summarized per session and compared with research patterns and your personal baseline.',
            ),
            const _StepCard(
              number: '3',
              title: 'MONITOR',
              subtitle: 'See changes over time.',
              desc:
                  'Over days and weeks you build a personal baseline. Later sessions are checked for sustained changes — a monitoring signal, not a diagnosis.',
            ),
            const SizedBox(height: 16),
            const GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What we do NOT collect',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your typed words are not stored as content. Raw key identity is discarded at capture after deriving hand/row. Only timing is kept.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is a research and screening tool. It does NOT diagnose any medical condition. Always consult a qualified healthcare professional for medical advice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final String desc;
  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(desc, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
