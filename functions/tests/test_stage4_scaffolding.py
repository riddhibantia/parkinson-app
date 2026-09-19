"""Stage 4.1 fixture tests: adapters, explicit label join, evaluation
scaffolding. No model fitting anywhere in this file."""

import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.evaluation import (
    assert_no_subject_leakage,
    fit_per_dataset_scalers,
    leave_one_dataset_out_splits,
    subject_grouped_folds,
    summarize_metrics,
    transform_with_scalers,
    transform_with_train_scaler,
)
from services.harmonize_datasets import load_and_label
from services.neuroqwerty_adapter import (
    file_to_events,
    file_to_features,
    hand_for,
    key_type_for,
    row_for,
)
from services.tappy_adapter import (
    age_at_session,
    load_users,
    month_to_features,
    monthly_files,
    read_monthly_file,
)


def _tappy_root(tmp_path):
    root = tmp_path / "tappy"
    kdir = root / "keystrokes" / "Tappy Data"
    udir = root / "users" / "Archived users"
    kdir.mkdir(parents=True)
    udir.mkdir(parents=True)
    (udir / "User_AAAA111111.txt").write_text(
        "BirthYear: 1950\nGender: Female\nParkinsons: True\n")
    (udir / "User_BBBB222222.txt").write_text(
        "BirthYear: 1960\nGender: Male\nParkinsons: False\n")
    (udir / "User_CCCC333333.txt").write_text(
        "BirthYear: 1970\nGender: Male\nParkinsons: False\n")
    rows = ["AAAA111111\t160701\t10:00:00.000\tL\t0100.0\tLL\t0300.0\t0200.0\t"]
    t = 300.0
    for i in range(1, 8):
        # Corrupt row 4: missing newline concatenates two records.
        if i == 4:
            rows.append("AAAA111111\t160701\t10:00:01.200\tL\t0090.0AAAA111111\t160701\t10:00:01.300")
        hand = "L" if i % 2 == 0 else "R"
        rows.append(f"AAAA111111\t160701\t10:00:{i:02d}.000\t{hand}\t"
                    f"0100.0\tLR\t0300.0\t0200.0\t")
        t += 300.0
    (kdir / "AAAA111111_1607.txt").write_text("\n".join(rows) + "\n")
    (kdir / "BBBB222222_1607.txt").write_text(
        "BBBB222222\t160701\t10:00:00.000\tR\t0120.0\tRR\t0400.0\t0250.0\t\n"
        "BBBB222222\t160701\t10:00:01.000\tR\t0120.0\tRR\t0400.0\t0250.0\t\n")
    # CCCC333333 has keystroke data but is removed from users below by the
    # join test (simulated by dropping its label row).
    (kdir / "CCCC333333_1607.txt").write_text(
        "CCCC333333\t160701\t10:00:00.000\tL\t0100.0\tLL\t0300.0\t0200.0\t\n"
        "CCCC333333\t160701\t10:00:01.000\tL\t0100.0\tLL\t0300.0\t0200.0\t\n")
    return str(root)


def test_tappy_users_and_label_parse():
    import tempfile, os
    with tempfile.TemporaryDirectory() as tmp:
        root = _tappy_root(Path(tmp))
        users = load_users(root)
        assert len(users) == 3
        assert users.set_index("subject_id").loc[
            "AAAA111111", "parkinsons_label"] == 1
        assert users["BirthYear"].tolist() == ["1950", "1960", "1970"]


def test_tappy_monthly_read_drops_first_and_corrupt_rows():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        root = _tappy_root(Path(tmp))
        assert monthly_files(root, "AAAA111111") == ["AAAA111111_1607.txt"]
        df = read_monthly_file(root, "AAAA111111_1607.txt")
        # 9 lines written: first dropped (stale context), 1 corrupt dropped.
        assert len(df) == 7
        assert (df["ht"] == 100.0).all()


def test_tappy_month_features_exact():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        root = _tappy_root(Path(tmp))
        df = read_monthly_file(root, "AAAA111111_1607.txt")
        f = month_to_features(df)
        assert f["ht_mean"] == 100.0
        assert f["ft_mean"] == 200.0
        assert f["ikl_mean"] == 300.0
        assert f["backspace_rate"] is None  # never imputed
        assert f["n_keystrokes"] == 7


def test_age_at_session():
    assert age_at_session(1950, "1607") == 66
    assert age_at_session(None, "1607") is None
    assert age_at_session(1950, "xx") is None


def test_load_and_label_drops_unlabeled_subjects():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        root = _tappy_root(Path(tmp))
        users = load_users(root)
        gt = users[users["subject_id"] != "CCCC333333"][
            ["subject_id", "parkinsons_label"]]
        rows = pd.DataFrame([
            {"subject_id": "AAAA111111", "ht_mean": 1.0},
            {"subject_id": "BBBB222222", "ht_mean": 2.0},
            {"subject_id": "CCCC333333", "ht_mean": 3.0},
        ])
        labeled, dropped = load_and_label(rows, gt)
        assert dropped == 1
        assert set(labeled["subject_id"]) == {"AAAA111111", "BBBB222222"}
        assert labeled["parkinsons_label"].tolist() == [1, 0]


