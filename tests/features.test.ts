import { describe, expect, it } from "vitest";
import {
  extractMotorFeatures,
  extractTypingFeatures,
  withinSessionSeries,
} from "@/lib/features";
import type { KeystrokeEventWire } from "@/lib/types";

const ev = (press: number, hold = 100, hand: "left" | "right" = "right"): KeystrokeEventWire => ({
  pressTimestamp: press,
  releaseTimestamp: press + hold,
  hand,
  row: 1,
  keyType: "character",
});

describe("typing feature math (ms, monotonic deltas)", () => {
  it("computes HT/FT/IKL consistently", () => {
    const events = [ev(0, 100, "left"), ev(300), ev(600, 100, "left"), ev(900), ev(1200)];
    const f = extractTypingFeatures(events, 60);
    expect(f.ht_mean).toBeCloseTo(100);
    expect(f.ft_mean).toBeCloseTo(200);
    expect(f.ikl_mean).toBeCloseTo(300);
  });

  it("excludes backspace/control from rhythm but counts backspace rate", () => {
    const events: KeystrokeEventWire[] = [
      ev(0), ev(300),
      { pressTimestamp: 600, releaseTimestamp: 650, hand: "right", row: 1, keyType: "backspace" },
      { pressTimestamp: 700, releaseTimestamp: 710, hand: "right", row: 1, keyType: "control" },
      ev(1000),
    ];
    const f = extractTypingFeatures(events, 60);
    expect(f.typing_speed).toBeCloseTo(3 / 60);
    expect(f.backspace_rate).toBeCloseTo(1);
    expect(f.ht_mean).toBeCloseTo(100);
  });

  it("removes outlier holds via hard cutoff", () => {
    const events = Array.from({ length: 8 }, (_, i) => ev(i * 300));
    events.push(ev(2400, 5000));
    const f = extractTypingFeatures(events, 60);
    expect(f.ht_mean!).toBeLessThan(150);
  });

  it("computes asymmetry only when both hands present", () => {
    const both = [ev(0, 120, "left"), ev(300, 80), ev(600, 120, "left"), ev(900, 80)];
    expect(extractTypingFeatures(both, 60).hand_asymmetry).toBeCloseTo(0.333, 2);
    const oneHand = [ev(0), ev(300), ev(600), ev(900)];
    expect(extractTypingFeatures(oneHand, 60).hand_asymmetry).toBeNull();
  });

  it("returns empty series when insufficient data (never synthetic)", () => {
    const s = withinSessionSeries([ev(0, 100)], 10);
    expect(s.elapsed_ms).toEqual([]);
    const real = withinSessionSeries(Array.from({ length: 15 }, (_, i) => ev(i * 300)), 10);
    expect(real.elapsed_ms).toHaveLength(15);
    expect(real.rolling_ht_ms[0]).toBeCloseTo(100);
  });

  it("scores motor alternation on its own path", () => {
    const taps = Array.from({ length: 10 }, (_, i) => ({
      timestampMs: i * 150,
      key: i % 2 === 0 ? "F" : "J",
    }));
    const m = extractMotorFeatures(taps);
    expect(m.valid_taps).toBe(10);
    expect(m.mean_iti_ms).toBeCloseTo(150);
    expect(m.extra_tap_count).toBe(0);
  });
});
