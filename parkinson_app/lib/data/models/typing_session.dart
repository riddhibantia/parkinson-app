import 'keystroke_event.dart';

/// One complete typing sitting (Stage 2.5).
class TypingSession {
  final String sessionId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;

  /// "structured" | "free" | "motor_task"
  final String mode;

  /// "familiarization" | "screening"
  final String sessionPhase;

  final List<KeystrokeEvent> events;
  final int totalKeystrokes;

  /// Stable per-keyboard identifier driving the Stage 5 device check.
  final String deviceId;

  /// OS, session quality flags, etc.
  final Map<String, dynamic> metadata;

  const TypingSession({
    required this.sessionId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.mode,
    required this.sessionPhase,
    required this.events,
    required this.totalKeystrokes,
    required this.deviceId,
    this.metadata = const {},
  });

  bool get isFamiliarization => sessionPhase == 'familiarization';

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'mode': mode,
        'sessionPhase': sessionPhase,
        'events': events.map((e) => e.toJson()).toList(),
        'totalKeystrokes': totalKeystrokes,
        'deviceId': deviceId,
        'metadata': metadata,
      };

  factory TypingSession.fromJson(Map<String, dynamic> json) {
    return TypingSession(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      mode: json['mode'] as String,
      sessionPhase: json['sessionPhase'] as String,
      events: ((json['events'] as List?) ?? [])
          .map((e) => KeystrokeEvent.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalKeystrokes: (json['totalKeystrokes'] as num).toInt(),
      deviceId: json['deviceId'] as String,
      metadata: Map<String, dynamic>.from(
          (json['metadata'] as Map?) ?? const {}),
    );
  }
}
