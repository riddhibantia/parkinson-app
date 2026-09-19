# ParkinTrace — Keystroke-Dynamics Based Parkinson's Screening & Longitudinal Monitoring System

> **Academic Research Project** — Submitted in partial fulfillment of degree requirements.  
> This repository is maintained for academic evaluation and demonstration purposes. It is **not** an open-source product and is **not licensed for public distribution or commercial use**.

---

## Abstract

**ParkinTrace** is a desktop application for research-oriented screening and longitudinal monitoring of Parkinson's-related motor signatures through passive keystroke dynamics. The system analyses typing timing — hold time, flight time, inter-key latency, and consistency — **never the typed content** — to identify (a) population-level deviations and (b) personalized drift over time.

The project implements a **two-layer architecture**: **Layer 1** performs population comparison using models trained on harmonized public research datasets (Tappy & neuroQWERTY); **Layer 2** builds a personal baseline and applies statistical drift detection (CUSUM/EWMA) and anomaly detection (Isolation Forest) to track changes across sessions. All outputs are framed as *research signals* — the system does not provide a medical diagnosis and always recommends clinician follow-up for unusual patterns.

---

## 1. Research Objectives

1.  Investigate keystroke timing as a low-burden, passive signal for Parkinson's-related motor monitoring.
2.  Harmonize heterogeneous public datasets into a unified feature space for cross-dataset evaluation.
3.  Evaluate classical (Random Forest) and tabular foundation (TabPFN) models for population-level screening.
4.  Design a personalized longitudinal monitoring pipeline that adapts to an individual's typing baseline.
5.  Deliver a privacy-preserving desktop application with secure, owner-scoped data storage and reproducible evaluation.

---

## 2. System Architecture

### 2.1 High-Level Architecture

```mermaid
flowchart TB
    subgraph Client["Flutter Desktop App (Riverpod + GoRouter)"]
        A1[Structured / Free Typing] --> A2[Keystroke Capture\npress/release timestamps + hand mapping]
        A2 --> A3[Local Feature Extraction\nht_mean, ft_mean, ikl, consistency,\nasymmetry, pauses]
        A3 --> A4[Immediate Offline Feedback\nLayer 1 Result Card]
    end

    subgraph Backend["Firebase Backend"]
        B1["Firestore\nusers/{uid}/sessions"]
        B2["Firestore\nusers/{uid}/results"]
        B3["Firestore\nusers/{uid}/baselines/current"]
        B4["Storage\nanomaly_models/{uid}/isolation_forest.joblib"]
        B5["Cloud Functions 2nd Gen\nPython"]
    end

    subgraph Pipeline["Single Analysis Pipeline\nfunctions/services/pipeline.py"]
        P1[Feature Extraction]
        P2[Layer 1: Population Screening\nRF / TabPFN → pd_probability]
        P3[Layer 2: Personal Monitoring\nCUSUM/EWMA + Isolation Forest]
        P4[SHAP Explanation\nasync via fill_shap_explanation]
    end

    A3 -->|saveSession| B1
    B1 -->|onCreate trigger| B5
    B5 --> P1 --> P2 --> P3
    P2 -.->|async| P4
    P2 --> B2
    P3 --> B3
    P3 --> B4
    B2 -->|watch| Client
    B3 -->|watch| Client
```

### 2.2 Client-Side Flow

