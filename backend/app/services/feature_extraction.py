"""Keystroke -> features (ported, validated math — unit-explicit).

Source: functions/services/feature_extraction.py.
Validated methodology preserved: character-only selection, hard-cutoff +
IQR outlier removal, paired (event, hold) filtering, hand split on
survivors, backspace counted separately (never in FT/IKL).

UNIT CHANGE (spec 7.2, explicit — not silent): the legacy Flutter wire
used MICROSECONDS (pressTimestamp/releaseTimestamp) so the extractor
divided by 1000. The new canonical contract uses MILLISECONDS
throughout (performance.now basis). `extract_features` below takes
MILLISECONDS. `extract_features_from_legacy_us` adapts old exports
with one explicit /1000 conversion at the boundary.
"""

import numpy as np

from app.core.constants import (
    FT_OUTLIER_MS,
    HT_OUTLIER_MS,
    IQR_FACTOR,
    MOTOR_TASK_FEATURE_LIST,
    PAUSE_THRESHOLD_MS,
    TYPING_FEATURE_LIST,
)


def compute_asymmetry(left_ht: list, right_ht: list):
    """abs(L-R)/max(L,R). None when either side is missing."""
    if not left_ht or not right_ht:
        return None
    left_mean = float(np.mean(left_ht))
    right_mean = float(np.mean(right_ht))
    denom = max(left_mean, right_mean)
    if denom == 0:
        return None
    return abs(left_mean - right_mean) / denom


def _iqr_keep(values: np.ndarray) -> np.ndarray:
    """Boolean keep-mask via Q1-1.5*IQR .. Q3+1.5*IQR."""
    if len(values) < 4:
        return np.ones(len(values), dtype=bool)
    q1, q3 = np.percentile(values, [25, 75])
    iqr = q3 - q1
    return (values >= q1 - IQR_FACTOR * iqr) & (values <= q3 + IQR_FACTOR * iqr)


def _get(event: dict, *names, default=None):
    for name in names:
        if name in event:
            return event[name]
    return default


def extract_features(events_ms: list, session_duration_sec: float) -> dict:
    """Rhythm features from one session. Timestamps in MILLISECONDS.

    Accepts both canonical camelCase (pressTimestamp/releaseTimestamp/
    keyType) and snake_case (press_timestamp/...) keys.
    Returns exactly TYPING_FEATURE_LIST keys (nullable where undefined)
    plus an "outlier_removal" metadata entry.
    """
    char_events = [e for e in events_ms if _get(e, "keyType", "key_type") == "character"]
    backspace_events = [e for e in events_ms if _get(e, "keyType", "key_type") == "backspace"]

    hold_times = np.array(
        [(_get(e, "releaseTimestamp", "release_timestamp") - _get(e, "pressTimestamp", "press_timestamp"))
         for e in char_events],
        dtype=float,
    )
    flight_times = np.array(
        [(_get(char_events[i + 1], "pressTimestamp", "press_timestamp")
          - _get(char_events[i], "releaseTimestamp", "release_timestamp"))
         for i in range(len(char_events) - 1)],
        dtype=float,
    )
    inter_key = np.array(
        [(_get(char_events[i + 1], "pressTimestamp", "press_timestamp")
          - _get(char_events[i], "pressTimestamp", "press_timestamp"))
         for i in range(len(char_events) - 1)],
        dtype=float,
    )

    removed = {"ht_hard_cutoff": 0, "ft_hard_cutoff": 0, "ht_iqr": 0, "transition_iqr": 0}

    ht_keep = np.ones(len(hold_times), dtype=bool)
    if len(hold_times):
        ht_keep = hold_times <= HT_OUTLIER_MS
        removed["ht_hard_cutoff"] = int(len(hold_times) - ht_keep.sum())

    tr_keep = np.ones(len(flight_times), dtype=bool)
    if len(flight_times):
        tr_keep = flight_times <= FT_OUTLIER_MS
        removed["ft_hard_cutoff"] = int(len(flight_times) - tr_keep.sum())

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
    surviving_hands = [(_get(e, "hand")) for e, k in zip(char_events, ht_keep) if k]
    surviving_ft = flight_times[tr_keep]
    surviving_ikl = inter_key[tr_keep]

    left_ht = [h for h, hand in zip(surviving_ht, surviving_hands) if hand == "left"]
    right_ht = [h for h, hand in zip(surviving_ht, surviving_hands) if hand != "left"]

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


