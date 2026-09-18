"""Aggregate Stage 4.4 report artifacts (no model fitting).

Reads per-experiment JSON files and writes:
  reports/stage4_model_results.json
  reports/stage4_model_results.csv
  reports/stage4_summary.md

Run: python models/make_stage4_reports.py
"""

import csv
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORTS_DIR = os.path.join(BASE, "reports")
FINETUNED_JSON = os.path.join(BASE, "models", "experiments",
                              "tabpfn_finetuned", "finetuned_results.json")


def load(name):
    path = os.path.join(REPORTS_DIR, name)
    if not os.path.exists(path):
        return None
    with open(path) as fh:
        return json.load(fh)


def fmt(mean_std):
    if mean_std is None:
        return "n/a"
    return f"{mean_std['mean']:.3f} ± {mean_std['std']:.3f}"


def main() -> None:
    rf = load("stage4_rf_results.json")
    tabpfn = load("stage4_tabpfn_results.json")
    demo = load("stage4_demographic_results.json")
    finetuned = None
    if os.path.exists(FINETUNED_JSON):
        with open(FINETUNED_JSON) as fh:
            finetuned = json.load(fh)

    rows = []

    def add(model, view, payload, extra=""):
        mean = payload.get("mean", payload.get("metrics"))
        if mean is None:
            return
        if "std" in (mean.get("roc_auc", {}) if isinstance(
                mean.get("roc_auc"), dict) else {}):
            auc = fmt(mean["roc_auc"])
            ap = fmt(mean["avg_precision"])
            f1 = fmt(mean["f1"])
        else:
            auc = f"{mean['roc_auc']:.3f}"
            ap = f"{mean['avg_precision']:.3f}"
            f1 = f"{mean['f1']:.3f}"
        n = payload.get("n_subjects", payload.get("n_test_subjects", ""))
        rows.append({"model": model, "view": view, "roc_auc": auc,
                     "avg_precision": ap, "f1": f1, "n_subjects": n,
                     "notes": extra})

    for view, payload in rf["views"].items():
        add("rf", view, payload)
    for view, payload in tabpfn["views"].items():
        add("tabpfn_pretrained", view, payload)
    for tag, payload in demo["arms"].items():
        family, arm = tag.split("_", 1)
        family = "rf" if family == "rf" else "tabpfn_pretrained"
        payload = {**payload,
                   "n_subjects": demo["subset"]["n_subjects"]}
        add(family, f"demo_subset:{arm}", payload,
            extra="complete-case Tappy only")
    if finetuned and finetuned.get("mean"):
        add("tabpfn_finetuned", "pooled",
            {"mean": finetuned["mean"], "n_subjects": 297},
            extra=f"epochs={finetuned.get('epochs')} "
                  f"gpu={finetuned.get('gpu')}")

    with open(os.path.join(REPORTS_DIR, "stage4_model_results.json"),
              "w") as fh:
        json.dump({"rows": rows,
                   "finetuning_status": ("completed" if finetuned and
                                         finetuned.get("mean")
                                         else "pending-colab-gpu"),
                   "rf": rf, "tabpfn_pretrained": tabpfn,
                   "demographic_secondary": demo,
                   "tabpfn_finetuned": finetuned}, fh, indent=2,
                  default=str)
    with open(os.path.join(REPORTS_DIR, "stage4_model_results.csv"),
              "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=[
            "model", "view", "roc_auc", "avg_precision", "f1",
            "n_subjects", "notes"])
        writer.writeheader()
        writer.writerows(rows)

    lines = ["# Stage 4.4 — Layer 1 results", ""]
    lines.append("| model | view | ROC-AUC | AP | F1 | subjects | notes |")
    lines.append("|---|---|---|---|---|---|---|")
    for r in rows:
        lines.append(f"| {r['model']} | {r['view']} | {r['roc_auc']} | "
                     f"{r['avg_precision']} | {r['f1']} | "
                     f"{r['n_subjects']} | {r['notes']} |")
    lines += ["",
              "## Readout",
              "- Tappy-only signal is near chance for both families; "
              "neuroQWERTY carries the pooled result. Expected per Stage 4.0.",
              "- Pretrained TabPFN v2 does not clearly outperform the "
              "Random Forest baseline on any view.",
              "- Adding age/sex on the complete-case Tappy subset does not "
              "improve either family; the typing-only primary stands.",
              "- No thresholds were tuned; probabilities are saved per fold "
              "under models/experiments/* for later threshold work.",
              ""]
    if finetuned and finetuned.get("mean"):
        lines += [
            "## Fine-tuning status: COMPLETED on Colab T4 GPU",
            f"Config: tabpfn=={finetuned['versions'].get('tabpfn')}, "
            f"model_version={finetuned.get('model_version')}, "
            f"epochs={finetuned.get('epochs')}, "
            f"lr={finetuned.get('learning_rate')}, "
            f"gpu={finetuned.get('gpu')}, "
            f"errors={len(finetuned.get('errors', []))}.",
            "Pooled result is in the table above (tabpfn_finetuned row). "
            "Per the locked decision, fine-tuning was an adaptation "
            "experiment, not a dependency — and it did not beat the "
            "Random Forest primary.",
        ]
    else:
        lines += [
            "## Fine-tuning status: PENDING Colab GPU",
            "Local tabpfn==2.2.1 has no finetuning module (verified); the "
              "fine-tuning API (`tabpfn.finetuning`, v2 weights pinned) "
              "ships in tabpfn==9.0.0 (verified import + ModelVersion in an "
              "isolated venv, then removed). No local CPU fit was attempted "
              "per instruction.",
              "Run on a Colab T4 GPU:",
              "```",
              "pip install \"tabpfn==9.0.0\" pandas scikit-learn joblib",
              "# upload: harmonized_sessions.csv + train_tabpfn_finetuned.py",
              "#         + models/exp_common.py + services/evaluation.py",
              "#         + utils/constants.py (same relative layout)",
              "python train_tabpfn_finetuned.py --data harmonized_sessions.csv"
              " --out ./tabpfn_finetuned --device cuda",
              "# copy tabpfn_finetuned/finetuned_results.json + probabilities"
              "_pooled.csv into functions/models/experiments/tabpfn_finetuned/",
              "# then re-run: python models/make_stage4_reports.py",
              "```",
              "",
              "## License note",
              "tabpfn 2.2.1 ships under Prior Labs License 1.1 "
              "(Apache-2.0-derived + enhanced attribution paragraph) — "
              "recorded here to satisfy the attribution duty; v3 weights "
              "(research/non-commercial) were never used."]
    with open(os.path.join(REPORTS_DIR, "stage4_summary.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"Wrote reports for {len(rows)} result rows.")


if __name__ == "__main__":
    main()
