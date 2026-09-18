import 'package:flutter/material.dart';

class TypingProgressBar extends StatelessWidget {
  final double progress; // 0-1
  const TypingProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: progress);
  }
}

class SessionTimer extends StatelessWidget {
  final int seconds;
  const SessionTimer({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return Text('$m:$s', style: Theme.of(context).textTheme.titleSmall);
  }
}
