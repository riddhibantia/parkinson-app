import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label),
              ]),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status; // normal/watch/attention/building
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case 'attention':
        c = AppColors.statusAttention;
        label = 'Attention';
        break;
      case 'watch':
        c = AppColors.statusWatch;
        label = 'Watch';
        break;
      case 'building':
        c = AppColors.textMutedDark;
        label = 'Building';
        break;
      default:
        c = AppColors.statusNormal;
        label = 'Normal';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(label.toUpperCase(), style: AppTextStyles.caption.copyWith(color: c)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class ProgressCard extends StatelessWidget {
  final String title;
  final String progressText;
  final double fraction; // 0-1
  final String caption;
  const ProgressCard({super.key, required this.title, required this.progressText, required this.fraction, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(progressText, style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: fraction.clamp(0, 1)),
          const SizedBox(height: 8),
          Text(caption, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