```mermaid
flowchart LR
    subgraph Splash["Splash Screen"]
        S1[ParkinTrace Logo + BEGIN]
    end

    subgraph Auth["Authentication"]
        A1[Not Signed In] --> A2[Login Screen]
        A2 --> A3[Email/Password or Google]
        A3 --> A4[Signed In]
    end

    subgraph Onboarding["Onboarding (once per user)"]
        O1[How It Works + Consent] --> O2[Typing Experience]
        O2 --> O3[Demographics]
        O3 --> O4[Context Profile]
        O4 --> O5[Layer Selection]
        O5 --> O6{Choose Mode}
        O6 -->|Layer 1| O7[Quick Analysis]
        O6 -->|Layer 2| O8[Personal Monitoring]
    end

    subgraph Main["Main App (AppShell - 4 tabs)"]
        M1[🏠 Home / Dashboard]
        M2[⌨️ Type\nStructured / Free / Motor Task]
        M3[📊 Insights\nLayer 1 / Layer 2 / History]
        M4[👤 Profile / Settings]
    end

    S1 -->|tap BEGIN| A1
    A4 -->|hasOnboarded?| O1
    A4 -->|onboarded| M1
    O7 -->|setCompleted| M1
    O8 -->|setCompleted| M1
    M2 -->|Session Complete| M3
```

---

## 3. Data Flow & Pipeline

### 3.1 End-to-End Data Pipeline

```mermaid
flowchart TD
    %% Data Sources
    D1["Tappy Dataset\n(PhysioNet)"]
    D2["neuroQWERTY Dataset\n(MIT / Research)"]
    
    %% Harmonization
    H1["build_harmonized.py"]
    H2["harmonized_sessions.csv"]
    H3["feature_schema.json"]
    
    %% Model Training
    M1["run_rf.py\nRandom Forest"]
    M2["run_tabpfn.py\nTabPFN"]
    M3["train_tabpfn_finetuned.py"]
    M4["live_scaler.json"]
    M5["experiments/probabilities_*.csv"]
    M6["experiments/folds_*.json"]
    M7["stage4_* reports"]
    
    %% Pipeline Services
    P1["feature_extraction.py\nHT, FT, IKL, Speed, Asymmetry, Pauses"]
    P2["pipeline.py\nSingle analysis entry point"]
    P3["layer1_screening.py\nRF/TabPFN inference → pd_probability"]
    P4["familiarization.py\nGate first N sessions"]
    P5["baseline_builder.py\nFreeze after 10 sessions / 5 days"]
    P5a["baselines/current\nmedian, MAD, mean, std per feature"]
    P6["layer2_drift.py\nCUSUM/EWMA per-feature robust-Z"]
    P7["layer2_anomaly.py\nIsolation Forest per user"]
    P7a["anomaly_models/{uid}/isolation_forest.joblib"]
    P8["explain.py\nSHAP top-contributors"]
    P9["quality_filter.py\nSession quality flags"]
    P10["device_guard.py\nKeyboard consistency check"]
    
    %% Triggers
    T1["onCreate users/{uid}/sessions/{id}\n→ run_analysis"]
    T2["onCreate users/{uid}/results/{id}\n→ fill_shap_explanation"]
    T3["callable submit_session\nvalidate + persist"]
    T4["callable get_dashboard / reset_baseline"]

    %% Connections
    D1 --> H1
    D2 --> H1
    H1 --> H2
    H1 --> H3
    H2 --> M1
    H2 --> M2
    H2 --> M3
    M1 --> M4
    M2 --> M4
    M3 --> M4
    M4 --> M5
    M4 --> M6
    M4 --> M7
    
    P1 -.->|mirror| P1_Client["lib/data/services/\nlocal_analysis_service.dart"]
    P2 --> P1
    P2 --> P3
    P2 --> P4
    P2 --> P5
    P2 --> P6
    P2 --> P7
    P3 --> P8
    P5 --> P5a
    P7 --> P7a
    
    T1 --> P2
    T2 --> P8
    T3 --> P9
    T4 --> P5a
    T4 --> P7a
```

### 3.2 Session Processing Flow (Layer 1 & Layer 2)

