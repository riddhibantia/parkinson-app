"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Card, PrimaryButton, SecondaryButton } from "@/components/ui";
import { supabaseBrowser } from "@/lib/supabaseClient";
import { baselineProgress } from "@/lib/baseline";
import { fetchHistory } from "@/lib/session";
import { stableDeviceId } from "@/lib/session";
import { useAppStore } from "@/store/useAppStore";
import { lastSessionId } from "@/lib/localCache";

export default function DashboardPage() {
  const router = useRouter();
  const layer = useAppStore((s) => s.layer);
  const setLayer = useAppStore((s) => s.setLayer);
  const resetSession = useAppStore((s) => s.resetSession);
  const [sessions, setSessions] = useState(0);
  const [days, setDays] = useState(0);
  const [baselineState, setBaselineState] = useState("building");

  useEffect(() => {
    fetchHistory().then((rows) => {
      const p = baselineProgress(rows, typeof window !== "undefined" ? stableDeviceId() : "");
      setSessions(p.sessions);
      setDays(p.distinctDays);
      setBaselineState(p.status);
    });
  }, []);

  const logout = async () => {
    await supabaseBrowser()?.auth.signOut();
    resetSession();
    router.replace("/");
  };

  return (
    <div>
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <SecondaryButton onClick={logout}>Log out</SecondaryButton>
      </div>
      <div className="mt-4 grid gap-3 md:grid-cols-2">
        <Card className={layer === "layer1" ? "ring-2 ring-teal-500" : ""}>
          <h2 className="font-semibold">Layer 1 — Typing-pattern screening</h2>
          <p className="mt-1 text-sm text-slate-600">Population comparison of your typing characteristics.</p>
          <div className="mt-3 flex gap-2">
            <PrimaryButton onClick={() => { setLayer("layer1"); router.push("/layer1"); }}>Open Layer 1</PrimaryButton>
          </div>
        </Card>
        <Card className={layer === "layer2" ? "ring-2 ring-teal-500" : ""}>
          <h2 className="font-semibold">Layer 2 — Personal monitoring</h2>
          <p className="mt-1 text-sm text-slate-600">
            Baseline: {baselineState} · {sessions}/10+ sessions · {days}/5+ days.
          </p>
          <div className="mt-3 flex gap-2">
            <PrimaryButton onClick={() => { setLayer("layer2"); router.push("/layer2"); }}>Open Layer 2</PrimaryButton>
          </div>
        </Card>
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        <PrimaryButton onClick={() => router.push("/test")}>New typing session</PrimaryButton>
        <SecondaryButton onClick={() => router.push("/motor-task")}>Motor task (F/J)</SecondaryButton>
        <SecondaryButton onClick={() => { const id = lastSessionId(); if (id) router.push(`/session/${id}`); }}>
          Latest session
        </SecondaryButton>
      </div>
    </div>
  );
}
