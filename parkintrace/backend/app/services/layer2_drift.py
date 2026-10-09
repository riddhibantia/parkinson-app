"""Personal drift detection: CUSUM + EWMA + Layer 2 combination (ported, validated).

Source: functions/services/layer2_drift.py.
Frozen-baseline monitoring: reads baseline statistics, returns new
results; never mutates the baseline or retrains models.
Thresholds (CUSUM 4.0/0.5, EWMA alpha 0.3, robust-z 2/3, 3-feature
attention rule) are experimental engineering values, not medical cutoffs.
Persistence rule (spec 12): attention needs 3+ drifting features OR an
anomaly run in 2 of last 3 — never one abnormal session alone.
"""

import numpy as np

from app.core.constants import (
    ATTENTION_MIN_FEATURES,
    CUSUM_SLACK,
    CUSUM_THRESHOLD,
    EWMA_ALPHA,
    EWMA_BAND,
    ROBUST_Z_WATCH,
    WATCH_MIN_FEATURES,
)
from app.services.layer2_anomaly import score_session_anomaly


def compute_ewma(values: list, alpha: float = EWMA_ALPHA) -> list:
    seq = list(values)
    if not seq:
        return []
    out = [float(seq[0])]
    for value in seq[1:]:
        out.append(alpha * float(value) + (1 - alpha) * out[-1])
    return out


def detect_drift(baseline: dict, recent_sessions: list,
                 feature_list: list, lookback_sessions: int = 10) -> dict:
    """Per-feature CUSUM drift + EWMA trend vs the FROZEN baseline."""
    recent = recent_sessions[-lookback_sessions:]
    stats = baseline["features"]
    drift_signals = {}

    for name in feature_list:
        entry = stats.get(name)
        if not entry:
            continue
        baseline_mean = entry.get("mean")
        baseline_std = entry.get("std")
        baseline_median = entry.get("median")
        baseline_mad = entry.get("mad")
        if baseline_mean is None or baseline_std is None:
            continue
        if baseline_std <= 1e-9:
            continue
        values = [s.get(name) for s in recent]
        values = [v for v in values if v is not None]
        if not values:
            continue

        z_values = [(v - baseline_mean) / baseline_std for v in values]
        robust_den = max(1.4826 * (baseline_mad or 0.0), 1e-6)
        robust_z = [(v - baseline_median) / robust_den for v in values]

        cusum_pos, cusum_neg = 0.0, 0.0
        drift_detected = False
        for z in z_values:
            cusum_pos = max(0.0, cusum_pos + z - CUSUM_SLACK)
            cusum_neg = max(0.0, cusum_neg - z - CUSUM_SLACK)
            if cusum_pos > CUSUM_THRESHOLD or cusum_neg > CUSUM_THRESHOLD:
                drift_detected = True

        ewma = compute_ewma(z_values)
        last = ewma[-1]
        trend = ("increasing" if last > EWMA_BAND else
                 "decreasing" if last < -EWMA_BAND else "stable")
        drift_signals[name] = {
            "drift_detected": drift_detected,
            "cusum_max": float(max(cusum_pos, cusum_neg)),
            "ewma_current": float(last),
            "trend": trend,
            "robust_z_current": float(robust_z[-1]),
            "unusual_range": bool(abs(robust_z[-1]) >= ROBUST_Z_WATCH),
        }

    drifting = [f for f, v in drift_signals.items() if v["drift_detected"]]
    if len(drifting) >= ATTENTION_MIN_FEATURES:
        status = "attention"
        message = ("Your typing rhythm has changed compared to your usual "
                   "pattern over recent sessions. This kind of change can "
                   "sometimes be linked to motor conditions. We recommend "
                   "consulting a doctor.")
    elif len(drifting) >= WATCH_MIN_FEATURES:
        status = "watch"
        message = ("We've noticed some changes in your typing patterns. "
                   "This could be due to many factors. Keep typing "
                   "regularly so we can track this more accurately.")
    else:
        status = "normal"
        message = ("Your typing patterns are consistent with your "
                   "personal baseline. Everything looks steady.")
    return {"status": status, "message": message,
            "drift_signals": drift_signals, "drifting_features": drifting}


def layer2_concern_score(drift_result: dict, anomaly_result: dict,
                         feature_list: list) -> float:
    """Layer 2's OWN signals only (CUSUM fraction + IF anomaly). Never Layer 1."""
    cusum_fraction = (len(drift_result.get("drifting_features", []))
                      / max(len(feature_list), 1))
    raw_score = anomaly_result.get("anomaly_score", 0.0)
    raw_score = 0.0 if raw_score is None else raw_score
    anomaly_component = 1.0 / (1.0 + np.exp(raw_score * 5))
    return float(0.5 * cusum_fraction + 0.5 * anomaly_component)


def dual_result(layer1_result: dict, layer2_result: dict,
                sessions_since_baseline: int,
                confidence_window: int = 5) -> dict:
    """Return BOTH results separately. No blending (spec 3.3)."""
    confidence = ("building" if sessions_since_baseline < confidence_window
                  else "established")
    return {
        "layer1": layer1_result,
        "layer2": {**layer2_result, "confidence": confidence},
        "primary_focus": ("layer2" if confidence == "established" else "layer1"),
    }


def score_monitoring_session(baseline: dict, anomaly_model,
                             current: dict, recent: list,
                             feature_list: list) -> dict:
    """Full Layer 2 scoring for one monitoring session (read-only)."""
    drift = detect_drift(baseline, recent, feature_list)
    if anomaly_model is None:
        anomaly = {"anomaly_score": None, "is_anomaly": False,
                   "reason": "model_pending"}
        anomaly_run = False
    else:
        anomaly = score_session_anomaly(anomaly_model, current, feature_list)
        window = recent[-3:]
        anomaly_run = sum(
            1 for s in window
            if score_session_anomaly(anomaly_model, s, feature_list).get(
                "is_anomaly")) >= 2

    if drift["status"] == "attention" or anomaly_run:
        status = "attention"
        message = ("Your typing rhythm has changed compared to your usual "
                   "pattern over recent sessions. This kind of change can "
                   "sometimes be linked to motor conditions. We recommend "
                   "consulting a doctor.") if drift["status"] == "attention" \
            else ("Several of your recent sessions look unusual compared "
                  "to your own usual pattern. We recommend consulting a "
                  "doctor.")
    else:
        status, message = drift["status"], drift["message"]

    return {
        "status": status,
        "message": message,
        "score": layer2_concern_score(drift, anomaly, feature_list),
        "drift_result": drift,
        "anomaly_result": anomaly,
        "anomaly_run": anomaly_run,
    }
