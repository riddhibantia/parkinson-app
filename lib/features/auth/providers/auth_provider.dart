import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Setup completion that survives restart/login/navigation.
/// Persisted to SharedPreferences (and Firestore for real users if available).
/// This is the single gate: hasCompletedSetup == true → never auto-send to onboarding.
class HasOnboardedNotifier extends StateNotifier<bool> {
  HasOnboardedNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getBool('hasOnboarded_v2') ?? false;
      // Use super.state to avoid double persist on load
      super.state = local;
    } catch (_) {}
  }

  @override
  set state(bool value) {
    super.state = value;
    // Persist whenever state changes (covers both direct assignment and setCompleted)
    SharedPreferences.getInstance().then(
      (p) => p.setBool('hasOnboarded_v2', value),
    );
  }

  Future<void> setCompleted(bool v) async {
    state = v;
  }
}

final hasOnboardedProvider = StateNotifierProvider<HasOnboardedNotifier, bool>(
  (ref) => HasOnboardedNotifier(),
);

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  const PlaceholderScreen({super.key, required this.title, this.subtitle = ''});

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
