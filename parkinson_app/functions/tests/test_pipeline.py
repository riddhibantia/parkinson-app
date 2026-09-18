"""End-to-end pipeline tests (Stage 6): the complete user journey against
an in-memory Firestore fake — practice gate, collection, baseline build
(with a real per-user Isolation Forest fit), Layer 1 + Layer 2 monitoring,
device mismatch, rejection, motor handling, and explicit reset.

No retraining of Stage 4 models: the frozen RF artifact is loaded for
inference only.
"""

import sys
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.baseline_builder import LAYER2_TYPING_FEATURES  # noqa: E402
from services.layer2_anomaly import score_session_anomaly  # noqa: E402
from services.pipeline import (  # noqa: E402
    dashboard_data,
    handle_new_session,
    reset_user_baseline,
)
from utils.constants import TYPING_FEATURE_LIST  # noqa: E402

DAY0 = datetime(2026, 1, 1)


class FakeSnap:
    def __init__(self, doc_id, data):
        self.id = doc_id
        self._data = data

    @property
    def exists(self):
        return self._data is not None

    def to_dict(self):
        return dict(self._data) if self._data is not None else None


class FakeDoc:
    def __init__(self, parent, doc_id):
        self._parent = parent
        self.id = doc_id
        self._subs = {}

    def get(self):
        return FakeSnap(self.id, self._parent.get(self.id))

    def set(self, data, merge=False):
        if merge and self._parent.get(self.id):
            merged = dict(self._parent[self.id])
            merged.update(data)
            self._parent[self.id] = merged
        else:
            self._parent[self.id] = dict(data)

    def delete(self):
        self._parent.pop(self.id, None)

    def collection(self, name):
        key = (self.id, name)
        if key not in FakeCollection._registry:
            FakeCollection._registry[key] = FakeCollection()
        return FakeCollection._registry[key]


class FakeQuery:
    def __init__(self, docs, order_field=None, descending=False, limit=None):
        self._docs = docs
        self._order_field = order_field
        self._descending = descending
        self._limit = limit

    def order_by(self, field, descending=False):
        return FakeQuery(self._docs, field, descending, self._limit)

    def limit(self, n):
        return FakeQuery(self._docs, self._order_field, self._descending, n)

    def stream(self):
        docs = list(self._docs)
        if self._order_field:
            docs.sort(key=lambda d: d.to_dict().get(self._order_field),
                      reverse=self._descending)
        if self._limit is not None:
            docs = docs[:self._limit]
        return docs


class FakeCollection:
    _registry = {}

    def __init__(self):
        self._docs = {}
        self._auto = 0

    def document(self, doc_id=None):
        if doc_id is None:
            self._auto += 1
            doc_id = f"auto-{self._auto}"
        return FakeDoc(self._docs, doc_id)

    def stream(self):
        return [FakeSnap(doc_id, data)
                for doc_id, data in self._docs.items()]

    def order_by(self, field, descending=False):
        return FakeQuery(self.stream(), field, descending)

    def limit(self, n):
        return FakeQuery(self.stream(), limit=n)


class FakeDb:
    def __init__(self):
        FakeCollection._registry = {}
        self._cols = {}

    def collection(self, name):
        if name not in self._cols:
            self._cols[name] = FakeCollection()
        return self._cols[name]


class FakeStore:
    def __init__(self):
        self.models = {}
        self.save_count = 0

    def save(self, user_id, model, kind="typing"):
        self.models[(user_id, kind)] = model
        self.save_count += 1

    def load(self, user_id, kind="typing"):
        return self.models.get((user_id, kind))

    def delete(self, user_id):
        self.models.pop((user_id, "typing"), None)
        self.models.pop((user_id, "motor"), None)


def stable_features(seed, ht=100.0, ft=200.0, ikl=300.0, pct=0.02):
    rng = np.random.RandomState(2000 + seed)
    jitter = lambda base: round(
        float(base + rng.normal(0, base * pct)), 3)
    return {
        "ht_mean": jitter(ht), "ht_std": 10.0,
        "ft_mean": jitter(ft), "ft_std": 20.0,
        "ikl_mean": jitter(ikl), "ikl_std": 25.0,
        "left_ht_mean": jitter(ht), "right_ht_mean": jitter(ht),
        "hand_asymmetry": round(float(0.02 + rng.normal(0, 0.002)), 4),
        "pause_frequency": 1.0, "typing_speed": 2.5,
        "session_consistency": 0.1, "backspace_rate": 2.0,
    }


def session_doc(day, seed, phase="screening", device="kbd-a",
                mode="structured", flags=None, pct=0.02, **overrides):
    doc = {
        **stable_features(seed, pct=pct, **overrides),
        "device_id": device,
        "mode": mode,
        "session_phase": phase,
        "quality_flags": flags or [],
        "keystroke_count": 120,
        "duration_sec": 60.0,
        "timestamp": DAY0 + timedelta(days=day, hours=seed % 5),
    }
    return doc


def persist_and_handle(db, store, user_id, session_id, doc):
    db.collection("users").document(user_id).collection(
        "sessions").document(session_id).set(doc)
    return handle_new_session(db, user_id, session_id, doc, store)


def fresh_user(db, level="not_familiar"):
    db.collection("users").document("u1").set(
        {"typing_experience_level": level})


