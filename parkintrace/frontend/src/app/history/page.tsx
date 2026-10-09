"use client";
import { useEffect, useState } from "react";
import { Card, EmptyState, SecondaryButton } from "@/components/ui";
import { fetchHistory } from "@/lib/session";
import type { SessionRow } from "@/lib/types";

export default function HistoryPage() {
  const [rows, setRows] = useState<SessionRow[] | null>(null);
  useEffect(() => {
    fetchHistory().then(setRows);
  }, []);
  if (!rows) return <p>Loading…</p>;
  return (
    <div>
      <h1 className="text-2xl font-bold">History</h1>
      {!rows.length ? (
        <div className="mt-4">
          <EmptyState title="No sessions yet" body="Your real persisted sessions will appear here." />
          <div className="mt-3"><SecondaryButton href="/test">Start typing session</SecondaryButton></div>
        </div>
      ) : (
        <Card className="mt-4">
          <ul className="flex flex-col gap-2 text-sm">
            {[...rows].reverse().map((s) => (
              <li key={s.id} className="flex justify-between border-b border-slate-100 pb-2">
                <a className="text-teal-700 underline" href={`/session/${s.id}`}>{s.id.slice(0, 8)}…</a>
                <span className="text-slate-600">{s.started_at.slice(0, 16).replace("T", " ")} · {s.session_type} · {s.device_id}</span>
              </li>
            ))}
          </ul>
        </Card>
      )}
    </div>
  );
}
