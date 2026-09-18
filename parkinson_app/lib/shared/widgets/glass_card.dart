import 'package:flutter/material.dart';

/// Glass-like translucent card (calm, low saturation).
/// Fallback to regular Card on older platforms — no blur dep required.
class GlassCard extends StatelessWidget {
  final Widget child;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tint?.withValues(alpha: 0.12) ??
        scheme.surface.withValues(alpha: 0.95);
    return Card(
      color: bg,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
