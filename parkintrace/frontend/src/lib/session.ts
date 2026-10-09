import { API_URL } from "@/lib/config";
import { supabaseBrowser } from "@/lib/supabaseClient";
import { SessionNotFoundError, type SessionPayload, type SessionRow } from "@/lib/types";

export function newSessionId(): string {
  return crypto.randomUUID();
}

export function stableDeviceId(): string {
  const key = "parkintrace-device-id";
  let id = localStorage.getItem(key);
  if (!id) {
    id = `browser-${crypto.randomUUID().slice(0, 8)}`;
    localStorage.setItem(key, id);
  }
  return id;
}

async function api(path: string, body: unknown) {
  const res = await fetch(`${API_URL}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Analysis service ${res.status}: ${text.slice(0, 300)}`);
  }
  return res.json();
}

/** Canonical lifecycle (spec 14): persist session, analyze with the SAME id,
 *  persist metrics against the SAME id. Never mints a second id. */
export async function persistAndAnalyze(
  payload: SessionPayload,
  opts: { baseline?: Record<string, unknown> | null; recent?: Record<string, unknown>[] } = {},
): Promise<{ analysis: Record<string, unknown>; persisted: boolean }> {
  const supa = supabaseBrowser();
  let persisted = false;
  // Owner-only persistence (spec 18/RLS): persist only for a signed-in
  // owner. Signed-out visitors get analysis-only + local snapshot — never
  // a write with a placeholder user id (FK + RLS reject it, and the throw
  // used to block navigation to the session insight entirely).
  let ownerId: string | null = null;
  if (supa) {
    const { data: auth } = await supa.auth.getUser();
    ownerId = auth.user?.id ?? null;
  }
  if (supa && ownerId) {
    const { error } = await supa.from("sessions").upsert(
      {
        id: payload.sessionId,
        user_id: ownerId,
        started_at: payload.startedAt,
        ended_at: payload.endedAt,
        session_type: payload.sessionType,
        device_id: payload.deviceId,
        valid: true,
        quality_flags: payload.qualityFlags,
      },
      { onConflict: "id" },
    );
    if (error) throw new Error(`Session persist failed: ${error.message}`);
    persisted = true;
  }

  const analysis = await api("/api/v1/analysis/session", {
    ...payload,
    baseline: opts.baseline ?? null,
    recent: opts.recent ?? [],
  });

  if (supa && ownerId) {
    const layer1 = (analysis as Record<string, Record<string, unknown>>)["layer1"] ?? null;
    const layer2 = (analysis as Record<string, Record<string, unknown>>)["layer2"] ?? null;
    const features = (analysis as Record<string, Record<string, number>>)["features"] ?? {};
    const series = (analysis as Record<string, unknown>)["withinSessionSeries"] ?? null;
    const { error } = await supa.from("session_metrics").upsert(
      {
        session_id: payload.sessionId,
        user_id: ownerId,
        features,
        quality_metrics: { keystrokeCount: payload.keystrokeCount, qualityFlags: payload.qualityFlags },
        layer1_result: layer1,
        layer2_result: layer2,
        within_session_series: series,
      },
      { onConflict: "session_id" },
    );
    if (error) throw new Error(`Metrics persist failed: ${error.message}`);
  }
  return { analysis: analysis as Record<string, unknown>, persisted };
}

/** Exact retrieval (spec 16): the requested id or SessionNotFoundError.
 *  NEVER falls back to another session. */
export async function fetchSessionExact(sessionId: string): Promise<{ session: SessionRow; metrics: unknown }> {
  const supa = supabaseBrowser();
  if (!supa) throw new Error("Backend not configured");
  const { data: auth } = await supa.auth.getUser();
  if (!auth.user) throw new Error("Sign-in required");
  const { data: row, error } = await supa.from("sessions").select("*").eq("id", sessionId).limit(1).maybeSingle();
  if (error) throw new Error(`Session fetch failed: ${error.message}`);
  if (!row) throw new SessionNotFoundError(sessionId);
  const { data: metrics } = await supa.from("session_metrics").select("*").eq("session_id", sessionId).limit(1).maybeSingle();
  return { session: row as SessionRow, metrics };
}

export async function fetchHistory(limit = 200): Promise<SessionRow[]> {
  const supa = supabaseBrowser();
  if (!supa) return [];
  const { data: auth } = await supa.auth.getUser();
  if (!auth.user) return [];
  const { data } = await supa
    .from("sessions")
    .select("*")
    .eq("user_id", auth.user.id)
    .order("started_at", { ascending: true })
    .limit(limit);
  return (data ?? []) as SessionRow[];
}
