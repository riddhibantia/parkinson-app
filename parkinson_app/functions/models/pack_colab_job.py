"""Pack the Colab fine-tuning job (Stage 4.4 experiment C).

Outputs (in functions/models/colab/):
  colab_bundle.zip           everything the notebook needs (code + CSV)
  tabpfn_finetune_colab.ipynb  upload to Colab, set T4 GPU, Run all

Run: python models/pack_colab_job.py
"""

import json
import os
import zipfile

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(BASE, "models", "colab")

BUNDLE_FILES = [
    ("models/train_tabpfn_finetuned.py", "train_tabpfn_finetuned.py"),
    ("models/exp_common.py", "models/exp_common.py"),
    ("services/evaluation.py", "services/evaluation.py"),
    ("utils/constants.py", "utils/constants.py"),
    ("data/harmonized/harmonized_sessions.csv", "harmonized_sessions.csv"),
]

NOTEBOOK_CELLS = [
    ("markdown",
     "# Stage 4.4C — Fine-tuned TabPFN v2 (adaptation experiment)\n"
     "1. Runtime → Change runtime type → **T4 GPU** (required).\n"
     "2. Runtime → Run all. When prompted, upload `colab_bundle.zip`.\n"
     "3. At the end, download the two result files and hand them back."),
    ("code", "!pip install -q \"tabpfn==9.0.0\" pandas scikit-learn joblib"),
    ("code",
     "import torch\n"
     "assert torch.cuda.is_available(), 'Enable a GPU runtime first!'\n"
     "print(torch.cuda.get_device_name(0))"),
    ("code",
     "from google.colab import files\n"
     "uploaded = files.upload()  # <-- upload colab_bundle.zip here"),
    ("code",
     "import zipfile, glob\n"
     "zpath = glob.glob('/content/colab_bundle*.zip')[0]\n"
     "with zipfile.ZipFile(zpath) as z:\n"
     "    z.extractall('/content/job')\n"
     "!ls -R /content/job | head -20"),
    ("code",
     "!cd /content/job && python train_tabpfn_finetuned.py "
     "--data harmonized_sessions.csv --out ./tabpfn_finetuned "
     "--device cuda --epochs 30 --model-version v2"),
    ("code",
     "from google.colab import files\n"
     "files.download('/content/job/tabpfn_finetuned/finetuned_results.json')\n"
     "files.download('/content/job/tabpfn_finetuned/probabilities_pooled.csv')"),
]


def make_cell(kind, source):
    if kind == "markdown":
        return {"cell_type": "markdown", "metadata": {},
                "source": source.splitlines(keepends=True)}
    return {"cell_type": "code", "metadata": {},
            "execution_count": None, "outputs": [],
            "source": source.splitlines(keepends=True)}


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    bundle_path = os.path.join(OUT_DIR, "colab_bundle.zip")
    with zipfile.ZipFile(bundle_path, "w",
                         compression=zipfile.ZIP_DEFLATED) as bundle:
        for src_rel, arc_name in BUNDLE_FILES:
            src = os.path.join(BASE, src_rel)
            if not os.path.exists(src):
                raise FileNotFoundError(src)
            bundle.write(src, arc_name)
    print(f"bundle: {bundle_path}")

    notebook = {
        "nbformat": 4,
        "nbformat_minor": 5,
        "metadata": {"kernelspec": {"name": "python3",
                                    "display_name": "Python 3"}},
        "cells": [make_cell(kind, src) for kind, src in NOTEBOOK_CELLS],
    }
    nb_path = os.path.join(OUT_DIR, "tabpfn_finetune_colab.ipynb")
    with open(nb_path, "w") as fh:
        json.dump(notebook, fh, indent=1)
    print(f"notebook: {nb_path}")


if __name__ == "__main__":
    main()
