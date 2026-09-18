import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/session_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Profile hub: check-in, settings, info screens, sign-out.
/// Sign-out flushes buffered sessions first so nothing is silently lost.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut(
            flushBeforeSignOut:
                ref.read(sessionRepositoryProvider).syncPending,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Daily check-in'),
              onTap: () => context.go('/checkin'),
            ),
          ),
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
              title: const Text('About'),
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Sign out'),
              onTap: () => _signOut(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
