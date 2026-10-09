"use client";
import { useEffect, useState } from "react";
import { Card, EmptyState, SecondaryButton, StatusBadge } from "@/components/ui";
import { LongitudinalChart, type TrendPoint } from "@/components/charts";
import { baselineProgress } from "@/lib/baseline";
import { fetchHistory, stableDeviceId } from "@/lib/session";
import { supabaseBrowser } from "@/lib/supabaseClient";
import type { SessionRow } from "@/lib/types";

/** Layer 2: building view (Session 1 useful immediately) + longitudinal
 *  view over REAL persisted sessions. No fabricated history. */
export default function Layer2Page() {
  const [sessions, setSessions] = useState<SessionRow[]>([]);
  const [points, setPoints] = useState<TrendPoint[]>([]);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const run = async () => {
      const rows = await fetchHistory();
      setSessions(rows);
      const supa = supabaseBrowser();
      if (supa && rows.length) {
        const { data: auth } = await supa.auth.getUser();
        if (auth.user) {
          const { data } = await supa.from("session_metrics").select("*").eq("user_id", auth.user.id).order("created_at");
          setPoints(((data ?? []) as { created_at: string; features: Record<string, number | null> }[]).map((m) => ({
            date: m.created_at, ht_mean: m.features?.ht_mean ?? null,
            ft_mean: m.features?.ft_mean ?? null, ikl_mean: m.features?.ikl_mean ?? null,
          })));
        }
      }
      setLoaded(true);
    };
    run();
  }, []);

  if (!loaded) return <p>Loading…</p>;
  if (!sessions.length) {
    return (
      <div>
        <h1 className="text-2xl font-bold">Layer 2 — Personal monitoring</h1>
        <div className="mt-4">
          <EmptyState title="No sessions yet" body="Save your first typing session to begin building your personal baseline." />
          <div className="mt-3"><SecondaryButton href="/test">Start first session</SecondaryButton></div>
        </div>
      </div>
    );
  }
  const progress = baselineProgress(sessions, stableDeviceId());

  return (
    <div>
      <h1 className="text-2xl font-bold">Layer 2 — Personal monitoring</h1>
      <div className="mt-4 flex flex-col gap-3">
        <Card>
          <div className="flex items-center gap-3">
            <StatusBadge status={progress.status} />
            <p className="text-sm text-slate-700">
              Baseline {progress.status}: {progress.sessions}/{progress.required} sessions ·{" "}
              {progress.distinctDays}/{progress.requiredDays} distinct days
              {progress.anchorDevice ? ` · anchor ${progress.anchorDevice}` : ""}.
            </p>
          </div>
        </Card>
        <LongitudinalChart points={points} />
        <Card>
          <h3 className="font-semibold">Sessions</h3>
          <ul className="mt-2 flex flex-col gap-1 text-sm">
            {[...sessions].reverse().map((s) => (
              <li key={s.id}>
                <a className="text-teal-700 underline" href={`/session/${s.id}`}>
                  {s.started_at.slice(0, 16).replace("T", " ")} · {s.session_type} · {(s.quality_flags ?? []).join(", ") || "ok"}
                </a>
              </li>
            ))}
          </ul>
        </Card>
      </div>
    </div>
  );
}
