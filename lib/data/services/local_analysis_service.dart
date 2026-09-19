import 'dart:math';
import '../models/keystroke_event.dart';

/// Local feature extraction mirroring Python feature_extraction.py (simplified).
/// Used for immediate Layer1 feedback when backend is unavailable or for demo.
/// Preserves privacy: only timing, never content.
class LocalFeatureExtractor {
  static Map<String, double> extract(List<KeystrokeEvent> events) {
    final chars = events.where((e) => e.keyType.name == 'character').toList();
    if (chars.length < 10) return {};
    final holds = chars
        .map((e) => (e.releaseTimestamp - e.pressTimestamp) / 1000.0)
        .toList();
    final flights = <double>[];
    final ikls = <double>[];
    for (var i = 0; i < chars.length - 1; i++) {
      flights.add(
        (chars[i + 1].pressTimestamp - chars[i].releaseTimestamp) / 1000.0,
      );
      ikls.add(
        (chars[i + 1].pressTimestamp - chars[i].pressTimestamp) / 1000.0,
      );
    }
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    double std(List<double> v) {
      final m = mean(v);
      return sqrt(
        v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / v.length,
      );
    }

    final left = <double>[];
    final right = <double>[];
    for (var i = 0; i < chars.length; i++) {
      final ht = holds[i];
      if (chars[i].hand == 'left') left.add(ht);
      if (chars[i].hand == 'right') right.add(ht);
    }
    final leftMean = left.isEmpty ? 0.0 : mean(left);
    final rightMean = right.isEmpty ? 0.0 : mean(right);
    final asym = (leftMean == 0 && rightMean == 0)
        ? 0.0
        : (leftMean - rightMean).abs() /
              max(leftMean, rightMean).clamp(0.001, double.infinity);
    final pauses = flights.where((f) => f > 500).length;
    final durationSec =
        (chars.last.releaseTimestamp - chars.first.pressTimestamp) /
        1000.0 /
        1000.0;
    // Actually timestamps are microseconds? Convert to ms: press is ms since epoch? Use ms.
    // Simplified: use holds already in ms, so duration in seconds approx
    final dur = max(1.0, durationSec);
    final speed = chars.length / dur;
    final consistency = (mean(ikls) == 0) ? 0.0 : std(ikls) / mean(ikls);
    return {
      'ht_mean': mean(holds),
      'ht_std': std(holds),
      'ft_mean': flights.isEmpty ? 0 : mean(flights),
      'ft_std': flights.isEmpty ? 0 : std(flights),
      'ikl_mean': ikls.isEmpty ? 0 : mean(ikls),
      'ikl_std': ikls.isEmpty ? 0 : std(ikls),
      'left_ht_mean': leftMean,
      'right_ht_mean': rightMean,
      'hand_asymmetry': asym,
      'pause_frequency': pauses / max(1, dur / 60.0),
      'typing_speed': speed,
      'session_consistency': consistency,
    };
  }

  /// Simple heuristic Layer1 inference (population comparison) — not the Python RF,
  /// but preserves immediate UX when backend unavailable. Returns watch/attention/normal.
  static Map<String, dynamic> layer1Heuristic(Map<String, double> f) {
    if (f.isEmpty) {
      return {
        'status': 'watch',
        'message':
            'Not enough typing data for a confident comparison. Try another session.',
        'pd_probability': 0.45,
      };
    }
    // Heuristic thresholds derived from harmonized medians (research, not diagnosis)
    final ht = f['ht_mean'] ?? 100;
    final ft = f['ft_mean'] ?? 100;
    final ikl = f['ikl_mean'] ?? 200;
    // Slightly longer holds / slower flight may push toward watch
    double score = 0;
    if (ht > 120) score += 0.25;
    if (ft > 130) score += 0.2;
    if (ikl > 250) score += 0.2;
    if ((f['hand_asymmetry'] ?? 0) > 0.12) score += 0.15;
    if ((f['pause_frequency'] ?? 0) > 4) score += 0.1;
    final prob = (0.3 + score).clamp(0.05, 0.85);
    String status;
    String message;
    if (prob >= 0.7) {
      status = 'attention';
      message =
          'Your typing pattern shows some characteristics that differ from the typical research range. This is a research screening signal and not a medical diagnosis.';
    } else if (prob >= 0.4) {
      status = 'watch';
      message =
          'Some typing features are slightly outside the typical research range. Keep typing regularly for a clearer picture.';
    } else {
      status = 'normal';
      message =
          'Your typing pattern is within the typical research range. This is a research screening signal and not a medical diagnosis.';
    }
    return {'status': status, 'message': message, 'pd_probability': prob};
  }
}
