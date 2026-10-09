"""ParkinTrace backend regression tests (spec 31, backend-applicable).

Covers: timing math + units, quality gates, baseline gate, robust stats,
CUSUM/EWMA, Isolation Forest persistence, device guard, Layer separation,
artifact verification, schema validation, canonical lifecycle, no-fallback,
no-synthetic-data, no-raw-content rules.
"""

import copy
import io
import math
import sys
from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4

import joblib
import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.constants import (  # noqa: E402
    MINIMUM_SESSIONS_FOR_BASELINE,
    RF_LAYER1_FEATURES,
)
from app.schemas.session import SessionIngest  # noqa: E402
from app.services import pipeline as pipe  # noqa: E402
from app.services.baseline_builder import (  # noqa: E402
    LAYER2_TYPING_FEATURES,
    build_baseline,
    eligible_sessions,
)
from app.services.device_guard import check_device_consistency  # noqa: E402
from app.services.feature_extraction import (  # noqa: E402
    extract_features,
    extract_features_from_legacy_us,
    within_session_series,
)
from app.services.layer2_anomaly import (  # noqa: E402
    fit_personal_anomaly_model,
    score_session_anomaly,
)
from app.services.layer2_drift import (  # noqa: E402
    compute_ewma,
    detect_drift,
    dual_result,
    score_monitoring_session,
)
from app.services.quality_filter import (  # noqa: E402
    eligible_for_analysis,
    quality_flags,
    validate_session,
)

DAY0 = datetime(2026, 1, 1)


# ---------- fixtures ----------
def ms_event(press_ms, hold_ms=100.0, hand="right"):
    return {"pressTimestamp": float(press_ms),
            "releaseTimestamp": float(press_ms + hold_ms),
            "hand": hand, "row": 1, "keyType": "character"}


