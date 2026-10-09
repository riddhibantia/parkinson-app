"use client";
import { useEffect, useState } from "react";
import { Card, EmptyState, SecondaryButton, StatusBadge } from "@/components/ui";
import { FeatureComparisonChart } from "@/components/charts";
import { fetchHistory } from "@/lib/session";
import { loadSnapshot, lastSessionId } from "@/lib/localCache";
import { supabaseBrowser } from "@/lib/supabaseClient";

/** Layer 1 insight: real extracted metrics, categorical interpretation,
 *  SHAP contributors when present. The internal model signal
 *  (pdProbability) is NEVER rendered as a clinical probability. */
export default function Layer1Page() {
  const [state, setState] = useState<{ features: Record<string, number | null>; layer1: Record<string, unknown> | null; shap: string } | null>(null);

  useEffect(() => {
    const run = async () => {
      const supa = supabaseBrowser();
      if (supa) {
        const { data: auth } = await supa.auth.getUser();
        if (auth.user) {
          const { data } = await supa
            .from("session_metrics").select("*").eq("user_id", auth.user.id)
            .order("created_at", { ascending: false }).limit(1).maybeSingle();
          if (data) {
            setState({ features: data.features ?? {}, layer1: data.layer1_result, shap: "stored" });
            return;
          }
        }
      }
      const id = lastSessionId();
      const snap = id ? loadSnapshot(id) : null;
      setState(snap ? { features: snap.features, layer1: snap.layer1, shap: "snapshot" } : { features: {}, layer1: null, shap: "none" });
    };
    run();
  }, []);

  if (!state) return <p>Loading…</p>;
  if (!state.layer1 && Object.keys(state.features).length === 0) {
    return (
      <div>
        <h1 className="text-2xl font-bold">Layer 1 — Typing-pattern screening</h1>
        <div className="mt-4">
          <EmptyState title="Not enough data yet" body="Complete a typing session to see your research comparison. The first session is a real measurement." />
          <div className="mt-3"><SecondaryButton href="/test">Start typing session</SecondaryButton></div>
        </div>
      </div>
    );
  }
  const l1 = (state.layer1 ?? {}) as Record<string, unknown>;
  const contributors = Array.isArray(l1["topContributors"]) ? (l1["topContributors"] as Record<string, unknown>[]) : [];
  void fetchHistory;

  return (
    <div>
      <h1 className="text-2xl font-bold">Layer 1 — Typing-pattern screening</h1>
      <p className="mt-1 text-sm text-slate-600">Population comparison of your typing characteristics. Research signal — not a diagnosis.</p>
      <div className="mt-4 flex flex-col gap-3">
        <Card>
          <div className="flex items-center gap-3">
            <StatusBadge status={String(l1["status"] ?? "preview")} />
            <p className="text-sm text-slate-700">{String(l1["message"] ?? "On-device preview — connect the analysis service for the population comparison.")}</p>
          </div>
        </Card>
        <FeatureComparisonChart features={state.features} />
        {contributors.length > 0 && (
          <Card>
            <h3 className="font-semibold">What stood out</h3>
            <ul className="mt-1 list-disc pl-5 text-sm text-slate-700">
              {contributors.slice(0, 3).map((c, i) => (
                <li key={i}>{String(c["text"] ?? c["feature"])}</li>
              ))}
            </ul>
          </Card>
        )}
      </div>
    </div>
  );
}
