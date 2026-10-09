"""Responsibility split (spec 20.1/20.2):
- sessions.py  -> persist + exact retrieval (no analysis).
- analysis.py  -> Layer 1 ONLY or Layer 2 ONLY, or the convenience
                  combined analyze that returns two separate objects.
- baseline.py  -> baseline state + explicit reset.
- insights.py  -> read-only insight views over persisted rows.
- health.py    -> artifact verification + dependency status.
"""

from fastapi import APIRouter

from app.api.v1.endpoints import analysis, baseline, health, insights, sessions

router = APIRouter()
router.include_router(health.router, tags=["health"])
router.include_router(sessions.router, tags=["sessions"])
router.include_router(analysis.router, tags=["analysis"])
router.include_router(baseline.router, tags=["baseline"])
router.include_router(insights.router, tags=["insights"])
