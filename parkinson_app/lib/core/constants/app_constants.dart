/// Config values, API URLs, and Stage 1.6 / 5.x engineering constants.
/// Thresholds here are engineering starting values, not medical cutoffs.
class AppConstants {
  // Familiarization readiness gate (Stage 1.6 / 2.2).
  static const double familiarizationMaxMedianApc = 0.15;
  static const List<String> familiarizationCoreFeatures = [
    'ht_mean',
    'ht_std',
    'ft_mean',
    'ft_std',
    'ikl_mean',
    'ikl_std',
    'typing_speed',
    'pause_frequency',
    'hand_asymmetry',
  ];

  // Session quality filters (Stage 2.6).
  static const int minSessionSeconds = 30;
  static const int minKeyEvents = 50;
  static const double pauseThresholdMs = 500;

  // Alternating-key motor task duration (Stage 2.3: 10-15 s window).
  static const int motorTaskSeconds = 15;

  // Baseline gates (Stage 5.1).
  static const int minimumSessionsForBaseline = 10;
  static const int minimumBaselineSpanDays = 5;
  static const int baselineWindowDays = 21;

  // Layer 2 confidence window (Stage 5.5).
  static const int layer2ConfidenceWindow = 5;

  // Layer 1 probability bands — experimental placeholders (Stage 4.6).
  static const double layer1WatchThreshold = 0.4;
  static const double layer1AttentionThreshold = 0.7;

  // Cloud Functions names (Stage 6.1).
  static const String fnSubmitSession = 'submit_session';
  static const String fnGetDashboard = 'get_dashboard';
  static const String fnResetBaseline = 'reset_baseline';
}