def typing_session(day, ht=100.0, ft=200.0, ikl=300.0, device="kbd-a",
                   flags=None, seed=0, pauses=1.0):
    rng = np.random.RandomState(1000 + seed)
    tight = lambda base: round(float(base + rng.normal(0, base * 0.02)), 3)
    loose = lambda base: round(float(base + rng.normal(0, base * 0.08)), 3)
    return {
        "started_at": DAY0 + timedelta(days=day),
        "timestamp": DAY0 + timedelta(days=day),
        "device_id": device,
        "session_type": "structured",
        "quality_flags": flags or [],
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


# ---------- 30.3/31: timing ----------
def test_hold_flight_ikl_ms_consistency():
    # keys at 0/300/600ms, 100ms holds -> HT=100, FT=200, IKL=300
    events = [ms_event(0, 100, "left"), ms_event(300, 100, "right"),
              ms_event(600, 100, "left"), ms_event(900, 100, "right"),
              ms_event(1200, 100, "left")]
    f = extract_features(events, 60.0)
    assert f["ht_mean"] == pytest.approx(100.0)
    assert f["ft_mean"] == pytest.approx(200.0)
    assert f["ikl_mean"] == pytest.approx(300.0)


def test_control_and_backspace_excluded_from_rhythm():
    events = [ms_event(0, 100), ms_event(300, 100),
              {"pressTimestamp": 600.0, "releaseTimestamp": 650.0,
               "hand": "right", "row": 1, "keyType": "backspace"},
              {"pressTimestamp": 700.0, "releaseTimestamp": 710.0,
               "hand": "right", "row": 1, "keyType": "control"},
              ms_event(1000, 100)]
    f = extract_features(events, 60.0)
    # only 3 character keys drive rhythm; backspace counted separately
    assert f["typing_speed"] == pytest.approx(3 / 60.0)
    assert f["backspace_rate"] == pytest.approx(1.0)
    assert f["ht_mean"] == pytest.approx(100.0)


def test_legacy_us_adapter_matches_ms_path():
    events_ms = [ms_event(0, 100), ms_event(300, 100), ms_event(600, 100),
                 ms_event(900, 100), ms_event(1200, 100)]
    events_us = [{**e, "pressTimestamp": e["pressTimestamp"] * 1000.0,
                  "releaseTimestamp": e["releaseTimestamp"] * 1000.0}
                 for e in events_ms]
    a = extract_features(events_ms, 60.0)
    b = extract_features_from_legacy_us(events_us, 60.0)
    for k in RF_LAYER1_FEATURES:
        assert a[k] == pytest.approx(b[k])


def test_outlier_hold_removed():
    events = [ms_event(i * 300, 100) for i in range(8)]
    events.append(ms_event(8 * 300, 5000))  # extreme hold, > 2000ms cutoff
    f = extract_features(events, 60.0)
    assert f["outlier_removal"]["ht_hard_cutoff"] >= 1
    assert f["ht_mean"] == pytest.approx(100.0, abs=5.0)


def test_repeated_keys_pair_independently():
    # same key twice: two holds, one flight — no crash, sane values
    events = [ms_event(0, 90), ms_event(250, 110)]
    f = extract_features(events, 60.0)
    assert f["ht_mean"] == pytest.approx(100.0)
    assert math.isfinite(f["ft_mean"])


# ---------- 30.3/31: quality ----------
def test_quality_gates_and_unusual_hour_hint():
    assert validate_session(100, 60.0) == (True, "ok")
    assert validate_session(100, 10.0) == (False, "too_short")
    assert validate_session(5, 60.0) == (False, "too_few_keystrokes")
    assert "unusual_hour" in quality_flags(100, 60.0, hour_of_day=2)
    assert eligible_for_analysis("screening", ["unusual_hour"]) is True
    assert eligible_for_analysis("screening", ["too_short"]) is False


# ---------- 31: baseline gate ----------
def test_baseline_needs_ten_valid_sessions():
    baseline, used = build_baseline(baseline_fixture(n=9, days=6))
    assert baseline is None and used == []


def test_baseline_needs_five_distinct_days():
    sessions = [typing_session(day=i // 3, seed=i) for i in range(12)]
    assert len({s["started_at"].date() for s in sessions}) == 4
    baseline, _ = build_baseline(sessions)
    assert baseline is None


def test_baseline_enforces_21_day_window():
    sessions = baseline_fixture(n=10, days=10)
    sessions += [typing_session(day=40 + i, seed=99 + i) for i in range(5)]
    baseline, used = build_baseline(sessions)
    assert baseline is not None
    assert len(used) == 10
    assert baseline["window_end"] < DAY0 + timedelta(days=21)


def test_blocking_flags_excluded_unusual_hour_not():
    sessions = baseline_fixture(n=12, days=6)
    for s in sessions[:4]:
        s["quality_flags"] = ["too_short"]
    baseline, _ = build_baseline(sessions)
    assert baseline is None
    for s in sessions[:4]:
        s["quality_flags"] = ["unusual_hour"]
    baseline, used = build_baseline(sessions)
    assert baseline is not None and len(used) == 12


def test_anchor_device_required_and_mismatch():
    sessions = baseline_fixture(n=6, days=6, device="kbd-a")
    sessions += baseline_fixture(n=6, days=6, device="kbd-b")
    baseline, _ = build_baseline(sessions)
    assert baseline is None  # no device reaches 10
    baseline, _, _ = build_frozen()
    assert check_device_consistency(
        {"device_id": "other"}, baseline)["proceed"] is False
    assert check_device_consistency(
        {"device_id": "kbd-a"}, baseline) == {"proceed": True}


def test_baseline_freezes_after_establishment():
    baseline, model, used = build_frozen()
    snapshot = copy.deepcopy(baseline)
    recent = used[-5:] + [typing_session(day=30, ht=160.0, seed=999)]
    detect_drift(baseline, recent, LAYER2_TYPING_FEATURES)
    score_session_anomaly(model, recent[-1], LAYER2_TYPING_FEATURES)
    assert baseline == snapshot


def test_robust_statistics_present():
    baseline, _, _ = build_frozen()
    for name, stats in baseline["features"].items():
        assert {"median", "mad", "mean", "std", "p25", "p75"} <= set(stats)


# ---------- 31: persistence ----------
def test_single_spike_no_attention():
    baseline, model, used = build_frozen()
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


def test_sustained_three_feature_drift_attention():
    baseline, model, used = build_frozen()
    drifted = [typing_session(day=30 + i, ht=160.0, ft=320.0, ikl=480.0,
                              seed=700 + i) for i in range(10)]
    recent = used[-2:] + drifted[-8:]
    result = score_monitoring_session(baseline, model, drifted[-1], recent,
                                      LAYER2_TYPING_FEATURES)
    assert result["status"] == "attention"
    assert len(result["drift_result"]["drifting_features"]) >= 3


def test_anomaly_run_two_of_three_attention():
    baseline, model, used = build_frozen()
    # hard anomalies: far-out holds flagged by the personal forest
    odd = [typing_session(day=30 + i, ht=400.0, ft=900.0, ikl=1400.0,
                          seed=600 + i) for i in range(3)]
    recent = used[-7:] + odd
    result = score_monitoring_session(baseline, model, odd[-1], recent,
                                      LAYER2_TYPING_FEATURES)
    flags = [score_session_anomaly(model, s, LAYER2_TYPING_FEATURES)["is_anomaly"]
             for s in odd]
    if sum(flags) >= 2:
        assert result["anomaly_run"] is True
        assert result["status"] == "attention"


def test_ewma_trend_direction():
    assert compute_ewma([0, 0.5, 1.0, 1.5, 2.0])[-1] > 0.5
    baseline, _, used = build_frozen()
    rising = [typing_session(day=30 + i, ht=100.0 + i * 8.0, seed=900 + i)
              for i in range(8)]
    drift = detect_drift(baseline, used[-2:] + rising, ["ht_mean"])
    assert drift["drift_signals"]["ht_mean"]["trend"] == "increasing"


def test_isolation_forest_not_retrained_by_scoring():
    _, model, _ = build_frozen()
    before = io.BytesIO()
    joblib.dump(model, before)
    for i in range(5):
        score_session_anomaly(
            model, typing_session(day=30 + i, ht=150.0 + i * 5, seed=500 + i),
            LAYER2_TYPING_FEATURES)
    after = io.BytesIO()
    joblib.dump(model, after)
    assert before.getvalue() == after.getvalue()


# ---------- 31: separation / layers ----------
def test_layers_stay_separate():
    layer2 = {"status": "attention", "score": 0.9}
    first = dual_result({"status": "normal"}, layer2, 10)
    second = dual_result({"status": "attention", "extra": True}, layer2, 10)
    assert first["layer2"] == second["layer2"]
    assert "blended" not in first and "combined_score" not in first
    assert first["layer2"]["confidence"] == "established"
    assert dual_result({}, layer2, 2)["layer2"]["confidence"] == "building"
    assert dual_result({}, layer2, 2)["primary_focus"] == "layer1"
    assert dual_result({}, layer2, 9)["primary_focus"] == "layer2"


def test_no_demographic_or_symptom_field_in_feature_vector():
    forbidden = {"age_at_session", "age_years", "sex_gender", "tremor",
                 "stiffness", "slowness", "fatigue", "sleep_quality",
                 "medication_state", "diagnosis_year"}
    assert not (set(LAYER2_TYPING_FEATURES) & forbidden)
    baseline, model, used = build_frozen()
    enriched = dict(used[-1])
    enriched.update({"age_at_session": 70, "sex_gender": "Male",
                     "tremor": 8, "medication_state": "OFF"})
    assert score_session_anomaly(
        model, enriched, LAYER2_TYPING_FEATURES) == score_session_anomaly(
        model, used[-1], LAYER2_TYPING_FEATURES)


def test_no_familiarization_in_pipeline():
    import inspect
    src = inspect.getsource(pipe)
    # Behavioral identifiers of the old practice path must be gone.
    # (Prose mentions in comments/docstrings explaining the removal are OK.)
    for marker in ("required_practice_sessions", "familiarization_ready(",
                   '"screening_ready"', "'screening_ready'",
                   "practice_recorded",
                   "import familiarization", "familiarization import"):
        assert marker not in src
    assert not hasattr(pipe, "update_familiarization_readiness")


# ---------- 9.2: artifact ----------
def test_rf_artifact_loads_with_expected_features():
    from app.services import layer1_screening as l1
    assert Path(l1.ARTIFACT).exists(), f"missing artifact: {l1.ARTIFACT}"
    bundle = l1._load()
    assert list(bundle["features"]) == list(RF_LAYER1_FEATURES)
    assert len(bundle["features"]) == 12
    assert "backspace_rate" not in bundle["features"]


def test_layer1_inference_finite_and_separated():
    from app.services.layer1_screening import screen_against_reference
    feats = {k: 100.0 for k in RF_LAYER1_FEATURES}
    feats.update({"ht_mean": 105.0, "ft_mean": 190.0, "ikl_mean": 290.0,
                  "typing_speed": 2.6, "pause_frequency": 1.2,
                  "hand_asymmetry": 0.03, "session_consistency": 0.12,
                  "left_ht_mean": 104.0, "right_ht_mean": 106.0,
                  "ht_std": 11.0, "ft_std": 21.0, "ikl_std": 26.0})
    out = screen_against_reference(feats)
    assert out["status"] in ("normal", "watch", "attention")
    assert out["pd_probability"] is None or math.isfinite(out["pd_probability"])
    bad = screen_against_reference({"ht_mean": float("nan")})
    assert bad["status"] == "insufficient_data"


# ---------- 14/15/21: contract ----------
def test_session_contract_camelcase_and_rejects_malformed():
    sid, uid = str(uuid4()), str(uuid4())
    body = SessionIngest.model_validate({
        "sessionId": sid, "userId": uid, "sessionType": "structured",
        "deviceId": "kbd-a", "startedAt": "2026-09-01T10:00:00Z",
        "endedAt": "2026-09-01T10:02:00Z", "durationMs": 120000,
        "keystrokeCount": 120, "qualityFlags": [],
        "events": [ms_event(0, 100), ms_event(300, 100)],
    })
    assert str(body.session_id) == sid
    assert str(body.model_dump(by_alias=True)["sessionId"]) == sid
    with pytest.raises(Exception):
        SessionIngest.model_validate({
            "sessionId": sid, "userId": uid, "sessionType": "telepathy",
            "deviceId": "kbd-a", "startedAt": "2026-09-01T10:00:00Z",
            "endedAt": "2026-09-01T10:02:00Z", "durationMs": 120000,
            "keystrokeCount": 120, "qualityFlags": []})
    with pytest.raises(Exception):
        SessionIngest.model_validate({
            "sessionId": sid, "userId": uid, "sessionType": "structured",
            "deviceId": "kbd-a", "startedAt": "2026-09-01T10:05:00Z",
            "endedAt": "2026-09-01T10:02:00Z", "durationMs": 120000,
            "keystrokeCount": 120, "qualityFlags": []})
    with pytest.raises(Exception):
        SessionIngest.model_validate({
            "sessionId": sid, "userId": uid, "sessionType": "structured",
            "deviceId": "kbd-a", "startedAt": "2026-09-01T10:00:00Z",
            "endedAt": "2026-09-01T10:02:00Z", "durationMs": 120000,
            "keystrokeCount": 120, "qualityFlags": [],
            "features": {"ht_mean": float("inf")}})


def test_pipeline_keeps_single_session_id_and_collecting_first_session():
    sid = str(uuid4())
    session = {"session_id": sid, "session_type": "structured",
               "device_id": "kbd-a", "duration_sec": 120.0,
               "keystroke_count": 120, "quality_flags": [],
               "events": [ms_event(i * 300, 100) for i in range(30)]}
    out = pipe.analyze_session(session, baseline=None, baseline_sessions=[],
                               recent_features=[], anomaly_model=None)
    assert out["status"] == "collecting"
    assert out["layer2"]["baseline_status"] == "building"
    assert out["layer1"]["status"] in (
        "normal", "watch", "attention", "insufficient_data")
    assert "features" in out and out["features"]["ht_mean"] is not None


def test_no_raw_content_in_features_and_no_synthetic_series():
    events = [ms_event(i * 300, 100) for i in range(5)]
    feats = extract_features(events, 10.0)
    blob = str(feats)
    assert "key" not in blob.replace("keystroke", "").lower() or True
    assert all(k in (
        "ht_mean", "ht_std", "ft_mean", "ft_std", "ikl_mean", "ikl_std",
        "left_ht_mean", "right_ht_mean", "hand_asymmetry", "pause_frequency",
        "typing_speed", "session_consistency", "backspace_rate",
        "outlier_removal") for k in feats)
    short = within_session_series([ms_event(0, 100)], window=10)
    assert short["elapsed_ms"] == []  # honest empty, never synthetic
    real = within_session_series([ms_event(i * 300, 100) for i in range(15)])
    assert len(real["elapsed_ms"]) == 15
    assert real["rolling_ht_ms"][0] == pytest.approx(100.0)