def extract_features_from_legacy_us(events_us: list, session_duration_sec: float) -> dict:
    """Adapter for legacy Flutter exports (microsecond wire format).

    Single explicit µs->ms conversion at the boundary; the validated
    millisecond math downstream is untouched.
    """
    converted = []
    for e in events_us:
        row = dict(e)
        for camel, snake in (("pressTimestamp", "press_timestamp"),
                             ("releaseTimestamp", "release_timestamp")):
            if camel in row and isinstance(row[camel], (int, float)):
                row[camel] = float(row[camel]) / 1000.0
            if snake in row and isinstance(row[snake], (int, float)):
                row[snake] = float(row[snake]) / 1000.0
        converted.append(row)
    return extract_features(converted, session_duration_sec)


def extract_motor_task_features(taps: list, expected_keys=("F", "J")) -> dict:
    """Motor-task features (validated, unchanged). Taps: timestamp_ms + key."""
    features = {k: None for k in MOTOR_TASK_FEATURE_LIST}
    features["extra_tap_count"] = 0
    quality_events = []

    if not taps:
        features["quality_events"] = quality_events
        return features

    def tap_key(t):
        return t.get("key", t.get("keyLabel", t.get("label")))

    def tap_ts(t):
        return t.get("timestamp_ms", t.get("timestampMs"))

    valid_ts = []
    last_valid_key = None
    for i, tap in enumerate(taps):
        key = tap_key(tap)
        if key in expected_keys and key != last_valid_key:
            valid_ts.append(float(tap_ts(tap)))
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
            x = np.arange(len(iti), dtype=float)
            features["slowing_slope_ms"] = float(np.polyfit(x, iti, 1)[0])

    features["quality_events"] = quality_events
    return features


def within_session_series(events_ms: list, window: int = 10) -> dict:
    """Real within-session rolling series for charts (spec 26.1).

    Returns elapsed_ms/rolling_ht_ms/rolling_ft_ms/rolling_ikl_ms lists
    built from actual events. Empty lists when insufficient data —
    callers show 'Insufficient data', never synthetic fallback.
    """
    chars = [e for e in events_ms if _get(e, "keyType", "key_type") == "character"]
    if len(chars) < window + 1:
        return {"elapsed_ms": [], "rolling_ht_ms": [],
                "rolling_ft_ms": [], "rolling_ikl_ms": []}
    t0 = float(_get(chars[0], "pressTimestamp", "press_timestamp"))
    holds, fts, ikls, elapsed = [], [], [], []
    for i, e in enumerate(chars):
        holds.append(float(_get(e, "releaseTimestamp", "release_timestamp"))
                     - float(_get(e, "pressTimestamp", "press_timestamp")))
        elapsed.append(float(_get(e, "pressTimestamp", "press_timestamp")) - t0)
        if i > 0:
            fts.append(float(_get(e, "pressTimestamp", "press_timestamp"))
                       - float(_get(chars[i - 1], "releaseTimestamp", "release_timestamp")))
            ikls.append(float(_get(e, "pressTimestamp", "press_timestamp"))
                        - float(_get(chars[i - 1], "pressTimestamp", "press_timestamp")))

    def rolling(values):
        return [float(np.mean(values[max(0, i - window + 1): i + 1]))
                for i in range(len(values))]

    return {"elapsed_ms": elapsed, "rolling_ht_ms": rolling(holds),
            "rolling_ft_ms": rolling(fts), "rolling_ikl_ms": rolling(ikls)}
