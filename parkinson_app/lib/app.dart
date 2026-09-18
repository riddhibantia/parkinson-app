import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

/// App-level config, theme, routing.
class ParkinsonApp extends ConsumerWidget {
  const ParkinsonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'TypeMonitor',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      routerConfig: router,
    );
  }
}
