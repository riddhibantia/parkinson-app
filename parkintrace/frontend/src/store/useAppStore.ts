"use client";
import { create } from "zustand";

export type Layer = "layer1" | "layer2";

interface AppState {
  layer: Layer;
  onboardingCompleted: boolean;
  userId: string | null;
  hydrated: boolean;
  setLayer: (l: Layer) => void;
  setOnboardingCompleted: (v: boolean) => void;
  setUserId: (id: string | null) => void;
  resetSession: () => void;
  hydrate: () => void;
}

/** Hydration-safe: server and first client render both use defaults, so
 *  the HTML matches. Browser-stored values load in an effect (see
 *  StoreHydrator), never during render. Layer switching never logs out,
 *  clears data, or restarts onboarding. */
export const useAppStore = create<AppState>()((set) => ({
  layer: "layer1",
  onboardingCompleted: false,
  userId: null,
  hydrated: false,
  setLayer: (layer) => {
    try {
      localStorage.setItem("parkintrace-layer", layer);
    } catch {
      /* private mode */
    }
    set({ layer });
  },
  setOnboardingCompleted: (v) => {
    try {
      localStorage.setItem("parkintrace-onboarded", v ? "1" : "0");
    } catch {
      /* private mode */
    }
    set({ onboardingCompleted: v });
  },
  setUserId: (userId) => set({ userId }),
  resetSession: () => set({ userId: null }),
  hydrate: () => {
    try {
      const layer = localStorage.getItem("parkintrace-layer");
      const onboarded = localStorage.getItem("parkintrace-onboarded") === "1";
      set({
        layer: layer === "layer2" ? "layer2" : "layer1",
        onboardingCompleted: onboarded,
        hydrated: true,
      });
    } catch {
      set({ hydrated: true });
    }
  },
}));

import { useEffect } from "react";

export function StoreHydrator() {
  const hydrate = useAppStore((s) => s.hydrate);
  useEffect(() => {
    hydrate();
  }, [hydrate]);
  return null;
}
