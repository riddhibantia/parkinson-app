import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/providers/analysis_mode_provider.dart';
import '../../core/providers/app_mode_provider.dart';
import '../../shared/widgets/parkin_trace_logo.dart';

class AppSidebar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppSidebar({super.key, required this.navigationShell});

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.keyboard_outlined, Icons.keyboard, 'Typing Session'),
    (Icons.insights_outlined, Icons.insights, 'Insights'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(appModeProvider).isDemo;
    final analysisMode = ref.watch(analysisModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand — ParkinTrace
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: const ParkinTraceLogo(size: 36, showWordmark: true),
          ),
          if (analysisMode != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: AppRadii.radiusMd,
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                analysisMode == AnalysisMode.layer1 ? 'LAYER 1 · Quick Analysis' : 'LAYER 2 · Personal Monitoring',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 8),
          if (isDemo)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: AppRadii.radiusMd,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'DEMO MODE',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Sample data',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Nav — fixed order Home, Typing Session, Insights, Profile
          for (var i = 0; i < _items.length; i++)
            _NavItem(
              icon: _items[i].$1,
              activeIcon: _items[i].$2,
              label: _items[i].$3,
              selected: navigationShell.currentIndex == i,
              onTap: () {
                // Insights is mode-aware: go to correct layer's insights
                if (i == 2) {
                  final mode = ref.read(analysisModeProvider);
                  if (mode == AnalysisMode.layer1) {
                    context.go('/insights/layer1');
                    return;
                  } else if (mode == AnalysisMode.layer2) {
                    context.go('/insights/layer2');
                    return;
                  }
                }
                navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);
              },
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('ANALYSIS MODES',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.6, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
          ),
          const SizedBox(height: 8),
          _LayerModeButton(
            icon: Icons.science_outlined,
            label: 'Layer 1',
            subtitle: 'Quick Analysis',
            selected: analysisMode == AnalysisMode.layer1,
            onTap: () async {
              await ref.read(analysisModeProvider.notifier).setMode(AnalysisMode.layer1);
              if (context.mounted) context.go('/home');
            },
          ),
          const SizedBox(height: 6),
          _LayerModeButton(
            icon: Icons.timeline_outlined,
            label: 'Layer 2',
            subtitle: 'Personal Monitoring',
            selected: analysisMode == AnalysisMode.layer2,
            onTap: () async {
              await ref.read(analysisModeProvider.notifier).setMode(AnalysisMode.layer2);
              if (context.mounted) context.go('/home');
            },
          ),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (isDemo) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(appModeProvider.notifier).resetDemo(),
                      child: const Text('Reset demo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        ref.read(appModeProvider.notifier).exitDemo();
                        context.go('/login');
                      },
                      child: const Text('Exit demo'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/profile/settings'),
                      child: const Text('Settings'),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'v1.0 · Research preview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: AppRadii.radiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.radiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(selected ? activeIcon : icon, size: 20, color: selected ? AppColors.primary : null),
                const SizedBox(width: 10),
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppColors.primary : null)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _LayerModeButton({required this.icon, required this.label, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF10B981).withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: AppRadii.radiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.radiusMd,
          child: Container(
            decoration: selected ? BoxDecoration(border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)), borderRadius: AppRadii.radiusMd) : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: selected ? const Color(0xFF10B981) : null),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? const Color(0xFF10B981) : null, fontSize: 13)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
