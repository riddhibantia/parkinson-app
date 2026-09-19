"""Stage 6 skeleton tests: familiarization gate, baseline stats/gates,
device guard. No ML, no Firebase — pure service logic only."""

import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.baseline_builder import baseline_quality_ok, build_baseline
from services.device_guard import check_device_consistency
from services.familiarization import (
    familiarization_ready,
    median_apc,
    required_practice_sessions,
)
from utils.constants import TYPING_FEATURE_LIST


def core(ht=100.0, ft=200.0, ikl=300.0, speed=2.0, pauses=1.0, asym=0.05):
    return {
        "ht_mean": ht, "ht_std": 10.0,
        "ft_mean": ft, "ft_std": 20.0,
        "ikl_mean": ikl, "ikl_std": 25.0,
        "typing_speed": speed,
        "pause_frequency": pauses,
        "hand_asymmetry": asym,
    }


def test_identical_sessions_are_ready():
    assert median_apc(core(), core()) == 0.0
    assert familiarization_ready(core(), core()) is True


def test_uniform_drift_beyond_threshold_is_not_ready():
    # ×1.2 on every moving feature: |a-b|/max(a,b) = 1/6 each, while the
    # three *_std features do not move. Median = 1/6 > 0.15 gate.
    shifted = core(ht=120.0, ft=240.0, ikl=360.0, speed=2.4,
                   pauses=1.2, asym=0.06)
    assert abs(median_apc(core(), shifted) - 1 / 6) < 1e-9
    assert familiarization_ready(core(), shifted) is False


def test_required_practice_counts():
    assert required_practice_sessions("not_familiar") == 2
    assert required_practice_sessions("regular") == 1
    assert required_practice_sessions("occasional") == 1


def session_on(day, device="kbd-a", ht=100.0):
    features = {k: ht for k in TYPING_FEATURE_LIST}
    return {
        **features,
        "timestamp": datetime(2026, 1, 1) + timedelta(days=day),
        "device_id": device,
    }


def test_baseline_builds_from_qualifying_sessions():
    sessions = [session_on(day=i // 2, ht=100.0 + i) for i in range(12)]
    baseline, used = build_baseline(sessions)
    assert baseline is not None
    assert baseline["session_count"] == 12
    assert baseline["anchor_device_id"] == "kbd-a"
    assert baseline["features"]["ht_mean"]["median"] == 105.5
    assert len(used) == 12


def test_baseline_rejects_single_day_rush():
    sessions = [session_on(day=i // 10, ht=100.0) for i in range(10)]
    ok, reason = baseline_quality_ok(sessions)
    assert ok is False
    assert "days" in reason
    baseline, _ = build_baseline(sessions)
    assert baseline is None


def test_baseline_rejects_too_few_sessions():
    sessions = [session_on(day=i, ht=100.0) for i in range(9)]
    assert build_baseline(sessions) == (None, [])


def test_baseline_anchors_one_keyboard():
    sessions = [session_on(day=i // 2, device="kbd-a", ht=100.0)
                for i in range(10)]
    sessions += [session_on(day=i // 2, device="kbd-b", ht=300.0)
                 for i in range(4)]
    baseline, used = build_baseline(sessions)
    assert baseline is not None
    assert baseline["anchor_device_id"] == "kbd-a"
    assert all(s["device_id"] == "kbd-a" for s in used)
    assert baseline["features"]["ht_mean"]["median"] == 100.0


def test_baseline_window_ignores_late_sessions():
    sessions = [session_on(day=i, ht=100.0) for i in range(10)]
    sessions += [session_on(day=25 + i, ht=999.0) for i in range(5)]
    baseline, used = build_baseline(sessions)
    assert baseline is not None
    assert len(used) == 10
    assert baseline["window_end"] < datetime(2026, 1, 26)


def test_build_does_not_mutate_input():
    sessions = [session_on(day=i // 2, ht=100.0) for i in range(12)]
    build_baseline(sessions)
    assert len(sessions) == 12


def test_device_guard():
    baseline = {"anchor_device_id": "kbd-a"}
    assert check_device_consistency(
        {"device_id": "kbd-a"}, baseline) == {"proceed": True}
    result = check_device_consistency({"device_id": "kbd-b"}, baseline)
    assert result["proceed"] is False
    assert result["status"] == "device_mismatch"
