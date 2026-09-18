import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/motor_task_provider.dart';

/// Short alternating-key task (Stage 2.3, 10-15 s).
/// A targeted repetitive-movement measure, not a speed competition.
/// Results feed Layer 2 only — never Layer 1.
class MotorTaskScreen extends ConsumerStatefulWidget {
  const MotorTaskScreen({super.key});

  @override
  ConsumerState<MotorTaskScreen> createState() => _MotorTaskScreenState();
}

class _MotorTaskScreenState extends ConsumerState<MotorTaskScreen> {
  Timer? _timer;
  int _secondsLeft = AppConstants.motorTaskSeconds;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    ref.read(motorTaskProvider.notifier).start();
    setState(() => _secondsLeft = AppConstants.motorTaskSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        _finish();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    final result = ref.read(motorTaskProvider.notifier).finish();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task complete'),
        content: Text(
          '${result.tapCount} alternating taps recorded. '
          'This measures task mechanics only.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/type');
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(motorTaskProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Motor task')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Repeatedly alternate between the F and J keys as quickly '
              'and accurately as comfortable.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _KeyBadge(label: 'F'),
                SizedBox(width: 16),
                _KeyBadge(label: 'J'),
              ],
            ),
            const SizedBox(height: 24),
            if (task.running) ...[
              Text(
                '$_secondsLeft s left — ${task.tapCount} taps',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _finish,
                child: const Text('Finish early'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _start,
                child: const Text('Start 15-second task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String label;
  const _KeyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
