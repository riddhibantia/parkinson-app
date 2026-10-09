"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Card, PrimaryButton } from "@/components/ui";
import { supabaseBrowser } from "@/lib/supabaseClient";

export default function ConsentPage() {
  const router = useRouter();
  const [agreed, setAgreed] = useState(false);
  const [research, setResearch] = useState(false);

  const next = async () => {
    const supa = supabaseBrowser();
    if (supa) {
      const { data } = await supa.auth.getUser();
      if (data.user) {
        await supa.from("profiles").upsert({ id: data.user.id, parkinson_context: { research_consent: research } });
      }
    }
    try {
      localStorage.setItem("parkintrace-consent", JSON.stringify({ agreed, research, at: new Date().toISOString() }));
    } catch {
      /* private mode */
    }
    router.push("/demographics");
  };

  return (
    <div className="mx-auto max-w-xl">
      <h1 className="text-2xl font-bold">Consent &amp; privacy</h1>
      <Card className="mt-4 flex flex-col gap-3 text-sm text-slate-700">
        <p>
          ParkinTrace analyzes <strong>how you type</strong> — key timing such as hold time and
          flight time — <strong>never what you type</strong>. Typed content is not persisted.
        </p>
        <p>
          This is a research, screening, and monitoring aid. It is <strong>not</strong> a medical
          device and its output is <strong>not a diagnosis</strong>.
        </p>
        <p>
          Raw key timing exists transiently in your browser to compute features. Only derived
          feature vectors, quality metrics, and analysis results are stored.
        </p>
        <label className="flex items-start gap-2 font-medium">
          <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} className="mt-1" />
          I understand the above and agree to participate.
        </label>
        <label className="flex items-start gap-2">
          <input type="checkbox" checked={research} onChange={(e) => setResearch(e.target.checked)} className="mt-1" />
          Optional: retain anonymized timing archives for approved research (off by default).
        </label>
        <PrimaryButton onClick={next} disabled={!agreed}>Continue</PrimaryButton>
      </Card>
    </div>
  );
}
