import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/user_profile.dart';
import '../../typing_test/providers/familiarization_provider.dart';
import '../widgets/onboarding_scaffold.dart';

/// Q1 — Typing experience (Stage 1.6). One question per screen, progress bar.
/// Stored only to set the familiarization requirement — not an ML feature.
class TypingExperienceScreen extends ConsumerStatefulWidget {
  const TypingExperienceScreen({super.key});

  @override
  ConsumerState<TypingExperienceScreen> createState() => _TypingExperienceScreenState();
}

class _TypingExperienceScreenState extends ConsumerState<TypingExperienceScreen> {
  TypingExperienceLevel? _selected;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      totalSteps: 5,
      title: 'How comfortable are you with typing on a physical keyboard?',
      subtitle:
          'We use this to determine how much keyboard familiarization you may need before your measurements are used.',
      onBack: () => context.go('/onboarding/how-it-works'),
      onContinue: _selected == null
          ? null
          : () {
              ref.read(familiarizationProvider.notifier).setExperienceLevel(_selected!);
              context.go('/onboarding/demographics');
            },
      canContinue: _selected != null,
      continueLabel: 'Continue',
      child: Column(
        children: [
          for (final level in TypingExperienceLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: _selected == level ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: _selected == level
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: _selected == level ? 1.5 : 1),
                ),
                child: ListTile(
                  title: Text(level.label),
                  subtitle: Text(level.description),
                  trailing: Text('${level.requiredPracticeSessions} practice',
                      style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => setState(() => _selected = level),
                  selected: _selected == level,
                  selectedTileColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
