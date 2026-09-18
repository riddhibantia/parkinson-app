import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../auth/providers/auth_provider.dart';

/// Profile hub: check-in, settings, info screens, sign-out.
/// Sign-out flushes buffered sessions first so nothing is silently lost.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .signOut(
            flushBeforeSignOut: ref.read(sessionRepositoryProvider).syncPending,
          );
    } catch (_) {
      // Local stand-in never throws; Firebase errors surface on the
      // login screen after redirect.
    }
    ref.read(isSignedInProvider.notifier).state = false;
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(appModeProvider).isDemo;
    return Scaffold(
      appBar: AppTopBar(
        title: isDemo ? 'Profile — Demo' : 'Profile',
        subtitle: isDemo ? 'Sample / Demo Data' : null,
      ),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isDemo)
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('DEMO ACCOUNT'),
                  subtitle: const Text("You're exploring with sample data."),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(appModeProvider.notifier).resetDemo(),
                    child: const Text('Reset demo'),
                  ),
                ),
              ),
            const SectionHeader(
              title: 'Profile',
              subtitle: 'Personal context for research',
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist_outlined),
                title: const Text('Daily check-in'),
                subtitle: const Text(
                  '0–10 sliders, 20–30s — not part of ML score',
                ),
                onTap: () => context.go('/checkin'),
              ),
            ),
            const SectionHeader(title: 'Monitoring'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Baseline & sessions'),
                subtitle: const Text('See progress and history'),
                onTap: () => context.go('/insights'),
              ),
            ),
            const SectionHeader(title: 'Account & Info'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => context.go('/profile/settings'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About — How it works'),
                onTap: () => context.go('/about'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('FAQ'),
                onTap: () => context.go('/faq'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Medical disclaimer'),
                onTap: () => context.go('/disclaimer'),
              ),
            ),
            const SizedBox(height: 8),
            if (isDemo) ...[
              SecondaryButton(
                label: 'Create real account',
                onPressed: () {
                  ref.read(appModeProvider.notifier).exitDemo();
                  context.go('/signup');
                },
              ),
              const SizedBox(height: 8),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: Text(isDemo ? 'Exit demo' : 'Sign out'),
                onTap: () => _signOut(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
