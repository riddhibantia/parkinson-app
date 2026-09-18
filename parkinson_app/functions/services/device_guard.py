"""Device-mismatch guard (Stage 5.1a, pure logic — no ML).

Runs before any Layer 2 scoring: a session typed on a different keyboard
than the baseline anchor must not feed CUSUM/EWMA or Isolation Forest
scoring as if it were behavioral data.
"""


def check_device_consistency(session: dict, baseline: dict) -> dict:
    if session.get("device_id") == baseline.get("anchor_device_id"):
        return {"proceed": True}
    return {
        "proceed": False,
        "status": "device_mismatch",
        "message": (
            "This session looks like it was typed on a different "
            "keyboard than your usual one. We've skipped comparing "
            "it to your personal trend so it doesn't throw off your "
            "results. If you've switched keyboards permanently, you "
            "can reset your baseline in Settings."
        ),
    }
