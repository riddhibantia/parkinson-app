import '../../data/models/keystroke_event.dart';
import '../../data/models/typing_session.dart';
import '../constants/app_constants.dart';

/// Session quality filters (Stage 2.6).
/// Familiarization sessions are never eligible for Layer 1/Layer 2 —
/// callers must filter them out before any screening/baseline work.
class SessionQuality {
  static List<String> check({
    required List<KeystrokeEvent> events,
    required Duration activeDuration,
  }) {
    final flags = <String>[];
    if (activeDuration.inSeconds < AppConstants.minSessionSeconds) {
      flags.add('too_short');
    }
    if (events.length < AppConstants.minKeyEvents) {
      flags.add('too_few_keystrokes');
    }
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 5) flags.add('unusual_hour');
    return flags;
  }

  static bool passesQuality(List<String> flags) =>
      !flags.contains('too_short') && !flags.contains('too_few_keystrokes');

  /// Hard gate shared by all analysis entry points.
  static bool eligibleForAnalysis(TypingSession session, List<String> flags) {
    if (session.isFamiliarization) return false;
    return passesQuality(flags);
  }
}
