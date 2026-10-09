# ParkinTrace backend (FastAPI)

Typing-pattern screening (Layer 1, RF) + longitudinal monitoring
(Layer 2, CUSUM/EWMA/Isolation Forest). Research aid — not a device.

## Run

```bash
cd backend
pip install -r requirements.txt   # pins scikit-learn==1.6.1 (artifact compat)
pytest -q
uvicorn app.main:app --reload
```

## Env (server-side only — never expose to the browser)

```bash
SUPABASE_URL=...
SUPABASE_ANON_KEY=...            # browser-safe only
SUPABASE_SERVICE_KEY=...         # server only, never commit
PARKINTRACE_RF_ARTIFACT=...      # override; default = legacy repo artifact
PARKINTRACE_RF_SCALER=...
```

See `.env.example`. `/api/v1/health` reports artifact status fail-closed:
`degraded` disables live Layer 1 inference instead of substituting.
