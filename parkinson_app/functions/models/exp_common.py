"""Shared experiment plumbing (Stage 4.4). No model fitting here.

- TRAIN_FEATURES: the harmonized intersection actually available in BOTH
  datasets. backspace_rate is a defined feature but Tappy records no
  backspace events, so it cannot enter the pooled training matrix (plan
  Stage 4.1 intersection rule). Live inference must subset to these same
  columns — enforced by saving them in every experiment's config.
- Fold indices are cached to disk so RF / TabPFN / demographic runs use
  byte-identical splits.
"""

import json
import os

import numpy as np
import pandas as pd

from services.evaluation import subject_grouped_folds
from utils.constants import TYPING_FEATURE_LIST

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HARMONIZED_CSV = os.path.join(BASE, "data", "harmonized",
                              "harmonized_sessions.csv")
EXPERIMENTS_DIR = os.path.join(BASE, "models", "experiments")
REPORTS_DIR = os.path.join(BASE, "reports")

TRAIN_FEATURES = [f for f in TYPING_FEATURE_LIST if f != "backspace_rate"]

N_SPLITS = 5
SEED = 42


def load_training_frame() -> pd.DataFrame:
    df = pd.read_csv(HARMONIZED_CSV)
    return df.dropna(subset=TRAIN_FEATURES).reset_index(drop=True)


def view_mask(df: pd.DataFrame, view: str) -> pd.DataFrame:
    if view == "pooled":
        return df
    if view in ("tappy", "neuroqwerty"):
        return df[df["dataset_source"] == view].reset_index(drop=True)
    raise ValueError(f"Unknown CV view: {view}")


def cached_folds(view: str, y, groups) -> list:
    """Identical splits for every model family. Cached on first build."""
    os.makedirs(EXPERIMENTS_DIR, exist_ok=True)
    path = os.path.join(EXPERIMENTS_DIR, f"folds_{view}.json")
    if os.path.exists(path):
        with open(path) as fh:
            saved = json.load(fh)
        return [(np.array(f["train"]), np.array(f["test"]))
                for f in saved["folds"]]
    folds = subject_grouped_folds(np.asarray(y), np.asarray(groups),
                                  n_splits=N_SPLITS, seed=SEED)
    with open(path, "w") as fh:
        json.dump({
            "view": view,
            "n_splits": N_SPLITS,
            "seed": SEED,
            "folds": [{"train": t.tolist(), "test": e.tolist()}
                      for t, e in folds],
        }, fh)
    return folds


def package_versions() -> dict:
    import sklearn
    import numpy
    import pandas
    import scipy
    import sys
    versions = {
        "python": sys.version.split()[0],
        "scikit-learn": sklearn.__version__,
        "numpy": numpy.__version__,
        "pandas": pandas.__version__,
        "scipy": scipy.__version__,
    }
    try:
        import torch
        versions["torch"] = torch.__version__
        versions["cuda_available"] = torch.cuda.is_available()
    except ImportError:
        versions["torch"] = None
    try:
        import tabpfn
        versions["tabpfn"] = tabpfn.__version__
    except ImportError:
        versions["tabpfn"] = None
    return versions
