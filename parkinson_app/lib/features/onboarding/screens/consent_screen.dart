import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Legacy consent route — now merged into How it works. Redirects there.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Privacy+consent now lives on How it works (same page). Keep this route alive for back-compat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/onboarding/how-it-works');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
