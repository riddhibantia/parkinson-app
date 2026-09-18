import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/typing_session.dart';
import '../../../data/services/keystroke_capture_service.dart';

/// Active-session state: owns one capture service per session,
/// buffers events locally, hands a finished TypingSession to the
/// upload path (Stage 2.5). Offline buffering lands with the
/// local storage service.
class TypingSessionState {
  final bool active;
  final String mode;
  final String sessionPhase;
  final int eventCount;
  final DateTime? startedAt;

  const TypingSessionState({
    this.active = false,
    this.mode = 'structured',
    this.sessionPhase = 'screening',
    this.eventCount = 0,
    this.startedAt,
  });
}

class TypingSessionNotifier extends StateNotifier<TypingSessionState> {
  KeystrokeCaptureService? _capture;

  TypingSessionNotifier() : super(const TypingSessionState());

  void start({required String mode, required String sessionPhase}) {
    _capture?.dispose();
    _capture = KeystrokeCaptureService(
      onEvent: () => state = TypingSessionState(
        active: true,
        mode: state.mode,
        sessionPhase: state.sessionPhase,
        eventCount: _capture?.events.length ?? 0,
        startedAt: state.startedAt,
      ),
    )..startSession();
    state = TypingSessionState(
      active: true,
      mode: mode,
      sessionPhase: sessionPhase,
      startedAt: DateTime.now(),
    );
  }

  TypingSession finish({
    required String sessionId,
    required String userId,
    required String deviceId,
  }) {
    final capture = _capture;
    final started = state.startedAt ?? DateTime.now();
    final mode = state.mode;
    final phase = state.sessionPhase;
    final now = DateTime.now();
    final events = capture?.events ?? const [];
    capture?.stopSession();
    _capture = null;
    state = const TypingSessionState();
    return TypingSession(
      sessionId: sessionId,
      userId: userId,
      startTime: started,
      endTime: now,
      mode: mode,
      sessionPhase: phase,
      events: List.of(events),
      totalKeystrokes: events.length,
      deviceId: deviceId,
    );
  }

  /// Flush-before-signout hook (Stage 1.5/2.5): push any buffered
  /// unsynced sessions before the session is cleared.
  Future<void> flushBeforeSignOut() async {}
}

final typingSessionProvider =
    StateNotifierProvider<TypingSessionNotifier, TypingSessionState>(
  (ref) => TypingSessionNotifier(),
);
