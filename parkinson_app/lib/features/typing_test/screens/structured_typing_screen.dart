import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/typing_session.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../typing_test/providers/familiarization_provider.dart';
import '../../../data/services/keystroke_capture_service.dart';
import '../widgets/typing_progress_and_timer.dart';
import '../widgets/typing_prompt.dart';

/// Structured typing test (Stage 2.3): neutral prompt + focused text field
/// + session-scoped capture. Minimum 30 s active typing, ~50+ key events
/// (quality gates in SessionQuality).
class StructuredTypingScreen extends ConsumerStatefulWidget {
  const StructuredTypingScreen({super.key});

  @override
  ConsumerState<StructuredTypingScreen> createState() =>
      _StructuredTypingScreenState();
}

class _StructuredTypingScreenState
    extends ConsumerState<StructuredTypingScreen> {
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
    final raw = await rootBundle.loadString(
      'assets/prompts/neutral_sentences.json',
    );
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

  bool get _canDone {
    final count = _capture.events.length;
    final seconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    return count >= AppConstants.minKeyEvents &&
        seconds >= AppConstants.minSessionSeconds;
  }

  Future<void> _finish() async {
    final count = _capture.events.length;
    final seconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    if (!_canDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Keep typing — need ${AppConstants.minKeyEvents} keys and ${AppConstants.minSessionSeconds}s (you have $count / ${seconds}s).',
          ),
        ),
      );
      return;
    }
    _capture.stopSession();
    final isPractice = !ref.read(familiarizationProvider).screeningReady;
    final session = TypingSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'local',
      startTime: _startedAt ?? DateTime.now(),
      endTime: DateTime.now(),
      mode: 'structured',
      sessionPhase: isPractice ? 'familiarization' : 'screening',
      events: List.from(_capture.events),
      totalKeystrokes: count,
      deviceId: 'default-keyboard',
      metadata: const {},
    );
    await ref.read(sessionRepositoryProvider).saveSession(session);
    ref.invalidate(localSessionsProvider);
    if (!mounted) return;
    context.go('/type/complete', extra: session);
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    return Scaffold(
      appBar: AppBar(title: const Text('Structured typing')),
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: TypingProgressBar(progress: _progress)),
                  const SizedBox(width: 12),
                  SessionTimer(seconds: seconds),
                ],
              ),
              const SizedBox(height: 12),
              TypingPrompt(prompt: _prompt, typed: _controller.text),
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
                'Recording timing… ${_capture.events.length} keys'
                ' · $seconds s',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!_canDone)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Keep typing — need ${AppConstants.minKeyEvents} keys and ${AppConstants.minSessionSeconds}s to finish.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _capture.stopSession();
                      context.go('/type');
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canDone ? _finish : null,
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
