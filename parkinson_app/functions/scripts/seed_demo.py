"""Seed a demo user with synthetic sessions for manual QA.

Usage (offline, no Firebase needed):
  python -m scripts.seed_demo

Writes to the local pending buffer shape via typing_session factories;
for a signed-in Firestore user, pipe the same JSON through
SessionRepository.saveSession() or the REST helper.

This is the "how to demo without waiting 21 days" helper referenced
in the plan's demo guidance — synthetic but realistic timing values
derived from the harmonized dataset medians.
"""

import json
import random
import uuid
from datetime import datetime, timedelta, timezone

# Representative feature medians sampled from harmonized_sessions.csv
# (Phase 2 research). Used to synthesize plausible session documents.
MEDIANS = {
    "ht_mean": 110, "ht_std": 28, "ft_mean": 85, "ft_std": 35,
    "ikl_mean": 210, "ikl_std": 55, "left_ht_mean": 108,
    "right_ht_mean": 112, "hand_asymmetry": 0.06, "pause_frequency": 2.1,
    "typing_speed": 4.2, "session_consistency": 0.26, "backspace_rate": 0.8,
}

def synth_session(day_offset: int, phase="screening",
                  device_id="laptop-keyboard") -> dict:
    jitter = lambda m: max(1, m * random.uniform(0.85, 1.15))
    sid = str(uuid.uuid4())
    start = datetime.now(timezone.utc) - timedelta(days=day_offset)
    features = {k: round(jitter(v), 3) for k, v in MEDIANS.items()}
    return {
        "sessionId": sid,
        "startTime": start.isoformat(),
        "endTime": (start + timedelta(seconds=random.randint(35, 90))).isoformat(),
        "mode": "structured",
        "sessionPhase": phase,
        "deviceId": device_id,
        "totalKeystrokes": random.randint(55, 140),
        **features,
    }

if __name__ == "__main__":
    # 12 screening sessions across 7 days + 1 practice
    sessions = [synth_session(8, phase="familiarization")]
    for d in [7,6,6,5,4,3,3,2,1,1,0,0]:
        sessions.append(synth_session(d))
    print(json.dumps(sessions[:2], indent=2))
    print(f"\n# {len(sessions)} sessions synthesized (1 practice + 12 screening).")
    print("# For Firestore: import firebase_admin and call")
    print("#   db.collection('users').document(uid).collection('sessions').document(s['sessionId']).set({...})")