```mermaid
flowchart TD
    Start([New Typing Session\nStructured / Free / Motor Task]) --> Capture[Keystroke Capture\npress_ts, release_ts, key, hand]
    Capture --> Validate[quality_filter.py\nkeystroke_count, duration, flags]
    Validate -->|fail| Reject[Reject / Request Retry]
    Validate -->|pass| Extract[feature_extraction.py\nHT, FT, IKL, Speed, Asymmetry, Pauses, Consistency]
    
    Extract --> Familiarization{familiarization.py\nsufficient experience?}
    Familiarization -->|no| FamiliarizationSessions[Familiarization Sessions\nnot used for analysis]
    Familiarization -->|yes| Layer1[layer1_screening.py\nRF / TabPFN inference]
    
    Layer1 --> Probability[pd_probability: 0.0 - 1.0]
    Probability --> Status1{Status Threshold}
    Status1 -->|< 0.33| Normal1[Normal / Within Range]
    Status1 -->|0.33 - 0.66| Watch1[Watch / Deviated]
    Status1 -->|> 0.66| Attention1[Attention / Distinctly Different]
    
    Layer1 --> SHAP[fill_shap_explanation\nasync SHAP top-contributors]
    Layer1 -->|save| Results["Firestore\nusers/{uid}/results/{id}"]
    
    Extract --> Layer2{Layer 2 Active?}
    Layer2 -->|no| End([Layer 1 Complete])
    Layer2 -->|yes| Baseline{baseline_exists?}
    
    Baseline -->|no| BuildBaseline[baseline_builder.py\nAccumulate sessions]
    BuildBaseline --> Count{screening_count ≥ 10\nacross ≥ 5 days?}
    Count -->|no| End
    Count -->|yes| Freeze[Freeze baseline\nmedian, MAD per feature]
    
    Baseline -->|yes| Drift[layer2_drift.py\nCUSUM + EWMA per feature\nrobust-Z vs baseline]
    Drift --> Anomaly[layer2_anomaly.py\nIsolation Forest score]
    Anomaly --> Device[device_guard.py\nSame keyboard?]
    Device --> Status2{Overall Status}
    Status2 -->|all normal| Normal2[Within Personal Range]
    Status2 -->|some elevated| Watch2[Watch / Some Change]
    Status2 -->|persistent shift| Attention2[Attention / Sustained Change]
    
    Drift -->|save| BaselineDoc["Firestore\nusers/{uid}/baselines/current"]
    Anomaly -->|save| ModelBlob["Storage\nanomaly_models/{uid}/\nisolation_forest.joblib"]
    Status2 -->|save| Results
    
    FamiliarizationSessions --> End
    Freeze --> End
```

---

## 4. Firestore & Storage Data Model

```mermaid
erDiagram
    USERS ||--o{ SESSIONS : "has"
    USERS ||--o| BASELINES : "has"
    USERS ||--o{ RESULTS : "has"
    USERS ||--o| MODEL_BLOB : "has"
    USERS ||--o{ REFERENCE : "reads"

    USERS {
        string uid PK
        string email
        string displayName
        map profileContext
        map demographics
        map parkinsonContext
        timestamp createdAt
        boolean hasOnboarded
        string analysisMode "layer1 | layer2"
    }

    SESSIONS {
        string sessionId PK
        string uid FK
        string mode "structured|free|motor_task"
        string phase "familiarization|screening"
        timestamp startTime
        timestamp endTime
        int totalKeystrokes
        int durationSec
        array events "KeystrokeEvent[]"
        string deviceId
        map metadata
        array qualityFlags
    }

    BASELINES {
        string docId "current"
        map features "per-feature: median, mad, mean, std, count"
        int sessionCount
        timestamp frozenAt
        array deviceIds
    }

    RESULTS {
        string resultId PK
        string sessionId FK
        map layer1 "pd_probability, status, message, top_contributors"
        map layer2 "drift_result: drift_signals, anomaly_score, confidence"
        string shap_status "pending|complete|unavailable"
        timestamp timestamp
    }

    MODEL_BLOB {
        string path "anomaly_models/{uid}/isolation_forest.joblib"
        bytes blob "scikit-learn IsolationForest pickle"
        timestamp updatedAt
    }

    REFERENCE {
        string docId
        map populationStats "per-feature median, mad"
        map modelMetadata "version, training_date, datasets"
    }
```

