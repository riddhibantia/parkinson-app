import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/parkin_trace_logo.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  void _onBegin(BuildContext context, WidgetRef ref) {
    final signedIn = ref.read(isSignedInProvider);
    final onboarded = ref.read(hasOnboardedProvider);
    if (!signedIn) {
      // Not signed in → go to Login first, then setup (once) after login
      context.go('/login');
    } else if (!onboarded) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ParkinTraceLogo(size: 96),
              const SizedBox(height: 24),
              Text('ParkinTrace', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 36)),
              const SizedBox(height: 8),
              Text("Typing patterns for Parkinson's monitoring",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color),
                  textAlign: TextAlign.center),
              const SizedBox(height: 40),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: () => _onBegin(context, ref),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('BEGIN', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
