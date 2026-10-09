"use client";
import { useRouter } from "next/navigation";
import { Card, PrimaryButton, SecondaryButton } from "@/components/ui";
import { supabaseBrowser } from "@/lib/supabaseClient";
import { useAppStore, type Layer } from "@/store/useAppStore";

export default function LayerSelectionPage() {
  const router = useRouter();
  const setLayer = useAppStore((s) => s.setLayer);
  const setOnboardingCompleted = useAppStore((s) => s.setOnboardingCompleted);

  const choose = async (layer: Layer) => {
    setLayer(layer);
    setOnboardingCompleted(true);
    const supa = supabaseBrowser();
    if (supa) {
      const { data } = await supa.auth.getUser();
      if (data.user) await supa.from("profiles").upsert({ id: data.user.id, onboarding_completed: true });
    }
    router.replace("/dashboard");
  };

  return (
    <div className="mx-auto max-w-xl">
      <h1 className="text-2xl font-bold">Choose your starting view</h1>
      <p className="mt-1 text-sm text-slate-600">
        You can switch layers anytime without repeating onboarding. Your first typing session is a
        real measurement either way — there is no practice session.
      </p>
      <div className="mt-4 flex flex-col gap-3">
        <Card>
          <h2 className="font-semibold">Layer 1 — Typing-pattern screening</h2>
          <p className="mt-1 text-sm text-slate-600">
            Compares your current typing characteristics with patterns learned from the research
            population.
          </p>
          <div className="mt-3"><PrimaryButton onClick={() => choose("layer1")}>Start with Layer 1</PrimaryButton></div>
        </Card>
        <Card>
          <h2 className="font-semibold">Layer 2 — Personal monitoring</h2>
          <p className="mt-1 text-sm text-slate-600">
            Tracks measurable change against your own baseline across sessions and days. Session 1
            is useful immediately while the baseline builds.
          </p>
          <div className="mt-3"><SecondaryButton onClick={() => choose("layer2")}>Start with Layer 2</SecondaryButton></div>
        </Card>
      </div>
    </div>
  );
}
