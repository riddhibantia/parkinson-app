import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/user_profile.dart';
import '../../typing_test/providers/familiarization_provider.dart';

/// Typing-experience question (Stage 1.6). Stored only to set the
/// familiarization requirement — not an ML feature.
class TypingExperienceScreen extends ConsumerWidget {
  const TypingExperienceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Typing experience'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How familiar are you with typing on a physical keyboard?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'This sets how many practice sessions come first. '
              'Practice is never used for results.',
            ),
            const SizedBox(height: 16),
            for (final level in TypingExperienceLevel.values)
              Card(
                child: ListTile(
                  title: Text(level.label),
                  subtitle: Text(level.description),
                  trailing:
                      Text('${level.requiredPracticeSessions} practice'),
                  onTap: () {
                    ref
                        .read(familiarizationProvider.notifier)
                        .setExperienceLevel(level);
                    context.go('/onboarding/demographics');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
