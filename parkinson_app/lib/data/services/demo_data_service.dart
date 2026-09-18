import 'dart:math';
import '../../data/models/typing_session.dart';
import '../../data/models/keystroke_event.dart';

/// Demo data — synthetic but realistic, labeled DEMO, never mixed with real.
/// Covers: sessions across days, baseline 6/10, layer1/layer2 results, motor.
class DemoDataService {
  static const demoUid = 'demo-user';

  static List<TypingSession> demoSessions() {
    final now = DateTime.now();
    final rng = Random(42);
    List<TypingSession> out = [];
    // 8 screening sessions across 6 days (6/10 baseline) + 2 practice
    for (var i = 0; i < 2; i++) {
      out.add(TypingSession(
        sessionId: 'demo-p-$i',
        userId: demoUid,
        startTime: now.subtract(Duration(days: 7, hours: i)),
        endTime: now.subtract(Duration(days: 7, hours: i)).add(const Duration(seconds: 55)),
        mode: 'structured',
        sessionPhase: 'familiarization',
        events: _events(70, rng),
        totalKeystrokes: 70,
        deviceId: 'demo-keyboard',
        metadata: const {'demo': true},
      ));
    }
    for (var i = 0; i < 8; i++) {
      final dayOffset = [6, 5, 4, 3, 2, 1, 1, 0][i];
      final start = now.subtract(Duration(days: dayOffset, hours: rng.nextInt(6)));
      out.add(TypingSession(
        sessionId: 'demo-s-$i',
        userId: demoUid,
        startTime: start,
        endTime: start.add(Duration(seconds: 50 + rng.nextInt(20))),
        mode: 'structured',
        sessionPhase: 'screening',
        events: _events(75 + rng.nextInt(30), rng),
        totalKeystrokes: 75 + rng.nextInt(30),
        deviceId: 'demo-keyboard',
        metadata: const {'demo': true},
      ));
    }
    // 3 motor sessions
    for (var i = 0; i < 3; i++) {
      final start = now.subtract(Duration(days: 2 - i));
      out.add(TypingSession(
        sessionId: 'demo-m-$i',
        userId: demoUid,
        startTime: start,
        endTime: start.add(const Duration(seconds: 15)),
        mode: 'motor_task',
        sessionPhase: 'screening',
        events: _events(40, rng),
        totalKeystrokes: 40,
        deviceId: 'demo-keyboard',
        metadata: const {'demo': true, 'valid_taps': 38},
      ));
    }
    return out;
  }

  static List<KeystrokeEvent> _events(int n, Random rng) {
    int t = DateTime.now().millisecondsSinceEpoch;
    return List.generate(n, (i) {
      final press = t + i * (180 + rng.nextInt(80));
      final release = press + (95 + rng.nextInt(35));
      t = release + (40 + rng.nextInt(40));
      return KeystrokeEvent(
        pressTimestamp: press,
        releaseTimestamp: release,
        hand: rng.nextBool() ? 'left' : 'right',
        row: rng.nextInt(3),
        keyType: KeyType.character,
      );
    });
  }

  static Map<String, dynamic> demoLayer1Result() => {
        'status': 'watch',
        'message':
            'Some typing features are slightly outside the typical range. Keep typing regularly.',
        'pd_probability': 0.52,
        'top_contributors': [
          {'feature': 'ht_mean', 'text': 'Your key presses held slightly longer than typical this session.'},
          {'feature': 'pause_frequency', 'text': 'Your typing included more pauses than typical this session.'},
        ],
      };

  static Map<String, dynamic> demoLayer2Result() => {
        'status': 'watch',
        'message':
            'Some recent sessions differ from your usual pattern. More sessions will clarify if this is a sustained change.',
        'score': 0.38,
        'confidence': 'building',
        'drift_result': {
          'status': 'watch',
          'drifting_features': ['ht_mean'],
          'drift_signals': {
            'ht_mean': {'drift_detected': true, 'robust_z_current': 2.1, 'trend': 'increasing', 'unusual_range': true},
            'ft_mean': {'drift_detected': false, 'robust_z_current': 0.8, 'trend': 'stable', 'unusual_range': false},
            'typing_speed': {'drift_detected': false, 'robust_z_current': -0.5, 'trend': 'stable', 'unusual_range': false},
            'pause_frequency': {'drift_detected': false, 'robust_z_current': 1.2, 'trend': 'stable', 'unusual_range': false},
          }
        },
        'anomaly_result': {'anomaly_score': 0.12, 'is_anomaly': false},
      };

  static Map<String, dynamic> demoBaseline() => {
        'built_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'features': {
          'ht_mean': {'median': 108.0, 'mad': 12.0, 'mean': 110.0, 'std': 14.0},
          'ft_mean': {'median': 85.0, 'mad': 10.0, 'mean': 88.0, 'std': 11.0},
          'typing_speed': {'median': 4.2, 'mad': 0.4, 'mean': 4.1, 'std': 0.5},
        },
      };
}
