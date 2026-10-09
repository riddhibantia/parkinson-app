"""ParkinTrace FastAPI application (spec 20).

Typing-pattern screening & longitudinal monitoring.
Research aid — not a diagnostic medical device.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import router as v1_router

import os

app = FastAPI(
    title="ParkinTrace API",
    description=("Typing-based motor-pattern screening (Layer 1, RF) and "
                 "longitudinal monitoring (Layer 2, CUSUM/EWMA/IF). "
                 "Research aid; not a diagnostic device."),
    version="0.1.0",
)

# Browser access: explicit origins only (spec 33). Production must set
# PARKINTRACE_CORS_ORIGINS to the real frontend origin(s); localhost
# entries exist for local development only and are NOT a wildcard.
_cors_env = os.environ.get("PARKINTRACE_CORS_ORIGINS", "")
_origins = [o.strip() for o in _cors_env.split(",") if o.strip()] or [
    "http://localhost:3000",
    "http://localhost:3111",
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["content-type", "authorization"],
)

app.include_router(v1_router, prefix="/api/v1")


@app.get("/")
def root() -> dict:
    return {"service": "parkintrace", "docs": "/docs",
            "health": "/api/v1/health"}
