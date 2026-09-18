import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_mode_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/parkin_trace_logo.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  const AppTopBar({super.key, required this.title, this.subtitle});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(appModeProvider).isDemo;
    return AppBar(
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        if (isDemo)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.science_outlined, size: 14),
              const SizedBox(width: 6),
              Text('DEMO', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        const ParkinTraceLogo(size: 28),
        const SizedBox(width: 4),
        IconButton(tooltip: 'Settings', onPressed: () => context.go('/profile/settings'), icon: const Icon(Icons.settings_outlined)),
        const SizedBox(width: 8),
      ],
    );
  }
}
