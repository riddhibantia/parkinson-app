import 'package:flutter/material.dart';

/// Professional ParkinTrace logo — circular emblem with P + keyboard/waveform.
/// Minimal, geometric, scalable at 24px to 128px.
class ParkinTraceLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  const ParkinTraceLogo({super.key, this.size = 48, this.showWordmark = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F766E),
                const Color(0xFF115E59),
              ],
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F766E).withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: CustomPaint(
            painter: _LogoPainter(),
            child: Center(
              child: Text('P',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.5)),
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ParkinTrace',
                  style: TextStyle(
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleSmall?.color,
                      height: 1)),
              Text('Typing patterns for Parkinson\'s monitoring',
                  style: TextStyle(fontSize: size * 0.14, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Subtle keyboard keys at bottom arc
    final keyPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.38;
    // three tiny rounded rects for keys
    for (var i = -1; i <= 1; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx + i * size.width * 0.15, center.dy + size.height * 0.22), width: size.width * 0.12, height: size.width * 0.08),
        Radius.circular(2),
      );
      canvas.drawRRect(rect, keyPaint);
    }

    // Waveform arc at top
    final path = Path();
    path.moveTo(center.dx - r * 0.7, center.dy - size.height * 0.12);
    path.quadraticBezierTo(center.dx - r * 0.35, center.dy - size.height * 0.22, center.dx, center.dy - size.height * 0.12);
    path.quadraticBezierTo(center.dx + r * 0.35, center.dy - size.height * 0.02, center.dx + r * 0.7, center.dy - size.height * 0.12);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
