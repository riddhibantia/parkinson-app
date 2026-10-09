"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Logo } from "@/components/ui";
import { useAppStore } from "@/store/useAppStore";

const LINKS = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/layer1", label: "Layer 1" },
  { href: "/layer2", label: "Layer 2" },
  { href: "/history", label: "History" },
];

export function TopBar() {
  const layer = useAppStore((s) => s.layer);
  const setLayer = useAppStore((s) => s.setLayer);
  const pathname = usePathname();
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-5xl items-center gap-3 px-4 py-3">
        <Logo />
        <div className="mr-auto">
          <p className="font-bold text-slate-900">ParkinTrace</p>
          <p className="text-xs text-slate-500">Typing-pattern screening &amp; monitoring</p>
        </div>
        <nav className="flex items-center gap-1" aria-label="Primary">
          {LINKS.map((l) => {
            const isLayerLink = l.href === "/layer1" || l.href === "/layer2";
            const active =
              pathname === l.href || (isLayerLink && ((l.href === "/layer1") === (layer === "layer1")) && pathname.startsWith("/" + l.href.slice(1, 7)));
            return (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => {
                  if (l.href === "/layer1") setLayer("layer1");
                  if (l.href === "/layer2") setLayer("layer2");
                }}
                className={`rounded-lg px-3 py-1.5 text-sm font-semibold ${
                  active ? "bg-teal-100 text-teal-800" : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                {l.label}
              </Link>
            );
          })}
        </nav>
      </div>
    </header>
  );
}
