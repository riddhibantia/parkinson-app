"""Keystroke -> features pipeline (Stage 3.2 / 3.2a / 3.3).

Runs server-side for consistency. Accepts events in the exact wire format
produced by the Flutter capture service (KeystrokeEvent.toJson):
    pressTimestamp, releaseTimestamp (microseconds, OS event time),
    hand ("left"/"right"), row, keyType ("character"/"backspace"/"control").

Only "character" events drive rhythm features. Backspace and control keys
are excluded entirely — including any FT/IKL transition touching them —
and backspace is instead counted as its own correction-rate signal
(Stage 2.1a), so correction bursts never distort FT/IKL.
"""

import numpy as np

from utils.constants import (
    FT_OUTLIER_MS,
    HT_OUTLIER_MS,
    IQR_FACTOR,
    MOTOR_TASK_FEATURE_LIST,
    PAUSE_THRESHOLD_MS,
    TYPING_FEATURE_LIST,
)


def compute_asymmetry(left_ht: list, right_ht: list):
    """abs(L-R)/max(L,R) per Stage 3.1. None when either side is missing."""
    if not left_ht or not right_ht:
        return None
    left_mean = float(np.mean(left_ht))
    right_mean = float(np.mean(right_ht))
    denom = max(left_mean, right_mean)
    if denom == 0:
        return None
    return abs(left_mean - right_mean) / denom


def _iqr_keep(values: np.ndarray) -> np.ndarray:
    """Boolean keep-mask via Q1-1.5*IQR .. Q3+1.5*IQR (Stage 3.3)."""
    if len(values) < 4:
        return np.ones(len(values), dtype=bool)
    q1, q3 = np.percentile(values, [25, 75])
    iqr = q3 - q1
    return (values >= q1 - IQR_FACTOR * iqr) & (values <= q3 + IQR_FACTOR * iqr)


