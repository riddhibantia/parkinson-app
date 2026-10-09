import type { Metadata } from "next";
import "./globals.css";
import { TopBar } from "@/components/Nav";
import { Disclaimer } from "@/components/ui";
import { StoreHydrator } from "@/store/useAppStore";

export const metadata: Metadata = {
  title: "ParkinTrace — Typing-Based Motor Pattern Screening & Monitoring",
  description:
    "Research aid analyzing how you type (never what you type). Not a medical device; not a diagnosis.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full">
      <body className="min-h-full bg-slate-50 text-slate-900 antialiased">
        <StoreHydrator />
        <TopBar />
        <main className="mx-auto max-w-5xl px-4 py-6">{children}</main>
        <footer className="mx-auto max-w-5xl px-4 pb-8">
          <Disclaimer />
        </footer>
      </body>
    </html>
  );
}
