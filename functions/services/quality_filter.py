"""Session quality filtering (Stage 2.6 / 6.2).

Rejects sessions that are too short or too sparse before any feature or
analysis work. Familiarization sessions are stored for history/readiness
only and are never eligible for Layer 1/Layer 2 analysis — enforced here
as a hard gate shared by all analysis entry points.
"""

from utils.constants import MIN_KEY_EVENTS, MIN_SESSION_SECONDS


def validate_session(keystroke_count: int, duration_sec: float) -> tuple:
    """Return (accepted: bool, reason: str)."""
    if duration_sec < MIN_SESSION_SECONDS:
        return False, "too_short"
    if keystroke_count < MIN_KEY_EVENTS:
        return False, "too_few_keystrokes"
    return True, "ok"


def quality_flags(keystroke_count: int, duration_sec: float,
                   hour_of_day: int | None = None) -> list:
    """Metadata flags. Unusual-hour is a weight hint, never a rejection."""
    flags = []
    accepted, reason = validate_session(keystroke_count, duration_sec)
    if not accepted:
        flags.append(reason)
    if hour_of_day is not None and 0 <= hour_of_day < 5:
        flags.append("unusual_hour")
    return flags


def eligible_for_analysis(session_phase: str, flags: list) -> bool:
    """Hard gate: familiarization never enters screening/baseline logic."""
    if session_phase == "familiarization":
        return False
    return "too_short" not in flags and "too_few_keystrokes" not in flags
