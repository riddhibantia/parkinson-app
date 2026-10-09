"""Canonical session contract (spec 14/15/21).

External JSON: camelCase. Python internals: snake_case via aliases.
Finite-numeric validation; malformed data is rejected, never corrected.

Timing units: MILLISECONDS everywhere (performance.now basis, spec 7).
Legacy Flutter wire used microseconds; use `events_us` adapter path only
for back-compat ingestion, converted explicitly once.
"""

from __future__ import annotations

import math
from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class CamelModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)


class KeystrokeEventIn(CamelModel):
    """One key event. Timestamps in MILLISECONDS (monotonic clock)."""

    press_timestamp: float = Field(alias="pressTimestamp")
    release_timestamp: float = Field(alias="releaseTimestamp")
    hand: Literal["left", "right"] = "right"
    row: int = 1
    key_type: Literal["character", "backspace", "control"] = Field(
        default="character", alias="keyType"
    )

    @field_validator("press_timestamp", "release_timestamp")
    @classmethod
    def _finite(cls, v: float) -> float:
        if not math.isfinite(float(v)):
            raise ValueError("timestamp must be finite")
        return float(v)


class MotorTapIn(CamelModel):
    timestamp_ms: float = Field(alias="timestampMs")
    key: str

    @field_validator("timestamp_ms")
    @classmethod
    def _finite_ts(cls, v: float) -> float:
        if not math.isfinite(float(v)):
            raise ValueError("timestamp must be finite")
        return float(v)


SessionType = Literal["structured", "free", "motor_task"]


class SessionIngest(CamelModel):
    """POST /sessions + analysis input. Exactly one session_id per lifecycle."""

    session_id: UUID = Field(alias="sessionId")
    user_id: UUID = Field(alias="userId")
    session_type: SessionType = Field(alias="sessionType")
    device_id: str = Field(alias="deviceId", min_length=1, max_length=256)
    started_at: datetime = Field(alias="startedAt")
    ended_at: datetime = Field(alias="endedAt")
    duration_ms: float = Field(alias="durationMs", gt=0)
    keystroke_count: int = Field(alias="keystrokeCount", ge=0)
    quality_flags: list[str] = Field(default_factory=list, alias="qualityFlags")
    events: list[KeystrokeEventIn] = Field(default_factory=list)
    taps: list[MotorTapIn] = Field(default_factory=list)
    # Pre-extracted features (server-trust path for re-analysis only).
    features: dict[str, float] = Field(default_factory=dict)

    @model_validator(mode="after")
    def _check_time_order(self) -> "SessionIngest":
        if self.ended_at < self.started_at:
            raise ValueError("endedAt must be >= startedAt")
        return self

    @field_validator("features")
    @classmethod
    def _finite_features(cls, v: dict) -> dict:
        for name, value in v.items():
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                raise ValueError(f"feature {name!r} must be numeric")
            if not math.isfinite(float(value)):
                raise ValueError(f"feature {name!r} must be finite")
        return {k: float(x) for k, x in v.items()}


class QualityOut(CamelModel):
    accepted: bool
    reason: str
    flags: list[str] = Field(default_factory=list)


class Layer1Out(CamelModel):
    status: Literal["normal", "watch", "attention", "insufficient_data", "not_applicable"]
    message: str
    # Internal research signal (spec 1.2/9.3): retained for debugging,
    # NEVER presented as a diagnosis or clinical probability in UI.
    pd_probability: float | None = Field(default=None, alias="pdProbability")
    top_contributors: list[dict] | None = Field(default=None, alias="topContributors")


class Layer2Out(CamelModel):
    status: str
    message: str
    baseline_status: Literal["building", "established"] = Field(alias="baselineStatus")
    drift: dict = Field(default_factory=dict)
    anomaly: dict = Field(default_factory=dict)
    anomaly_run: bool = Field(default=False, alias="anomalyRun")


class AnalysisResponse(CamelModel):
    """One session_id in, same session_id out. Two separate result objects."""

    session_id: UUID = Field(alias="sessionId")
    layer1: Layer1Out
    layer2: Layer2Out
