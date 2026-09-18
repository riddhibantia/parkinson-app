import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/analysis_mode_provider.dart';
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

  static const _layer1Passages = [
    'Regular typing allows us to observe timing differences between successive key presses while keeping the task simple and natural. Type the passage at your normal comfortable pace without deliberately changing your speed. Focus on accuracy and let the rhythm emerge naturally as you type.',
    'The morning light filled the quiet room as she prepared a simple breakfast of toast and tea. Outside, the street was calm and the air felt fresh after the night rain. Small daily routines like this can reveal consistent patterns in how we move and interact with familiar tools.',
    'A short walk through the park offers a chance to notice steady breathing and relaxed movement. People often find that regular, unhurried activity helps maintain balance and coordination throughout the day. Take a moment to type this description at an easy, even pace.',
  ];

  static const _layer2Passages = [
    'Typing on a familiar keyboard provides a window into everyday motor patterns that develop over time through repeated use. When you type at your usual pace, the timing between presses, the duration of each hold, and the rhythm across sentences create a personal signature. This passage gives us several lines of continuous typing to capture those subtle characteristics without rushing.',
    'Consistent daily practice helps establish a reliable personal baseline that reflects your typical interaction with the keyboard. As you complete sessions across different days and times, the system learns what is normal for you specifically. Please type this paragraph as you would any ordinary note, keeping your posture comfortable and your hands relaxed.',
    'Longer passages allow us to measure not only individual key timing but also how consistency and hand coordination evolve across a full paragraph. Notice the natural pauses between words and the steady return of fingers to home position. There is no need to correct every small mistake — just continue at your natural pace.',
  ];

  Future<void> _loadPrompt() async {
    // Layer-specific passages (4–5 lines). Fallback to legacy sentences if needed.
    final mode = ref.read(analysisModeProvider);
    final pool = mode == AnalysisMode.layer2
        ? _layer2Passages
        : _layer1Passages;
    // Also try legacy file for variety, but prefer paragraph passages for spec
    try {
      final raw = await rootBundle.loadString(
        'assets/prompts/neutral_sentences.json',
      );
      final sentences =
          (jsonDecode(raw) as Map<String, dynamic>)['sentences'] as List;
      // Occasionally use legacy sentence as paragraph seed if passages unavailable
      if (pool.isEmpty && sentences.isNotEmpty) {
        sentences.shuffle();
        setState(() => _prompt = (sentences.first as String));
        return;
      }
    } catch (_) {}
    final rng = pool.toList()..shuffle();
    setState(() => _prompt = rng.first);
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
    final typed = _controller.text;
    // progress based on correct prefix length, not raw length
    int correct = 0;
    for (var i = 0; i < typed.length && i < _prompt.length; i++) {
      if (typed[i] == _prompt[i]) {
        correct++;
      } else {
        break;
      }
    }
    return (correct / _prompt.length).clamp(0.0, 1.0);
  }

  /// Passage completion ignoring trailing spaces (spec 11).
  bool get _isPassageComplete {
    if (_prompt.isEmpty) return false;
    final typed = _controller.text;
    final normPrompt = _prompt.replaceAll(RegExp(r'\s+$'), '');
    final normTyped = typed.replaceAll(RegExp(r'\s+$'), '');
    return normTyped == normPrompt;
  }

  bool get _canDone {
    final count = _capture.events.length;
    // Must have passage complete (ignoring trailing spaces) + quality gate.
    // Done enables immediately after final required character (spec 11-12).
    return _isPassageComplete && count >= AppConstants.minKeyEvents;
  }

  bool _analyzing = false;

  Future<void> _finish() async {
    final count = _capture.events.length;
    if (!_canDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Keep typing — finish the passage to enable Done.'),
        ),
      );
      return;
    }
    setState(() => _analyzing = true);
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
    try {
      await ref.read(sessionRepositoryProvider).saveSession(session);
      ref.invalidate(localSessionsProvider);
      // Simulate feature extraction + backend analysis delay for UX
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final mode = ref.read(analysisModeProvider);
      if (isPractice) {
        context.go('/type/complete', extra: session);
      } else if (mode == AnalysisMode.layer1) {
        // Layer 1 analyzes immediately — go to dedicated result
        context.go('/insights/layer1');
      } else if (mode == AnalysisMode.layer2) {
        context.go('/insights/layer2');
      } else {
        context.go('/type/complete', extra: session);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save session: $e')));
      setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    final mode = ref.watch(analysisModeProvider);
    final modeBadge = mode == AnalysisMode.layer2
        ? 'LAYER 2 · PERSONAL MONITORING'
        : 'LAYER 1 · QUICK ANALYSIS';
    final instruction = mode == AnalysisMode.layer2
        ? 'Complete today\'s typing session to compare your typing pattern with your personal baseline.'
        : 'Complete this typing task to generate your population comparison.';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          mode == null
              ? 'Structured typing'
              : mode == AnalysisMode.layer1
              ? 'Quick Analysis'
              : 'Personal Monitoring',
        ),
      ),
      body: GradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      modeBadge,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    instruction,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TypingProgressBar(progress: _progress)),
                      const SizedBox(width: 12),
                      SessionTimer(seconds: seconds),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Centered paragraph — faded initially, bright as typed
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: TypingPrompt(
                      prompt: _prompt,
                      typed: _controller.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Hidden input — captures keystrokes, shows caret via prompt
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Type the passage above…',
                      border: const OutlineInputBorder(),
                      helperText:
                          'Recording timing… ${_capture.events.length} keys · $seconds s',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (!_isPassageComplete)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Keep typing — finish the passage to enable Done. Extra trailing spaces are ignored.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (_isPassageComplete && !_canDone)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Passage complete — need ${AppConstants.minKeyEvents} keys to save.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_analyzing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Analyzing your typing pattern...'),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _analyzing
                            ? null
                            : () {
                                _capture.stopSession();
                                context.go('/type');
                              },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _analyzing || !_canDone ? null : _finish,
                          child: Text(_analyzing ? 'Analyzing...' : 'Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
