"""Layer 2 contract tests (Stage 5.8). Controlled fixtures only.

Covers: 10-session floor, 5-day span, 21-day window, familiarization and
poor-quality exclusion, device gating, baseline freeze, no-retraining
proof, single-vs-sustained anomaly persistence, multi-feature drift,
Layer 1/2 separation, and demographic/symptom exclusion from the
feature vector. No Chronos anywhere in this file.
"""

import copy
import io
import sys
from datetime import datetime, timedelta
from pathlib import Path

import joblib
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.baseline_builder import (  # noqa: E402
    LAYER2_TYPING_FEATURES,
    build_baseline,
    eligible_sessions,
)
from services.device_guard import (  # noqa: E402
    check_device_consistency,
)
from services.layer2_anomaly import (  # noqa: E402
    fit_personal_anomaly_model,
    score_session_anomaly,
)
from services.layer2_drift import (  # noqa: E402
    compute_ewma,
    detect_drift,
    dual_result,
    layer2_concern_score,
    score_monitoring_session,
)
from utils.constants import MOTOR_TASK_FEATURE_LIST  # noqa: E402

DAY0 = datetime(2026, 1, 1)


def typing_session(day, ht=100.0, ft=200.0, ikl=300.0, device="kbd-a",
                   phase="screening", flags=None, seed=0, pauses=1.0):
    rng = np.random.RandomState(1000 + seed)
    tight = lambda base: round(float(base + rng.normal(0, base * 0.02)), 3)
    loose = lambda base: round(float(base + rng.normal(0, base * 0.08)), 3)
    return {
        "timestamp": DAY0 + timedelta(days=day),
        "device_id": device,
        "session_phase": phase,
        "quality_flags": flags or [],
        "mode": "typing",
        "ht_mean": tight(ht), "ht_std": 10.0,
        "ft_mean": tight(ft), "ft_std": 20.0,
        "ikl_mean": tight(ikl), "ikl_std": 25.0,
        "left_ht_mean": tight(ht), "right_ht_mean": tight(ht),
        "hand_asymmetry": loose(0.02),
        "pause_frequency": loose(pauses),
        "typing_speed": loose(2.5),
        "session_consistency": loose(0.1),
        "backspace_rate": loose(2.0),
    }