def extract_features(events: list, session_duration_sec: float) -> dict:
    """Rhythm features from one session's events (Stage 3.2 + 3.3).

    Filtering order per plan: character-only selection first (backspace /
    control transitions already excluded before this step, not after),
    then hard-cutoff + IQR outlier removal, then statistics. (Event, hold)
    pairs travel together so the hand split always matches the surviving
    hold times exactly.

    Returns a dict with exactly TYPING_FEATURE_LIST keys (nullable where
    undefined) plus an "outlier_removal" metadata entry with removal
    counts for quality logging.
    """
    char_events = [e for e in events if e.get("keyType") == "character"]
    backspace_events = [e for e in events if e.get("keyType") == "backspace"]

    # Per-key arrays (paired by index with char_events).
    hold_times = np.array(
        [(e["releaseTimestamp"] - e["pressTimestamp"]) / 1000.0
         for e in char_events],
        dtype=float,
    )
    # Per-transition arrays (length n-1, aligned with each other).
    flight_times = np.array(
        [(char_events[i + 1]["pressTimestamp"]
          - char_events[i]["releaseTimestamp"]) / 1000.0
         for i in range(len(char_events) - 1)],
        dtype=float,
    )
    inter_key = np.array(
        [(char_events[i + 1]["pressTimestamp"]
          - char_events[i]["pressTimestamp"]) / 1000.0
         for i in range(len(char_events) - 1)],
        dtype=float,
    )

    removed = {"ht_hard_cutoff": 0, "ft_hard_cutoff": 0,
               "ht_iqr": 0, "transition_iqr": 0}

    # --- Stage 3.3, hard cutoffs ---
    ht_keep = np.ones(len(hold_times), dtype=bool)
    if len(hold_times):
        ht_keep = hold_times <= HT_OUTLIER_MS
        removed["ht_hard_cutoff"] = int(len(hold_times) - ht_keep.sum())

    tr_keep = np.ones(len(flight_times), dtype=bool)
    if len(flight_times):
        tr_keep = flight_times <= FT_OUTLIER_MS
        removed["ft_hard_cutoff"] = int(len(flight_times) - tr_keep.sum())

    # --- Stage 3.3, IQR per array; transitions dropped jointly ---
    if ht_keep.sum():
        ht_mask = _iqr_keep(hold_times[ht_keep])
        survivors = np.where(ht_keep)[0][ht_mask]
        full = np.zeros(len(hold_times), dtype=bool)
        full[survivors] = True
        removed["ht_iqr"] = int(ht_keep.sum() - ht_mask.sum())
        ht_keep = full

    if tr_keep.sum() >= 1:
        joint = _iqr_keep(flight_times[tr_keep]) & _iqr_keep(inter_key[tr_keep])
        survivors = np.where(tr_keep)[0][joint]
        full = np.zeros(len(flight_times), dtype=bool)
        full[survivors] = True
        removed["transition_iqr"] = int(tr_keep.sum() - joint.sum())
        tr_keep = full

    surviving_ht = hold_times[ht_keep]
    surviving_hands = [e.get("hand") for e, k in zip(char_events, ht_keep) if k]
    surviving_ft = flight_times[tr_keep]
    surviving_ikl = inter_key[tr_keep]

    left_ht = [h for h, hand in zip(surviving_ht, surviving_hands)
               if hand == "left"]
    right_ht = [h for h, hand in zip(surviving_ht, surviving_hands)
                if hand != "left"]

    duration_min = session_duration_sec / 60.0 if session_duration_sec else 0

    features = {k: None for k in TYPING_FEATURE_LIST}
    if len(surviving_ht):
        features["ht_mean"] = float(np.mean(surviving_ht))
        features["ht_std"] = float(np.std(surviving_ht))
    if len(surviving_ft):
        features["ft_mean"] = float(np.mean(surviving_ft))
        features["ft_std"] = float(np.std(surviving_ft))
    if len(surviving_ikl):
        ikl_mean = float(np.mean(surviving_ikl))
        features["ikl_mean"] = ikl_mean
        features["ikl_std"] = float(np.std(surviving_ikl))
        features["session_consistency"] = (
            float(np.std(surviving_ikl) / ikl_mean) if ikl_mean else None
        )
    if left_ht:
        features["left_ht_mean"] = float(np.mean(left_ht))
    if right_ht:
        features["right_ht_mean"] = float(np.mean(right_ht))
    features["hand_asymmetry"] = compute_asymmetry(left_ht, right_ht)
    if duration_min > 0 and session_duration_sec:
        pauses = sum(1 for ft in surviving_ft if ft > PAUSE_THRESHOLD_MS)
        features["pause_frequency"] = pauses / duration_min
        features["typing_speed"] = len(char_events) / session_duration_sec
        features["backspace_rate"] = len(backspace_events) / duration_min
    features["outlier_removal"] = removed
    return features


def extract_motor_task_features(taps: list, expected_keys=("F", "J")) -> dict:
    """Motor-task features for mode == "motor_task" (Stage 3.2a).

    Never mixed into sentence-typing HT/FT/IKL statistics. Each tap is
    {"timestamp_ms": int, "key": str}. Taps breaking the expected
    alternation are recorded as quality events rather than silently
    treated as slow taps.
    """
    features = {k: None for k in MOTOR_TASK_FEATURE_LIST}
    features["extra_tap_count"] = 0
    quality_events = []

    if not taps:
        features["quality_events"] = quality_events
        return features

    valid_ts = []
    last_valid_key = None
    for i, tap in enumerate(taps):
        key = tap.get("key")
        if key in expected_keys and key != last_valid_key:
            valid_ts.append(tap["timestamp_ms"])
            last_valid_key = key
        else:
            features["extra_tap_count"] += 1
            quality_events.append({"index": i, "reason": "unexpected_key"})

    features["valid_taps"] = len(valid_ts)
    features["miss_rate"] = features["extra_tap_count"] / len(taps)

    if len(valid_ts) >= 2:
        iti = np.diff(np.asarray(valid_ts, dtype=float))
        features["mean_iti_ms"] = float(np.mean(iti))
        features["std_iti_ms"] = float(np.std(iti))
        if len(iti) >= 3:
            # Within-task slowing: slope of ITI over tap index (ms/tap).
            x = np.arange(len(iti), dtype=float)
            features["slowing_slope_ms"] = float(np.polyfit(x, iti, 1)[0])

    features["quality_events"] = quality_events
    return features
