"""Shared constants for the feature pipeline (Stage 3.1 / 3.4).

Thresholds are engineering starting values, not medical cutoffs.
"""

# Typing features supported by live capture AND both training datasets
# (Tappy adapter + neuroQWERTY extraction must produce exactly these).
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

# Alternating-key motor-task features (Stage 2.3 / 3.2a).
# Never part of the Layer 1 training matrix.
MOTOR_TASK_FEATURE_LIST = [
    "valid_taps",
    "mean_iti_ms",
    "std_iti_ms",
    "miss_rate",
    "extra_tap_count",
    "slowing_slope_ms",
]

# Subject-level context only (Stage 3.4). Never dynamic Layer 2 inputs,
# never imputed for a dataset that does not provide them.
DEMOGRAPHIC_COVARIATES = [
    "age_at_session",
    "sex_gender",
]

# Core timing features for the familiarization readiness gate (Stage 2.2).
FAMILIARIZATION_CORE_FEATURES = [
    "ht_mean",
    "ht_std",
    "ft_mean",
    "ft_std",
    "ikl_mean",
    "ikl_std",
    "typing_speed",
    "pause_frequency",
    "hand_asymmetry",
]

# Session quality gates (Stage 2.6).
MIN_SESSION_SECONDS = 30
MIN_KEY_EVENTS = 50
UNUSUAL_HOUR_START = 0
UNUSUAL_HOUR_END = 5

# Baseline gates (Stage 5.1): count is a floor, not a target.
MINIMUM_SESSIONS_FOR_BASELINE = 10
MINIMUM_BASELINE_SPAN_DAYS = 5
BASELINE_WINDOW_DAYS = 21

# Layer 2 confidence window (Stage 5.5).
LAYER2_CONFIDENCE_WINDOW = 5

# Feature definitions (Stage 3.1 / 3.3).
PAUSE_THRESHOLD_MS = 500
HT_OUTLIER_MS = 2000
FT_OUTLIER_MS = 3000
IQR_FACTOR = 1.5

# Familiarization readiness gate (Stage 1.6 / 2.2).
FAMILIARIZATION_MAX_MEDIAN_APC = 0.15
