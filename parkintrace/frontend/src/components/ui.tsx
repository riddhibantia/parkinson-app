import type { ReactNode } from "react";
import { DISCLAIMER } from "@/lib/config";

export function Logo({ size = 36 }: { size?: number }) {
  return (
    <span
      aria-label="ParkinTrace logo"
      className="inline-flex items-center justify-center rounded-full bg-teal-600 text-white font-bold"
      style={{ width: size, height: size, fontSize: size * 0.45 }}
    >
      PT
    </span>
  );
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div className={`rounded-2xl border border-slate-200 bg-white p-5 shadow-sm ${className}`}>{children}</div>
  );
}

export function PrimaryButton({
  children, onClick, type = "button", disabled = false,
}: {
  children: ReactNode; onClick?: () => void; type?: "button" | "submit"; disabled?: boolean;
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      className="rounded-xl bg-teal-600 px-5 py-2.5 font-semibold text-white hover:bg-teal-700 focus:outline-none focus:ring-2 focus:ring-teal-500 disabled:cursor-not-allowed disabled:opacity-50"
    >
      {children}
    </button>
  );
}

export function SecondaryButton({
  children, onClick, href,
}: {
  children: ReactNode; onClick?: () => void; href?: string;
}) {
  const cls =
    "rounded-xl border border-slate-300 bg-white px-5 py-2.5 font-semibold text-slate-700 hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-teal-500";
  if (href) return <a href={href} className={cls}>{children}</a>;
  return <button type="button" onClick={onClick} className={cls}>{children}</button>;
}

export function StatusBadge({ status }: { status: string }) {
  const color =
    status === "attention"
      ? "bg-amber-100 text-amber-800 border-amber-300"
      : status === "watch"
        ? "bg-sky-100 text-sky-800 border-sky-300"
        : status === "normal"
          ? "bg-emerald-100 text-emerald-800 border-emerald-300"
          : "bg-slate-100 text-slate-700 border-slate-300";
  return (
    <span className={`inline-block rounded-full border px-3 py-1 text-sm font-semibold ${color}`}>
      {status.replace(/_/g, " ")}
    </span>
  );
}

export function Disclaimer() {
  return <p className="text-sm italic text-slate-500">{DISCLAIMER}</p>;
}

export function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <Card>
      <h3 className="font-semibold text-slate-800">{title}</h3>
      <p className="mt-1 text-sm text-slate-600">{body}</p>
    </Card>
  );
}

export function Field({ label, error, children }: { label: string; error?: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="text-sm font-medium text-slate-700">{label}</span>
      <div className="mt-1">{children}</div>
      {error && <span className="text-sm text-red-600">{error}</span>}
    </label>
  );
}

export const inputCls =
  "w-full rounded-xl border border-slate-300 px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-teal-500";