def test_full_journey():
    db, store = FakeDb(), FakeStore()
    fresh_user(db)

    # 1. Familiarization gate: not_familiar needs 2 stable sessions.
    r1 = persist_and_handle(db, store, "u1", "p1",
                            session_doc(0, 1, phase="familiarization",
                                        pct=0.005))
    assert r1["status"] == "practice_recorded"
    assert r1["screening_ready"] is False
    r2 = persist_and_handle(db, store, "u1", "p2",
                            session_doc(0, 2, phase="familiarization",
                                        pct=0.005))
    assert r2["screening_ready"] is True
    assert db.collection("users").document("u1").get().to_dict()[
        "screening_ready"] is True

    # 2. Collection: 12 screening sessions across 6 days.
    results = []
    for i in range(12):
        results.append(persist_and_handle(
            db, store, "u1", f"s{i}", session_doc(day=i // 2, seed=10 + i,
                                                       pct=0.005)))
    assert all(r["status"] == "collecting" for r in results[:9])
    assert results[9]["status"] == "baseline_built"
    assert store.save_count == 1  # fit exactly once
    assert db.collection("users").document("u1").collection(
        "baselines").document("current").get().exists

    # 3. Monitoring: dual result, building confidence, real Layer 1.
    r = results[10]
    assert set(r) >= {"layer1", "layer2", "primary_focus"}
    assert r["layer2"]["confidence"] == "building"
    assert r["primary_focus"] == "layer1"
    assert isinstance(r["layer1"]["pd_probability"], float)
    assert r["layer1"]["status"] in ("normal", "watch", "attention")

    # Calm follow-ups replay in-sample baseline patterns on new days —
    # a user typing normally again. Chosen among sessions the personal
    # model itself scores normal, so this asserts dispatch wiring (not
    # detector calibration, which Stage 5 tests own).
    model = store.load("u1", "typing")
    calm_pool = [
        s for s in [
            session_doc(day=0, seed=10 + i, pct=0.005) for i in range(10)]
        if not score_session_anomaly(
            model, s, LAYER2_TYPING_FEATURES)["is_anomaly"]]
    assert len(calm_pool) >= 3
    for j, calm in enumerate(calm_pool[:3]):
        calm = dict(calm)
        calm["timestamp"] = DAY0 + timedelta(days=6 + j)
        calm_result = persist_and_handle(
            db, store, "u1", f"c{j}", calm)
        assert calm_result["layer2"]["status"] in ("normal", "watch"), j

    # 4. Sustained drift -> attention via the same dispatch.
    last = None
    for i in range(8):
        last = persist_and_handle(
            db, store, "u1", f"d{i}",
            session_doc(day=7 + i // 2, seed=300 + i,
                        ht=160.0, ft=320.0, ikl=480.0))
    assert last["layer2"]["status"] == "attention"
    assert len(last["layer2"]["drift_result"][
        "drifting_features"]) >= 3

    # 5. Wrong keyboard -> device mismatch, no scoring.
    mismatch = persist_and_handle(db, store, "u1", "x1",
                                  session_doc(day=12, seed=400,
                                              device="other-kbd"))
    assert mismatch["layer2"]["status"] == "device_mismatch"

    # 6. Too-short session -> rejected before any analysis.
    short = session_doc(day=12, seed=401)
    short["keystroke_count"] = 5
    short["duration_sec"] = 4.0
    rejected = persist_and_handle(db, store, "u1", "x2", short)
    assert rejected["status"] == "rejected"

    # 7. Motor session: no Layer 1, Layer 2 on the motor group.
    motor = {"device_id": "kbd-a", "mode": "motor_task",
             "session_phase": "screening", "quality_flags": [],
             "keystroke_count": 0, "duration_sec": 15.0,
             "timestamp": DAY0 + timedelta(days=13),
             "valid_taps": 40, "mean_iti_ms": 150.0, "std_iti_ms": 12.0,
             "miss_rate": 0.0, "extra_tap_count": 0,
             "slowing_slope_ms": 0.5}
    motor_result = persist_and_handle(db, store, "u1", "m1", motor)
    assert motor_result["layer1"]["status"] == "not_applicable"
    assert motor_result["layer2"]["anomaly_result"]["reason"] == \
        "model_pending"

    # 8. Explicit reset clears baseline + artifact; with recent
    # qualifying history still present, the next session rebuilds —
    # the rebuild path, not silent adaptation.
    assert reset_user_baseline(db, "u1", store) == {
        "status": "baseline_reset"}
    assert not db.collection("users").document("u1").collection(
        "baselines").document("current").get().exists
    assert store.models == {}
    after = persist_and_handle(db, store, "u1", "s99",
                               session_doc(day=60, seed=500))
    assert after["status"] == "baseline_built"
    assert store.save_count == 2  # one fit per explicit build only

    # 9. Dashboard aggregation reflects the journey.
    dash = dashboard_data(db, "u1")
    assert dash["screening_ready"] is True
    assert dash["baseline_ready"] is True
    assert dash["latest_result"]["session_id"] == "s99"


def test_single_practice_user_unblocked_after_one():
    db, store = FakeDb(), FakeStore()
    fresh_user(db, level="regular")
    doc = session_doc(0, 1, phase="familiarization")
    assert persist_and_handle(
        db, store, "u1", "p1", doc)["screening_ready"] is True
