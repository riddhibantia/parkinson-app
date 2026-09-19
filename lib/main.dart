import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repositories/session_repository.dart';

/// Firebase wiring: `flutterfire configure` has generated
/// firebase_options.dart (project parkinson-app-rbt). Desktop uses the
/// REST layer (5a-verified); plugin init is attempted for mobile targets
/// and skipped silently on desktop without native config.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Desktop local/REST mode — no native config required.
  }
  final container = ProviderContainer();
  try {
    await container.read(firebaseRestProvider).restore();
  } catch (_) {
    // Offline or no stored session — start signed out.
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ParkinsonApp(),
    ),
  );
}
