"""Stage 3 pipeline tests (plan Stage 10.1: feature extraction + quality)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.feature_extraction import (
    compute_asymmetry,
    extract_features,
    extract_motor_task_features,
)
from services.quality_filter import (
    eligible_for_analysis,
    quality_flags,
    validate_session,
)
from utils.constants import (
    DEMOGRAPHIC_COVARIATES,
    MOTOR_TASK_FEATURE_LIST,
    TYPING_FEATURE_LIST,
)

US = 1000  # microseconds per millisecond


def char(press_ms, hold_ms, hand="left", row=1):
    return {
        "pressTimestamp": int(press_ms * US),
        "releaseTimestamp": int((press_ms + hold_ms) * US),
        "hand": hand,
        "row": row,
        "keyType": "character",
    }


def backspace(press_ms):
    return {
        "pressTimestamp": int(press_ms * US),
        "releaseTimestamp": int((press_ms + 80) * US),
        "hand": "right",
        "row": 0,
        "keyType": "backspace",
    }


def control(press_ms):
    return {
        "pressTimestamp": int(press_ms * US),
        "releaseTimestamp": int((press_ms + 50) * US),
        "hand": "left",
        "row": 0,
        "keyType": "control",
    }


def steady_session(n=5, ht=100, step=300):
    """n keys, identical holds, even rhythm, alternating hands."""
    events = []
    for i in range(n):
        events.append(char(i * step, ht,
                            hand="left" if i % 2 == 0 else "right"))
    return events


def test_known_values():
    events = steady_session()
    f = extract_features(events, session_duration_sec=60.0)
    assert f["ht_mean"] == 100.0
    assert f["ht_std"] == 0.0
    assert f["ft_mean"] == 200.0
    assert f["ft_std"] == 0.0
    assert f["ikl_mean"] == 300.0
    assert f["session_consistency"] == 0.0
    assert f["left_ht_mean"] == 100.0
    assert f["right_ht_mean"] == 100.0
    assert f["hand_asymmetry"] == 0.0
    assert f["pause_frequency"] == 0.0
    assert abs(f["typing_speed"] - 5 / 60.0) < 1e-9
    assert f["backspace_rate"] == 0.0


def test_feature_key_contract():
    f = extract_features(steady_session(), 60.0)
    for key in TYPING_FEATURE_LIST:
        assert key in f, f"missing typing feature: {key}"
    assert "outlier_removal" in f


def test_backspace_excluded_from_rhythm_but_counted():
    base = extract_features(steady_session(), 60.0)
    events = steady_session() + [backspace(2000), backspace(2500),
                                 backspace(2600)]
    f = extract_features(events, 60.0)
    for key in ("ht_mean", "ft_mean", "ikl_mean", "typing_speed"):
        assert f[key] == base[key]
    assert f["backspace_rate"] == 3.0  # 3 corrections in 1 minute


def test_control_events_and_transitions_excluded():
    base = extract_features(steady_session(), 60.0)
    events = steady_session()
    events.insert(2, control(650))  # between key 1 and key 2
    f = extract_features(events, 60.0)
    for key in ("ht_mean", "ft_mean", "ikl_mean"):
        assert f[key] == base[key]


def test_outlier_removal_counts_and_effect():
    # Keys 0-2 steady, key 3 stuck (5 s hold), keys 4-5 resume normally,
    # then a 9 s distraction gap before keys 6-7.
    events = [
        char(0, 100, hand="left"),
        char(300, 100, hand="right"),
        char(600, 100, hand="left"),
        char(900, 5000, hand="right"),  # stuck key -> HT hard cutoff
        char(6100, 100, hand="left"),
        char(6400, 100, hand="right"),
        char(15500, 100, hand="left"),  # 9000 ms gap -> FT hard cutoff
        char(15800, 100, hand="right"),
    ]
    f = extract_features(events, 120.0)
    assert f["outlier_removal"]["ht_hard_cutoff"] >= 1
    assert f["outlier_removal"]["ft_hard_cutoff"] >= 1
    assert f["ht_mean"] == 100.0  # stuck key did not survive
    assert f["ft_mean"] == 200.0  # distraction gap did not survive


def test_empty_and_single_event_edges():
    f = extract_features([], 60.0)
    assert f["ht_mean"] is None and f["ft_mean"] is None
    assert f["ikl_mean"] is None and f["hand_asymmetry"] is None

    f = extract_features([char(0, 120, hand="left")], 60.0)
    assert f["ht_mean"] == 120.0
    assert f["ft_mean"] is None  # no transitions exist
    assert f["left_ht_mean"] == 120.0
    assert f["right_ht_mean"] is None  # one-sided session
    assert f["hand_asymmetry"] is None


def test_asymmetry_definition():
    assert compute_asymmetry([100, 100], [200, 200]) == 0.5
    assert compute_asymmetry([], [100]) is None
    assert compute_asymmetry([100], []) is None


def test_pause_frequency_per_minute():
    events = steady_session(n=4)
    # Insert a 900 ms hesitation between key 1 and key 2.
    events[2] = char(300 + 900, 100, hand="left")
    events[3] = char(600 + 900, 100, hand="right")
    f = extract_features(events, 60.0)
    assert f["pause_frequency"] == 1.0


def test_motor_task_perfect_run():
    taps = [{"timestamp_ms": i * 150, "key": "F" if i % 2 == 0 else "J"}
            for i in range(10)]
    f = extract_motor_task_features(taps)
    assert f["valid_taps"] == 10
    assert f["miss_rate"] == 0.0
    assert f["mean_iti_ms"] == 150.0
    assert f["extra_tap_count"] == 0
    assert abs(f["slowing_slope_ms"]) < 1e-9
    assert f["quality_events"] == []


def test_motor_task_errors_are_quality_events_not_slow_taps():
    taps = [{"timestamp_ms": i * 150, "key": "F" if i % 2 == 0 else "J"}
            for i in range(8)]
    taps.insert(3, {"timestamp_ms": 460, "key": "F"})  # breaks alternation
    f = extract_motor_task_features(taps)
    assert f["extra_tap_count"] == 1
    assert len(f["quality_events"]) == 1
    assert f["miss_rate"] == 1 / 9
    # Valid-tap rhythm only: the error tap is excluded while the true
    # 150 ms rhythm of the surrounding valid taps is untouched.
    assert f["valid_taps"] == 8
    assert f["mean_iti_ms"] == 150.0


def test_motor_task_slowing_slope_sign():
    taps = []
    t = 0
    for i in range(8):
        taps.append({"timestamp_ms": t, "key": "F" if i % 2 == 0 else "J"})
        t += 150 + i * 20  # steadily slowing
    f = extract_motor_task_features(taps)
    assert f["slowing_slope_ms"] > 0


def test_motor_task_empty():
    f = extract_motor_task_features([])
    assert f["valid_taps"] is None
    for key in MOTOR_TASK_FEATURE_LIST:
        assert key in f


def test_quality_filter_gates():
    assert validate_session(50, 30.0) == (True, "ok")
    assert validate_session(49, 60.0)[0] is False
    assert validate_session(100, 29.9) == (False, "too_short")
    assert "unusual_hour" in quality_flags(60, 60.0, hour_of_day=3)
    assert "unusual_hour" not in quality_flags(60, 60.0, hour_of_day=14)


def test_familiarization_never_eligible():
    assert eligible_for_analysis("familiarization", []) is False
    assert eligible_for_analysis("screening", []) is True
    assert eligible_for_analysis("screening", ["too_short"]) is False


def test_demographics_kept_out_of_typing_features():
    for covariate in DEMOGRAPHIC_COVARIATES:
        assert covariate not in TYPING_FEATURE_LIST