def baseline_fixture(n=12, days=6, **kwargs):
    return [typing_session(day=(i * days) // n, seed=i, **kwargs)
            for i in range(n)]


def build_frozen(n=12, days=6, **kwargs):
    sessions = baseline_fixture(n=n, days=days, **kwargs)
    baseline, used = build_baseline(sessions)
    assert baseline is not None
    model = fit_personal_anomaly_model(used, LAYER2_TYPING_FEATURES)
    return baseline, model, used


def test_baseline_needs_ten_valid_sessions():
    baseline, used = build_baseline(baseline_fixture(n=9, days=6))
    assert baseline is None and used == []


def test_baseline_needs_five_distinct_days():
    sessions = [typing_session(day=i // 3, seed=i) for i in range(12)]
    assert len({s["timestamp"].date() for s in sessions}) == 4
    baseline, _ = build_baseline(sessions)
    assert baseline is None


def test_baseline_enforces_21_day_window():
    sessions = baseline_fixture(n=10, days=10)
    sessions += [typing_session(day=40 + i, seed=99 + i) for i in range(5)]
    baseline, used = build_baseline(sessions)
    assert baseline is not None
    assert len(used) == 10
    assert baseline["window_end"] < DAY0 + timedelta(days=21)


def test_familiarization_sessions_cannot_enter_baseline():
    practice = [typing_session(day=i // 2, seed=i,
                               phase="familiarization") for i in range(10)]
    screening = [typing_session(day=10 + i, seed=50 + i) for i in range(3)]
    assert eligible_sessions(practice + screening) == screening
    baseline, _ = build_baseline(practice + screening)
    assert baseline is None  # only 3 eligible sessions


def test_poor_quality_sessions_cannot_enter_baseline():
    sessions = baseline_fixture(n=12, days=6)
    for s in sessions[:4]:
        s["quality_flags"] = ["too_short"]
    baseline, used = build_baseline(sessions)
    assert baseline is None  # only 8 eligible
    for s in sessions[:4]:
        s["quality_flags"] = ["unusual_hour"]  # hint only, not blocking
    baseline, used = build_baseline(sessions)
    assert baseline is not None and len(used) == 12


def test_wrong_device_sessions_rejected_from_scoring():
    baseline, _, _ = build_frozen()
    result = check_device_consistency({"device_id": "other-kbd"}, baseline)
    assert result["proceed"] is False
    assert result["status"] == "device_mismatch"
    assert check_device_consistency({"device_id": "kbd-a"},
                                    baseline) == {"proceed": True}


def test_baseline_unchanged_after_scoring():
    baseline, model, used = build_frozen()
    snapshot = copy.deepcopy(baseline)
    recent = used[-5:] + [typing_session(day=30, ht=160.0, seed=999)]
    drift = detect_drift(baseline, recent, LAYER2_TYPING_FEATURES)
    score_session_anomaly(model, recent[-1], LAYER2_TYPING_FEATURES)
    layer2_concern_score(
        drift,
        score_session_anomaly(model, recent[-1], LAYER2_TYPING_FEATURES),
        LAYER2_TYPING_FEATURES)
    assert baseline == snapshot


def test_isolation_forest_not_retrained_by_scoring():
    _, model, used = build_frozen()
    before = _dump(model)
    for i in range(5):
        score_session_anomaly(
            model, typing_session(day=30 + i, ht=150.0 + i * 5, seed=500 + i),
            LAYER2_TYPING_FEATURES)
    assert _dump(model) == before


def _dump(model) -> bytes:
    buffer = io.BytesIO()
    joblib.dump(model, buffer)
    return buffer.getvalue()


def test_single_abnormal_session_does_not_trigger_attention():
    # One feature excursions in one session: detected, but the
    # persistence gate holds — no attention without repetition or
    # multi-feature agreement.
    baseline, model, used = build_frozen()
    # pauses=8 against a ~1.0 baseline: CUSUM-visible on exactly one
    # feature. (The personal forest may not flag lone single-feature
    # excursions at all — one reason Layer 2 combines both signals.)
    spike = typing_session(day=30, seed=999, pauses=8.0)
    normals = [s for s in used if not score_session_anomaly(
        model, s, LAYER2_TYPING_FEATURES)["is_anomaly"]]
    assert len(normals) >= 9
    recent = normals[-9:] + [spike]
    drift = detect_drift(baseline, recent, LAYER2_TYPING_FEATURES)
    assert drift["drifting_features"] == ["pause_frequency"]
    assert drift["status"] != "attention"
    result = score_monitoring_session(baseline, model, spike, recent,
                                      LAYER2_TYPING_FEATURES)
    assert result["status"] != "attention"
    assert result["anomaly_run"] is False


def test_sustained_drift_triggers_attention():
    baseline, model, used = build_frozen()
    drifted = [typing_session(day=30 + i, ht=160.0, ft=320.0, ikl=480.0,
                              seed=700 + i) for i in range(10)]
    recent = used[-2:] + drifted[-8:]
    result = score_monitoring_session(baseline, model, drifted[-1], recent,
                                      LAYER2_TYPING_FEATURES)
    assert result["status"] == "attention"
    assert len(result["drift_result"]["drifting_features"]) >= 3


def test_multi_feature_drift_lists_all_drifting_features():
    baseline, _, used = build_frozen()
    drifted = [typing_session(day=30 + i, ht=170.0, ft=340.0, ikl=500.0,
                              seed=800 + i) for i in range(10)]
    drift = detect_drift(baseline, used[-2:] + drifted[-8:],
                         LAYER2_TYPING_FEATURES)
    assert {"ht_mean", "ft_mean", "ikl_mean"} <= set(
        drift["drifting_features"])


def test_ewma_reports_trend_direction():
    assert compute_ewma([0, 0.5, 1.0, 1.5, 2.0])[-1] > 0.5
    baseline, _, used = build_frozen()
    rising = [typing_session(
        day=30 + i, ht=100.0 + i * 8.0, seed=900 + i) for i in range(8)]
    drift = detect_drift(baseline, used[-2:] + rising,
                         ["ht_mean"])
    assert drift["drift_signals"]["ht_mean"]["trend"] == "increasing"


def test_layers_stay_separate():
    layer2 = {"status": "attention", "score": 0.9}
    first = dual_result({"status": "normal"}, layer2, 10)
    second = dual_result({"status": "attention", "extra": True}, layer2, 10)
    assert first["layer2"] == second["layer2"]  # Layer 1 can't move Layer 2
    assert "blended" not in first and "combined_score" not in first
    assert first["layer2"]["confidence"] == "established"
    assert dual_result({}, layer2, 2)["layer2"]["confidence"] == "building"
    assert dual_result({}, layer2, 2)["primary_focus"] == "layer1"
    assert dual_result({}, layer2, 9)["primary_focus"] == "layer2"


def test_no_demographic_or_symptom_field_in_feature_vector():
    forbidden = {"age_at_session", "age_years", "sex_gender",
                 "tremor", "stiffness", "slowness", "fatigue",
                 "sleep_quality", "medication_state", "diagnosis_year"}
    assert not (set(LAYER2_TYPING_FEATURES) & forbidden)
    assert not (set(MOTOR_TASK_FEATURE_LIST) & forbidden)
    # Even when present on the session, they never reach the model:
    baseline, model, used = build_frozen()
    enriched = dict(used[-1])
    enriched.update({"age_at_session": 70, "sex_gender": "Male",
                     "tremor": 8, "medication_state": "OFF"})
    plain = score_session_anomaly(model, used[-1], LAYER2_TYPING_FEATURES)
    assert score_session_anomaly(
        model, enriched, LAYER2_TYPING_FEATURES) == plain


def test_motor_task_group_scores_separately():
    motor = {"timestamp": DAY0 + timedelta(days=30),
             "device_id": "kbd-a", "mode": "motor_task",
             "valid_taps": 40, "mean_iti_ms": 150.0, "std_iti_ms": 12.0,
             "miss_rate": 0.0, "extra_tap_count": 0,
             "slowing_slope_ms": 0.5}
    history = [dict(motor, mean_iti_ms=150.0 + (i % 3)) for i in range(10)]
    drift = detect_drift(
        {"features": {"mean_iti_ms": {"mean": 150.0, "std": 3.0,
                                      "median": 150.0, "mad": 2.0}}},
        history, ["mean_iti_ms"])
    assert drift["status"] in ("normal", "watch", "attention")
    assert set(drift["drift_signals"]) == {"mean_iti_ms"}
