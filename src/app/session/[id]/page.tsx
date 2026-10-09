"use client";
import { use, useEffect, useState } from "react";
import { Card, EmptyState, SecondaryButton, StatusBadge } from "@/components/ui";
import { RhythmChart } from "@/components/charts";
import { fetchSessionExact } from "@/lib/session";
import { loadSnapshot, type Snapshot } from "@/lib/localCache";
import { supabaseBrowser } from "@/lib/supabaseClient";
import { SessionNotFoundError } from "@/lib/types";
import { isSupabaseConfigured } from "@/lib/config";

/** Exact session detail (spec 16): the requested id, or "Session not
 *  found". Never another session, never a redirect to one. */
export default function SessionDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [snap, setSnap] = useState<Snapshot | null>(null);
  const [missing, setMissing] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const run = async () => {
      // Supabase is authoritative only for a signed-in owner. Signed-out
      // visitors (analysis-only + local snapshot) go straight to the
      // exact-id local snapshot — otherwise "Sign-in required" would hide
      // their just-completed session insight.
      if (isSupabaseConfigured) {
        const supa = supabaseBrowser();
        const { data } = supa ? await supa.auth.getUser() : { data: { user: null } };
        if (data.user) {
          try {
            const { session, metrics } = await fetchSessionExact(id);
            const m = (metrics ?? {}) as Record<string, Record<string, number | null> | null>;
            setSnap({
              sessionId: session.id, startedAt: session.started_at, endedAt: session.ended_at,
              sessionType: session.session_type, deviceId: session.device_id,
              features: (m["features"] as Record<string, number | null>) ?? {},
              layer1: (m["layer1_result"] as Record<string, unknown>) ?? null,
              layer2: (m["layer2_result"] as Record<string, unknown>) ?? null,
              series: (m["within_session_series"] as Snapshot["series"]) ?? null,
              persisted: true, localPreview: false,
            });
            return;
          } catch (e) {
            if (!(e instanceof SessionNotFoundError)) {
              setError(e instanceof Error ? e.message : "Fetch failed");
              return;
            }
          }
        }
      }
      const local = loadSnapshot(id);
      if (local) setSnap(local);
      else setMissing(true);
    };
    run();
  }, [id]);

  if (missing) {
    return (
      <div>
        <h1 className="text-2xl font-bold">Session insight</h1>
        <div className="mt-4">
          <EmptyState title="Session not found" body={`No session with id ${id} exists for this user.`} />
          <div className="mt-3"><SecondaryButton href="/dashboard">Back to dashboard</SecondaryButton></div>
        </div>
      </div>
    );
  }
  if (error) return <p className="text-red-600">{error}</p>;
  if (!snap) return <p>Loading…</p>;

  const l1 = (snap.layer1 ?? {}) as Record<string, unknown>;
  const l2 = (snap.layer2 ?? {}) as Record<string, unknown>;
  const f = snap.features;

  return (
    <div>
      <h1 className="text-2xl font-bold">Session insight</h1>
      <p className="font-mono text-xs text-slate-500">session {snap.sessionId}</p>
      <p className="text-sm text-slate-600">
        {snap.startedAt.slice(0, 16).replace("T", " ")} · {snap.sessionType} · device {snap.deviceId}
        {snap.localPreview ? " · on-device preview (not yet analyzed)" : ""}
      </p>
      <div className="mt-4 flex flex-col gap-3">
        <Card>
          <h3 className="font-semibold">Session metrics</h3>
          <dl className="mt-2 grid grid-cols-2 gap-1 text-sm">
            <dt>Hold time</dt><dd>{f.ht_mean?.toFixed(0) ?? "—"} ms</dd>
            <dt>Flight time</dt><dd>{f.ft_mean?.toFixed(0) ?? "—"} ms</dd>
            <dt>Inter-key latency</dt><dd>{f.ikl_mean?.toFixed(0) ?? "—"} ms</dd>
            <dt>Typing speed</dt><dd>{f.typing_speed?.toFixed(2) ?? "—"} keys/s</dd>
            <dt>Consistency</dt><dd>{f.session_consistency?.toFixed(2) ?? "—"}</dd>
            <dt>Pause frequency</dt><dd>{f.pause_frequency?.toFixed(1) ?? "—"}/min</dd>
          </dl>
        </Card>
        <Card>
          <div className="flex items-center gap-3">
            <StatusBadge status={String(l1["status"] ?? l2["status"] ?? "preview")} />
            <p className="text-sm text-slate-700">
              {String(l1["message"] ?? l2["message"] ?? "Session saved. Baseline status: building.")}
            </p>
          </div>
          {typeof l2["baselineStatus"] === "string" && (
            <p className="mt-2 text-sm text-slate-600">Baseline: {l2["baselineStatus"]}</p>
          )}
        </Card>
        <RhythmChart series={snap.series} />
      </div>
    </div>
  );
}
