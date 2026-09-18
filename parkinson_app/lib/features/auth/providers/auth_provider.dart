import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/session_repository.dart';

/// Session state for router guards (Stage 1.3/1.5).
/// Firebase persistence (currentUser on relaunch) drives these once
/// firebase_options.dart exists; LocalAuthRepository keeps UI work
/// unblocked until then.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Desktop uses the 5a-verified REST path; the plugin implementation
  // stays for mobile targets.
  return RestAuthRepository(rest: ref.watch(firebaseRestProvider));
});

final isSignedInProvider = StateProvider<bool>((ref) => false);
final hasOnboardedProvider = StateProvider<bool>((ref) => false);

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitle),
            ],
          ],
        ),
      ),
    );
  }
}
