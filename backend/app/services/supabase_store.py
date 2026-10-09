"""Supabase persistence boundary (spec 17/18).

All user-owned reads/writes go through RLS as the user (Auth JWT).
The service-role client is used ONLY server-side for ML-owned writes
(result payloads, baselines) and is never exposed to the browser.
Session ownership is validated on every read (exact-ID, no fallback).
"""

from __future__ import annotations

import os


def _client(use_service_role: bool = False):
    url = os.environ.get("SUPABASE_URL", "")
    key = (os.environ.get("SUPABASE_SERVICE_KEY", "")
           if use_service_role else os.environ.get("SUPABASE_ANON_KEY", ""))
    if not url or not key:
        return None
    from supabase import create_client
    return create_client(url, key)


def get_user_client():
    return _client(False)


def get_service_client():
    return _client(True)


def fetch_session_exact(client, session_id: str, user_id: str) -> dict | None:
    """Exact session retrieval (spec 16). Returns the row or None.
    NEVER falls back to another session — callers map None to 404."""
    res = (client.table("sessions").select("*").eq("id", session_id)
           .eq("user_id", user_id).limit(1).execute())
    rows = res.data or []
    return rows[0] if rows else None


def fetch_metrics_exact(client, session_id: str, user_id: str) -> dict | None:
    res = (client.table("session_metrics").select("*")
           .eq("session_id", session_id).eq("user_id", user_id)
           .limit(1).execute())
    rows = res.data or []
    return rows[0] if rows else None


def history_for_user(client, user_id: str, limit: int = 200) -> list:
    """Real persisted sessions only, newest last. No synthetic rows."""
    res = (client.table("sessions").select("*").eq("user_id", user_id)
           .order("started_at", desc=False).limit(limit).execute())
    return res.data or []
