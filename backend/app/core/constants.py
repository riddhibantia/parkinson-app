"""Shared constants for the ParkinTrace pipeline (ported, validated).

Source: functions/utils/constants.py + functions/services/*.py.
Preserved exactly: feature lists, quality gates, baseline gates,
outlier thresholds, CUSUM/EWMA/IF config.

REMOVED per spec section 27.1 (no practice session):
- FAMILIARIZATION_CORE_FEATURES
- FAMILIARIZATION_MAX_MEDIAN_APC
- requiredPracticeSessions / familiarization_ready / sessionPhase gates
Typing experience remains onboarding context only; it never gates measurement.
"""

# Typing features supported by live capture AND both training datasets.
TYPING_FEATURE_LIST = [
    "ht_mean",
    "ht_std",
    "ft_mean",
    "ft_std",
    "ikl_mean",
    "ikl_std",
    "left_ht_mean",
    "right_ht_mean",
    "hand_asymmetry",
    "pause_frequency",
    "typing_speed",
    "session_consistency",
    "backspace_rate",
]

# Layer 1 RF training matrix: backspace_rate excluded — the research
# datasets carry no compatible backspace signal (spec 6.1). Verified
# against functions/models/experiments/rf/model_full.joblib features.
RF_LAYER1_FEATURES = [f for f in TYPING_FEATURE_LIST if f != "backspace_rate"]

# Alternating-key motor-task features. Never part of Layer 1.
MOTOR_TASK_FEATURE_LIST = [
    "valid_taps",
    "mean_iti_ms",
    "std_iti_ms",
    "miss_rate",
    "extra_tap_count",
    "slowing_slope_ms",
]

# Subject-level context only. Never a Layer 1/2 model input.
DEMOGRAPHIC_COVARIATES = [
    "age_at_session",
    "sex_gender",
]

# Session quality gates (validated).
MIN_SESSION_SECONDS = 30
MIN_KEY_EVENTS = 50
UNUSUAL_HOUR_START = 0
UNUSUAL_HOUR_END = 5

# Baseline gates (validated, spec 10.1).
MINIMUM_SESSIONS_FOR_BASELINE = 10
MINIMUM_BASELINE_SPAN_DAYS = 5
BASELINE_WINDOW_DAYS = 21

# Layer 2 confidence window (validated fixtures: building at 2, established at 9).
LAYER2_CONFIDENCE_WINDOW = 5

# Outlier filtering (validated, spec 6.3).
PAUSE_THRESHOLD_MS = 500
HT_OUTLIER_MS = 2000
FT_OUTLIER_MS = 3000
IQR_FACTOR = 1.5

# Layer 2 drift/anomaly config (validated, spec 11 — do not silently change).
CUSUM_THRESHOLD = 4.0
CUSUM_SLACK = 0.5
EWMA_ALPHA = 0.3
EWMA_BAND = 0.5
ROBUST_Z_WATCH = 2.0
ROBUST_Z_STRONG = 3.0
ATTENTION_MIN_FEATURES = 3
WATCH_MIN_FEATURES = 1
IF_N_ESTIMATORS = 100
IF_CONTAMINATION = 0.1
IF_RANDOM_STATE = 42

# Layer 1 bands are experimental placeholders, not medical cutoffs.
LAYER1_WATCH_THRESHOLD = 0.4
LAYER1_ATTENTION_THRESHOLD = 0.7
