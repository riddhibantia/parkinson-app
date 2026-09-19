import 'package:flutter/material.dart';

/// Pulsing dot / icon for live status (non-alarming).
class AnimatedStatusIndicator extends StatefulWidget {
  final Color color;
  final IconData icon;
  final double size;
  const AnimatedStatusIndicator({
    super.key,
    required this.color,
    required this.icon,
    this.size = 24,
  });

  @override
  State<AnimatedStatusIndicator> createState() =>
      _AnimatedStatusIndicatorState();
}

class _AnimatedStatusIndicatorState extends State<AnimatedStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.7, end: 1).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}
