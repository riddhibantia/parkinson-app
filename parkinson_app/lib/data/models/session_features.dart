/// Extracted features for one session (Stage 3.1).
///
/// Mirror of the Python pipeline output (functions/services/
/// feature_extraction.py). Typing keys match TYPING_FEATURE_LIST exactly;
/// motor-task keys are null for non-motor-task sessions (Stage 3.2a) and
/// typing keys are produced only for typing sessions — the two groups are
/// never mixed.
class SessionFeatures {
  // Typing group (ms, counts/min, ratios).
  final double? htMean;
  final double? htStd;
  final double? ftMean;
  final double? ftStd;
  final double? iklMean;
  final double? iklStd;
  final double? leftHtMean;
  final double? rightHtMean;
  final double? handAsymmetry;
  final double? pauseFrequency;
  final double? typingSpeed;
  final double? sessionConsistency;
  final double? backspaceRate;

  // Motor-task group (Stage 3.2a) — null unless mode == "motor_task".
  final int? validTaps;
  final double? meanItiMs;
  final double? stdItiMs;
  final double? missRate;
  final int? extraTapCount;
  final double? slowingSlopeMs;

  const SessionFeatures({
    this.htMean,
    this.htStd,
    this.ftMean,
    this.ftStd,
    this.iklMean,
    this.iklStd,
    this.leftHtMean,
    this.rightHtMean,
    this.handAsymmetry,
    this.pauseFrequency,
    this.typingSpeed,
    this.sessionConsistency,
    this.backspaceRate,
    this.validTaps,
    this.meanItiMs,
    this.stdItiMs,
    this.missRate,
    this.extraTapCount,
    this.slowingSlopeMs,
  });

  /// Core timing features for the familiarization readiness gate
  /// (Stage 2.2) — same names as the backend FAMILIARIZATION_CORE_FEATURES.
  double? valueOf(String name) {
    switch (name) {
      case 'ht_mean':
        return htMean;
      case 'ht_std':
        return htStd;
      case 'ft_mean':
        return ftMean;
      case 'ft_std':
        return ftStd;
      case 'ikl_mean':
        return iklMean;
      case 'ikl_std':
        return iklStd;
      case 'typing_speed':
        return typingSpeed;
      case 'pause_frequency':
        return pauseFrequency;
      case 'hand_asymmetry':
        return handAsymmetry;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'ht_mean': htMean,
        'ht_std': htStd,
        'ft_mean': ftMean,
        'ft_std': ftStd,
        'ikl_mean': iklMean,
        'ikl_std': iklStd,
        'left_ht_mean': leftHtMean,
        'right_ht_mean': rightHtMean,
        'hand_asymmetry': handAsymmetry,
        'pause_frequency': pauseFrequency,
        'typing_speed': typingSpeed,
        'session_consistency': sessionConsistency,
        'backspace_rate': backspaceRate,
        'valid_taps': validTaps,
        'mean_iti_ms': meanItiMs,
        'std_iti_ms': stdItiMs,
        'miss_rate': missRate,
        'extra_tap_count': extraTapCount,
        'slowing_slope_ms': slowingSlopeMs,
      };

  factory SessionFeatures.fromJson(Map<String, dynamic> json) {
    return SessionFeatures(
      htMean: (json['ht_mean'] as num?)?.toDouble(),
      htStd: (json['ht_std'] as num?)?.toDouble(),
      ftMean: (json['ft_mean'] as num?)?.toDouble(),
      ftStd: (json['ft_std'] as num?)?.toDouble(),
      iklMean: (json['ikl_mean'] as num?)?.toDouble(),
      iklStd: (json['ikl_std'] as num?)?.toDouble(),
      leftHtMean: (json['left_ht_mean'] as num?)?.toDouble(),
      rightHtMean: (json['right_ht_mean'] as num?)?.toDouble(),
      handAsymmetry: (json['hand_asymmetry'] as num?)?.toDouble(),
      pauseFrequency: (json['pause_frequency'] as num?)?.toDouble(),
      typingSpeed: (json['typing_speed'] as num?)?.toDouble(),
      sessionConsistency: (json['session_consistency'] as num?)?.toDouble(),
      backspaceRate: (json['backspace_rate'] as num?)?.toDouble(),
      validTaps: (json['valid_taps'] as num?)?.toInt(),
      meanItiMs: (json['mean_iti_ms'] as num?)?.toDouble(),
      stdItiMs: (json['std_iti_ms'] as num?)?.toDouble(),
      missRate: (json['miss_rate'] as num?)?.toDouble(),
      extraTapCount: (json['extra_tap_count'] as num?)?.toInt(),
      slowingSlopeMs: (json['slowing_slope_ms'] as num?)?.toDouble(),
    );
  }
}