### 4.2 Security Rules Summary

```mermaid
flowchart LR
    subgraph Firestore["firestore.rules"]
        F1["users/{uid}/sessions/*\nallow read, write: if isOwner(uid)"]
        F2["users/{uid}/results/*\nallow read, write: if isOwner(uid)"]
        F3["users/{uid}/baselines/*\nallow read, write: if isOwner(uid)"]
        F4["reference/**\nallow read: if request.auth != null\nallow write: if false"]
    end

    subgraph Storage["storage.rules"]
        S1["anomaly_models/{uid}/*\nallow read, write: if request.auth != null\n&& request.auth.uid == uid"]
    end

    Note["isOwner(uid): request.auth != null && request.auth.uid == uid"]
```

---

## 5. Cloud Functions Trigger Graph

```mermaid
flowchart TD
    %% Entry Points
    E1["callable: submit_session\nvalidate + persist session"]
    E2["trigger: users/{uid}/sessions/{id}.onCreate\nrun_analysis"]
    E3["trigger: users/{uid}/results/{id}.onCreate\nfill_shap_explanation"]
    E4["callable: get_dashboard\nreturn latest result + baseline"]
    E5["callable: reset_baseline\ndelete baseline + model blob"]

    %% Pipeline
    P["pipeline.py\nSingle analysis entry point"]

    %% Services
    S1["feature_extraction.py"]
    S2["quality_filter.py"]
    S3["familiarization.py"]
    S4["layer1_screening.py"]
    S5["baseline_builder.py"]
    S6["layer2_drift.py"]
    S7["layer2_anomaly.py"]
    S8["explain.py"]
    S9["device_guard.py"]

    %% Persistence
    DB1["Firestore\nusers/{uid}/sessions"]
    DB2["Firestore\nusers/{uid}/results"]
    DB3["Firestore\nusers/{uid}/baselines/current"]
    ST1["Storage\nanomaly_models/{uid}/isolation_forest.joblib"]

    %% Connections
    E1 -->|save| DB1
    DB1 -.->|onCreate| E2
    E2 --> P
    P --> S1
    S1 --> S2
    S2 --> S3
    S3 --> S4
    S4 -->|pd_probability| DB2
    S4 -->|async| S8
    S8 -->|top_contributors| DB2
    S3 --> S5
    S5 -->|baseline ready| DB3
    S5 --> S6
    S6 --> S7
    S7 -->|model blob| ST1
    S7 --> DB2
    S9 -.->|keyboard check| S5
    S9 -.->|keyboard check| S6

    E3 -.->|onCreate| S8
    E4 -->|read| DB2
    E4 -->|read| DB3
    E5 -->|delete| DB3
    E5 -->|delete| ST1
```

---

## 6. Repository Structure

```mermaid
flowchart TB
    ROOT["Parkinson Project (repo root)"]
    
    subgraph Flutter["lib/ — Flutter Desktop App"]
        F1["core/\nrouter, theme, layout, providers"]
        F2["data/\nmodels, repositories, REST service"]
        F3["features/\nauth, onboarding, dashboard,\ntyping_test, profile, splash, info"]
        F4["shared/\ndesign system, glass cards, logo"]
        F5["main.dart, app.dart,\nfirebase_options.dart"]
    end
    
    subgraph Functions["functions/ — Cloud Functions (Python)"]
        FN1["main.py\nthin handler entry points"]
        FN2["services/\npipeline, feature_extraction,\ndrift, anomaly, SHAP, familiarization,\nquality_filter, device_guard, baseline"]
        FN3["models/\ntraining scripts, experiments/\nfrozen artifacts, harmonized data"]
        FN4["tests/\npytest suite"]
        FN5["requirements.txt\n(scikit-learn, pandas, SHAP — no torch/tabpfn)"]
    end
    
    subgraph Config["Configuration & Assets"]
        C1["firebase.json"]
        C2["firestore.rules"]
        C3["storage.rules"]
        C4["pubspec.yaml / pubspec.lock"]
        C5["analysis_options.yaml"]
        C6["assets/prompts/neutral_sentences.json"]
        C7[".gitignore"]
    end
    
    subgraph Docs["doc/"]
        D1["implementation_plan_parkinson_personalized_v6.md\nsource of truth (stages 1-10)"]
    end

    ROOT --> Flutter
    ROOT --> Functions
    ROOT --> Config
    ROOT --> Docs
```

