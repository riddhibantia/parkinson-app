"""Device-mismatch guard (ported, validated — pure logic, no ML).

Source: functions/services/device_guard.py.
A session on a different keyboard than the baseline anchor must not
feed CUSUM/EWMA or Isolation Forest scoring. Never silently changes
the anchor device (spec 13).
"""


def check_device_consistency(session: dict, baseline: dict) -> dict:
    device = session.get("device_id", session.get("deviceId"))
    if device == baseline.get("anchor_device_id"):
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
