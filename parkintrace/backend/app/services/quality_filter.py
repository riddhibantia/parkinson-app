"""Session quality filtering (ported, validated — unchanged logic).

Source: functions/services/quality_filter.py.
 blocking flags: too_short / too_few_keystrokes.
 unusual_hour is metadata only, never a rejection (spec 10.1).
The legacy familiarization gate lives here only as a back-compat guard
for old Firestore-exported rows; new sessions never carry that phase
(spec 27.1 — no practice session exists in the new app).
"""

from app.core.constants import MIN_KEY_EVENTS, MIN_SESSION_SECONDS


def validate_session(keystroke_count: int, duration_sec: float) -> tuple:
    """Return (accepted: bool, reason: str)."""
    if duration_sec < MIN_SESSION_SECONDS:
        return False, "too_short"
    if keystroke_count < MIN_KEY_EVENTS:
        return False, "too_few_keystrokes"
    return True, "ok"


def quality_flags(
    keystroke_count: int, duration_sec: float, hour_of_day: int | None = None
) -> list:
    """Metadata flags. Unusual-hour is a weight hint, never a rejection."""
    flags = []
    accepted, reason = validate_session(keystroke_count, duration_sec)
    if not accepted:
        flags.append(reason)
    if hour_of_day is not None and 0 <= hour_of_day < 5:
        flags.append("unusual_hour")
    return flags


def eligible_for_analysis(session_phase: str, flags: list) -> bool:
    """Hard gate: legacy familiarization rows never enter scoring."""
    if session_phase == "familiarization":
        return False
    return "too_short" not in flags and "too_few_keystrokes" not in flags


BLOCKING_QUALITY_FLAGS = frozenset({"too_short", "too_few_keystrokes"})