---

## 7. Methodology

### 7.1 Datasets

| Dataset | Source | Description |
|---------|--------|-------------|
| **Tappy Keystroke** | PhysioNet | Controlled typing tasks with labelled PD / control subjects |
| **neuroQWERTY** | MIT / Research release | In-the-wild typing with clinical labels |

Both datasets are harmonized via `functions/models/build_harmonized.py` into `functions/data/harmonized/harmonized_sessions.csv` with a unified `feature_schema.json`. Raw downloads (`keystrokes/`, `users/`, `nq/`) and `*.zip` archives are excluded from version control and documented as reproducible downloads.

### 7.2 Feature Engineering

For each session, timing features are extracted from character keystrokes only: hold time (HT), flight time (FT), inter-key latency (IKL), typing speed, left/right hand asymmetry, pause frequency, and session consistency. Content is never stored. See `functions/services/feature_extraction.py` and the client mirror `lib/data/services/local_analysis_service.dart` (used for immediate offline feedback).

### 7.3 Layer 1 — Population Screening

*   Models: **Random Forest** (baseline, ~15 s training) and **TabPFN** (tabular foundation model; fine-tuning via Colab GPU).
*   Training scripts: `functions/models/run_rf.py`, `run_tabpfn.py`, `train_tabpfn_finetuned.py`.
*   Frozen evaluation artifacts live in `functions/models/experiments/` (probabilities, folds, `live_scaler.json`, `stage4_*` reports).
*   Output per session: `pd_probability` (0-1), `status` (normal / watch / attention), `message`, `top_contributors` (SHAP, async).

### 7.4 Layer 2 — Personal Longitudinal Monitoring

*   Familiarization handling (`functions/services/familiarization.py`) gates the first N sessions by typing experience.
*   Baseline construction (`functions/services/baseline_builder.py`): frozen after 10 screening sessions across ≥ 5 days.
*   Drift detection (`functions/services/layer2_drift.py`): CUSUM and EWMA per-feature robust-Z against the baseline.
*   Anomaly detection (`functions/services/layer2_anomaly.py`): per-user Isolation Forest, persisted to `anomaly_models/{uid}/isolation_forest.joblib`.
*   Device guard (`functions/services/device_guard.py`) ensures baseline stability across keyboards.

---

## 8. Technology Stack

| Layer | Technology |
|-------|------------|
| **Application** | Flutter 3.9 (Dart), Riverpod, GoRouter, Material 3 |
| **Visualisation** | fl_chart |
| **Backend** | Firebase Auth, Cloud Firestore, Cloud Storage, Cloud Functions (Python 2nd gen) |
| **ML / Analysis** | scikit-learn, SHAP, TabPFN (PyTorch), pandas / NumPy |
| **Testing** | `flutter_test` (34 tests), `pytest` (57 tests), `flutter analyze` |
| **Platform** | Windows / macOS / Linux desktop; Web build supported |

---

## 9. Setup & Reproduction

### 9.1 Prerequisites

*   Flutter SDK ≥ 3.9, Dart ≥ 3.9
*   Python 3.10+ (for Cloud Functions / model reproduction)
*   Firebase CLI (`npm i -g firebase-tools`) and a Firebase project (e.g. `parkinson-app-rbt`)

### 9.2 Application

