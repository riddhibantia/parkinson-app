import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/keystroke_capture_service.dart';

/// Structured typing test (Stage 2.3): neutral prompt + focused text field
/// + session-scoped capture. Minimum 30 s active typing, ~50+ key events
/// (quality gates in SessionQuality).
class StructuredTypingScreen extends ConsumerStatefulWidget {
  const StructuredTypingScreen({super.key});

  @override
  ConsumerState<StructuredTypingScreen> createState() =>
      _StructuredTypingScreenState();
}

class _StructuredTypingScreenState extends ConsumerState<StructuredTypingScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final KeystrokeCaptureService _capture;
  String _prompt = 'Loading prompt…';
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _capture = KeystrokeCaptureService(
      onEvent: () {
        _startedAt ??= DateTime.now();
        setState(() {});
      },
    )..startSession();
    _loadPrompt();
    _focusNode.requestFocus();
  }

  Future<void> _loadPrompt() async {
    final raw = await rootBundle
        .loadString('assets/prompts/neutral_sentences.json');
    final sentences =
        (jsonDecode(raw) as Map<String, dynamic>)['sentences'] as List;
    sentences.shuffle();
    setState(() => _prompt = (sentences.first as String));
  }

  @override
  void dispose() {
    _capture.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double get _progress {
    if (_prompt.isEmpty) return 0;
    final typed = _controller.text.length;
    return (typed / _prompt.length).clamp(0.0, 1.0);
  }

  void _finish() {
    final count = _capture.events.length;
    final seconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    _capture.stopSession();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Great session!'),
        content: Text(
          '$count keystrokes captured in ${seconds}s. '
          'Your data is being analyzed…',
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
      appBar: AppBar(title: const Text('Structured typing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text(_prompt, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Type the sentence above…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recording timing… ${_capture.events.length} keys',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finish,
                child: const Text('Finish session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