def test_nq_key_categorization_and_hand_map():
    assert key_type_for("e") == "character"
    assert key_type_for("space") == "character"
    assert key_type_for("BackSpace") == "backspace"
    assert key_type_for("Shift_L") == "control"
    assert key_type_for("mouse1") == "control"
    assert key_type_for("Return") == "control"
    assert hand_for("f") == "left" and hand_for("j") == "right"
    assert hand_for("space") == "right"  # mirrors live capture default
    assert row_for("q") == 0 and row_for("a") == 1 and row_for("z") == 2


def _nq_file(tmp_path):
    p = tmp_path / "nq.csv"
    lines = ['"e",1401114972.0134,0.0652,-1401114971.9481',
             '"n",0.1194,1.9508,1.8314',
             '"t",0.1337,2.5555,2.4218',
             '"BackSpace",0.0500,3.0000,2.9500',
             '"Shift_L",0.2000,3.5000,3.3000']
    p.write_text("\n".join(lines) + "\n")
    return str(p)


def test_nq_row0_dropped_and_types_tagged():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        events, raw = file_to_events(_nq_file(Path(tmp)))
        assert raw == 5
        kinds = [e["keyType"] for e in events]
        assert kinds.count("character") == 2
        assert kinds.count("backspace") == 1
        assert kinds.count("control") == 1
        chars = [e for e in events if e["keyType"] == "character"]
        assert chars[0]["hand"] == "right"  # n
        assert chars[1]["hand"] == "left"  # t


def test_nq_features_use_pipeline_keys():
    import tempfile
    from utils.constants import TYPING_FEATURE_LIST
    with tempfile.TemporaryDirectory() as tmp:
        f = file_to_features(_nq_file(Path(tmp)))
        for key in TYPING_FEATURE_LIST:
            assert key in f
        assert f["n_keystrokes"] == 2


def test_leakage_assert():
    groups = ["a", "a", "b", "b", "c", "c"]
    assert_no_subject_leakage([0, 1, 4, 5], [2, 3], groups)
    with pytest.raises(AssertionError, match="Subject leakage"):
        assert_no_subject_leakage([0, 1, 2], [2, 3], groups)


def test_subject_folds_cover_each_subject_once():
    rng = np.random.RandomState(0)
    subjects = [f"s{i:02d}" for i in range(12)]
    y, groups = [], []
    for i, s in enumerate(subjects):
        label = i % 2
        for _ in range(3):
            y.append(label)
            groups.append(s)
    folds = subject_grouped_folds(y, groups, n_splits=3, seed=7)
    assert len(folds) == 3
    tested = []
    for train_idx, test_idx in folds:
        tested.extend(np.asarray(groups)[test_idx].tolist())
    assert sorted(set(tested)) == sorted(subjects)
    assert len(tested) == 36  # 12 subjects x 3 sessions, each tested once


def test_lodo_splits_are_source_pure():
    sources = ["tappy", "tappy", "neuroqwerty", "neuroqwerty"]
    splits = leave_one_dataset_out_splits(sources)
    assert len(splits) == 2
    for held_out, train_idx, test_idx in splits:
        assert set(np.asarray(sources)[test_idx]) == {held_out}
        assert held_out not in set(np.asarray(sources)[train_idx])


def test_summarize_metrics_perfect():
    m = summarize_metrics([0, 0, 1, 1], [0.1, 0.2, 0.8, 0.9])
    assert m["roc_auc"] == 1.0
    assert m["confusion"] == {"tn": 2, "fp": 0, "fn": 0, "tp": 2}
    assert (m["n_pos"], m["n_neg"]) == (2, 2)


def test_scalers_fit_train_only():
    rng = np.random.RandomState(1)
    X_train = np.vstack([rng.normal(0, 1, (20, 3)),
                         rng.normal(100, 5, (20, 3))])
    sources = np.array(["a"] * 20 + ["b"] * 20)
    scalers = fit_per_dataset_scalers(X_train, sources, ["f1", "f2", "f3"])
    assert abs(scalers["a"].mean_[0]) < 0.5
    assert abs(scalers["b"].mean_[0] - 100) < 2
    X_test = np.array([[0.0, 0.0, 0.0]])
    out = transform_with_scalers(X_test, ["a"], scalers)
    assert abs(out[0][0]) < 0.5  # transformed with TRAIN stats
    with pytest.raises(KeyError):
        transform_with_scalers(X_test, ["zzz"], scalers)


def test_train_scaler_transform_for_lodo():
    # Held-out rows use the TRAINING source statistics, never their own.
    scalers = fit_per_dataset_scalers(
        np.array([[0.0], [2.0]]), np.array(["a", "a"]), ["f1"])
    out = transform_with_train_scaler(np.array([[10.0]]), scalers)
    assert abs(out[0][0] - 9.0) < 1e-9  # (10 - mean 1) / std 1
    multi = dict(scalers)
    multi["b"] = scalers["a"]
    with pytest.raises(ValueError, match="exactly one"):
        transform_with_train_scaler(np.array([[10.0]]), multi)


def test_train_features_are_the_supported_intersection():
    from models.exp_common import TRAIN_FEATURES
    from utils.constants import TYPING_FEATURE_LIST
    assert "backspace_rate" not in TRAIN_FEATURES  # Tappy lacks it
    assert set(TRAIN_FEATURES) < set(TYPING_FEATURE_LIST)
    assert len(TRAIN_FEATURES) == len(TYPING_FEATURE_LIST) - 1
