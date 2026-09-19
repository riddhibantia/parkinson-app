"""Build the pooled harmonized dataset (Stage 4.1, offline, run once).

Reads the raw PhysioNet downloads, writes:
  data/harmonized/harmonized_sessions.csv   pooled feature rows
  data/harmonized/feature_schema.json       frozen column/feature contract
  data/harmonized/harmonization_report.json counts, filters, provenance

No model fitting. Run: python models/build_harmonized.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))

from services.harmonize_datasets import (  # noqa: E402
    build_pooled,
    save_artifacts,
)

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> None:
    tappy_root = os.path.join(BASE, "data", "tappy_dataset")
    nq_root = os.path.join(BASE, "data", "neuroqwerty_dataset", "nq")
    out_dir = os.path.join(BASE, "data", "harmonized")

    print("Building Tappy rows ...")
    print("Building neuroQWERTY rows ...")
    pooled, report = build_pooled(tappy_root, nq_root)
    save_artifacts(pooled, report, out_dir)

    print(json.dumps(report, indent=2, default=str))
    print(f"Saved {len(pooled)} rows -> {out_dir}")


if __name__ == "__main__":
    main()
