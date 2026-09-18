import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/glass_card.dart';

/// Typing hub — three large cards, plain language, one primary CTA.
class TypingScreen extends StatelessWidget {
  const TypingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        title: 'Typing',
        subtitle: 'Choose a short activity.',
      ),
      body: GradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SectionHeader(
                  title: 'What would you like to do?',
                  subtitle:
                      'All activities measure timing, not what you write.',
                ),
                _TypeCard(
                  badge: 'RECOMMENDED',
                  icon: Icons.article_outlined,
                  title: 'Structured typing',
                  desc: 'Type a neutral sentence for about one minute.',
                  cta: 'Start',
                  onTap: () => context.go('/type/structured'),
                ),
                _TypeCard(
                  icon: Icons.edit_note_outlined,
                  title: 'Free typing',
                  desc:
                      'Type naturally. We measure timing, not what you write.',
                  cta: 'Start',
                  onTap: () => context.go('/type/free'),
                ),
                _TypeCard(
                  icon: Icons.repeat_outlined,
                  title: 'Motor task',
                  desc: '15-second alternating F/J tapping task.',
                  cta: 'Start',
                  onTap: () => context.go('/type/motor-task'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String? badge;
  final IconData icon;
  final String title;
  final String desc;
  final String cta;
  final VoidCallback onTap;
  const _TypeCard({
    this.badge,
    required this.icon,
    required this.title,
    required this.desc,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(desc, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onTap, child: Text(cta)),
            ),
          ],
        ),
      ),
    );
  }
}
