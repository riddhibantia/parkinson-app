import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/keystroke_capture_service.dart';
import '../widgets/notepad_area.dart';

/// Notepad-style free typing (Stage 2.4). Same capture engine, natural
/// collection. The visible text is discarded on finish — only keystroke
/// timing events are kept.
class FreeTypingScreen extends ConsumerStatefulWidget {
  const FreeTypingScreen({super.key});

  @override
  ConsumerState<FreeTypingScreen> createState() => _FreeTypingScreenState();
}

class _FreeTypingScreenState extends ConsumerState<FreeTypingScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final KeystrokeCaptureService _capture;

  @override
  void initState() {
    super.initState();
    _capture = KeystrokeCaptureService(
      onEvent: () => setState(() {}),
    )..startSession();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _capture.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _finish() {
    final count = _capture.events.length;
    _capture.stopSession();
    _controller.clear(); // text is never stored or sent
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session saved'),
        content: Text(
          '$count keystroke timings kept. Your text was discarded.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Free typing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.fiber_manual_record, size: 12),
                const SizedBox(width: 8),
                Text(
                  'Recording timing… ${_capture.events.length} keys',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: NotepadArea(
                controller: _controller,
                focusNode: _focusNode,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _finish,
              child: const Text('Finish (text is discarded)'),
            ),
          ],
        ),
      ),
    );
  }
}