```bash
flutter pub get
flutter run -d windows    # or macos / linux / chrome
flutter run -d chrome     # Web (no Android NDK / Gradle required)
```

### 9.3 Cloud Functions & Model Tests

```bash
cd functions
pip install -r requirements.txt
pytest -q                 # 57 passed

# Full verification from repo root:
flutter analyze lib test  # 0 issues
flutter test              # 34 passed
flutter build web         # √ Built build/web
```

Heavy training dependencies (`torch`, `tabpfn`) are excluded from `functions/requirements.txt` by design (size + Colab-GPU workflow). SHAP is optional at runtime — absence degrades `shap_status` to `unavailable` without breaking the pipeline.

### 9.4 Firebase Configuration

```bash
flutterfire configure                  # regenerates lib/firebase_options.dart
firebase deploy --only firestore:rules,storage
firebase deploy --only functions       # requires Blaze plan
```

Firestore and Storage rules enforce **owner-only** access: `users/{uid}/sessions`, `baselines`, `results`, and `anomaly_models/{uid}/*`. Reference data (`reference/**`) is read-only for authenticated users.

---

## 10. Results & Visualisation

*   **Layer 1 Result** (`/insights/layer1`): model probability, interpretation, per-feature values, interactive bar chart (metric switcher), and a line chart of hold time over elapsed time.
*   **Layer 2 Result** (`/insights/layer2` + `/session/layer2/:id`): baseline progress, current status, per-session metrics, interpretation, and a diagrammatic line chart (real history when ≥ 2 sessions, illustrative preview otherwise).
*   **Insights** (`/insights`) is mode-aware and mirrors the latest Layer 1 result in place when that mode is active.
*   **Dashboard** is driven by `functions/models/experiments/` frozen artifacts for deterministic evaluation; reports in `functions/reports/stage4_*`.

---

## 11. Ethics, Privacy & Limitations

*   **Not a medical device.** Every result screen carries an explicit disclaimer: *"This is a research monitoring signal and not a medical diagnosis."*
*   **Content never analysed.** Only key-press timing is processed; typed text is not stored or used as a feature.
*   **Data minimisation.** Demographic and health-context fields are optional, used only for model stratification, and do not affect core typing features.
*   **Security.** No private credentials are committed (see `.gitignore` — `.env`, `*.pem`, service-account JSON excluded). Firebase API keys in `firebase_options.dart` / `google-services.json` are public client identifiers.
*   **Limitations.** Cross-subject generalisation is modest; personal monitoring requires 10 sessions across 5 days on a consistent keyboard; results reflect typing behaviour, not clinical status.

---

## 12. Future Work

Personalised threshold calibration, longitudinal study integration, accessibility evaluation for diverse keyboards, and prospective validation against clinical assessment.

---

## 13. References

*   Tappy Keystroke Dataset — PhysioNet.
*   neuroQWERTY Dataset — MIT / Research release.
*   TabPFN — Hollmann et al., *Accurately Modeling Tabular Data*.
*   Isolation Forest — Liu et al., ICDM 2008.
*   CUSUM / EWMA — standard statistical process control literature.

---

## Authors & Supervision

*   **Author:** Riddhi Bantia — `riddhibantia@gmail.com` — [github.com/riddhibantia](https://github.com/riddhibantia)
*   **Academic Supervisor:** *To be listed as per institutional submission*
*   **Institution / Programme:** *Academic project — details per submission cover page*

For evaluation queries, please contact the author or supervisor directly.

## Licence & Use

© 2026 Riddhi Bantia. **All rights reserved.**

This repository is shared solely for **academic evaluation and demonstration**. No licence is granted for reproduction, distribution, or commercial use. No open-source licence (e.g. MIT/Apache/GPL) applies. Any use beyond academic review requires prior written permission from the author.

---

*Last updated: September 2026 · `flutter analyze` 0 issues · `flutter test` 34 passed · `pytest` 57 passed*