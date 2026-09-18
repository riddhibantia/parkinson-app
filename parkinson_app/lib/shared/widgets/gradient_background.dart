import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [AppColors.backgroundDark, const Color(0xFF141A33)]
              : [AppColors.backgroundLight, Colors.white],
        ),
      ),
      child: child,
    );
  }
}
