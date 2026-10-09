/**
 * On-device feature preview (parity port of backend/app/services/feature_extraction.py).
 * The BACKEND re-extracts authoritatively from raw events; this preview is
 * display-only and labeled as such. Units: MILLISECONDS throughout.
 * No Date.now(), no React state — pure functions over event arrays.
 */
import type { KeystrokeEventWire, MotorTapWire } from "@/lib/types";

export const HT_OUTLIER_MS = 2000;
export const FT_OUTLIER_MS = 3000;
export const PAUSE_THRESHOLD_MS = 500;
const IQR_FACTOR = 1.5;

function mean(v: number[]): number | null {
  if (!v.length) return null;
  return v.reduce((a, b) => a + b, 0) / v.length;
}
function std(v: number[]): number | null {
  if (!v.length) return null;
  const m = mean(v)!;
  return Math.sqrt(v.reduce((a, b) => a + (b - m) ** 2, 0) / v.length);
}
function quantile(sorted: number[], q: number): number {
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;
  return sorted[base] + (sorted[base + 1] !== undefined ? rest * (sorted[base + 1] - sorted[base]) : 0);
}
function iqrKeep(values: number[]): boolean[] {
  if (values.length < 4) return values.map(() => true);
  const s = [...values].sort((a, b) => a - b);
  const q1 = quantile(s, 0.25);
  const q3 = quantile(s, 0.75);
  const iqr = q3 - q1;
  return values.map((v) => v >= q1 - IQR_FACTOR * iqr && v <= q3 + IQR_FACTOR * iqr);
}

export interface TypingFeatures {
  [key: string]: number | null;
  ht_mean: number | null;
  ht_std: number | null;
  ft_mean: number | null;
  ft_std: number | null;
  ikl_mean: number | null;
  ikl_std: number | null;
  left_ht_mean: number | null;
  right_ht_mean: number | null;
  hand_asymmetry: number | null;
  pause_frequency: number | null;
  typing_speed: number | null;
  session_consistency: number | null;
  backspace_rate: number | null;
}

export function extractTypingFeatures(
  events: KeystrokeEventWire[],
  durationSec: number,
): TypingFeatures {
  const chars = events.filter((e) => e.keyType === "character");
  const backspaces = events.filter((e) => e.keyType === "backspace");
  const holds = chars.map((e) => e.releaseTimestamp - e.pressTimestamp);
  const flights = chars.slice(1).map((e, i) => e.pressTimestamp - chars[i].releaseTimestamp);
  const ikls = chars.slice(1).map((e, i) => e.pressTimestamp - chars[i].pressTimestamp);

  const htKeep = holds.map((h) => h <= HT_OUTLIER_MS);
  const trKeep = flights.map((f) => f <= FT_OUTLIER_MS);
  const htMask = iqrKeep(holds.filter((_, i) => htKeep[i]));
  const joint = iqrKeep(flights.filter((_, i) => trKeep[i])).map((k, i) => {
    const ik = iqrKeep(ikls.filter((_, j) => trKeep[j]));
    return k && ik[i];
  });

  let hi = 0;
  const sHt = holds.filter((_, i) => {
    if (!htKeep[i]) return false;
    return htMask[hi++] ?? false;
  });
  let ti = 0;
  const idx: number[] = [];
  trKeep.forEach((k, i) => {
    if (k && joint[ti++]) idx.push(i);
  });
  const sFt = idx.map((i) => flights[i]);
  const sIkl = idx.map((i) => ikls[i]);

  const hands = chars.filter((_, i) => htKeep[i]).filter((_, j) => htMask[j]).map((e) => e.hand);
  const left = sHt.filter((_, i) => hands[i] === "left");
  const right = sHt.filter((_, i) => hands[i] !== "left");

  const iklMean = mean(sIkl);
  const leftMean = mean(left);
  const rightMean = mean(right);
  const denom = Math.max(leftMean ?? 0, rightMean ?? 0);
  const durationMin = durationSec > 0 ? durationSec / 60 : 0;

  return {
    ht_mean: mean(sHt),
    ht_std: std(sHt),
    ft_mean: mean(sFt),
    ft_std: std(sFt),
    ikl_mean: iklMean,
    ikl_std: std(sIkl),
    left_ht_mean: leftMean,
    right_ht_mean: rightMean,
    hand_asymmetry:
      left.length && right.length && denom > 0 ? Math.abs(leftMean! - rightMean!) / denom : null,
    pause_frequency: durationMin > 0 ? sFt.filter((f) => f > PAUSE_THRESHOLD_MS).length / durationMin : null,
    typing_speed: durationSec > 0 ? chars.length / durationSec : null,
    session_consistency: iklMean ? std(sIkl)! / iklMean : null,
    backspace_rate: durationMin > 0 ? backspaces.length / durationMin : null,
  };
}

export interface WithinSessionSeries {
  elapsed_ms: number[];
  rolling_ht_ms: number[];
  rolling_ft_ms: number[];
  rolling_ikl_ms: number[];
}

/** Real within-session rolling series. Empty arrays when insufficient data —
 *  callers show "Insufficient data…", never synthetic points. */
export function withinSessionSeries(events: KeystrokeEventWire[], window = 10): WithinSessionSeries {
  const empty: WithinSessionSeries = { elapsed_ms: [], rolling_ht_ms: [], rolling_ft_ms: [], rolling_ikl_ms: [] };
  const chars = events.filter((e) => e.keyType === "character");
  if (chars.length < window + 1) return empty;
  const t0 = chars[0].pressTimestamp;
  const holds = chars.map((e) => e.releaseTimestamp - e.pressTimestamp);
  const elapsed = chars.map((e) => e.pressTimestamp - t0);
  const fts = chars.slice(1).map((e, i) => e.pressTimestamp - chars[i].releaseTimestamp);
  const ikls = chars.slice(1).map((e, i) => e.pressTimestamp - chars[i].pressTimestamp);
  const roll = (v: number[]) => v.map((_, i) => mean(v.slice(Math.max(0, i - window + 1), i + 1))!);
  return { elapsed_ms: elapsed, rolling_ht_ms: roll(holds), rolling_ft_ms: roll(fts), rolling_ikl_ms: roll(ikls) };
}

export interface MotorFeatures {
  valid_taps: number;
  mean_iti_ms: number | null;
  std_iti_ms: number | null;
  miss_rate: number | null;
  extra_tap_count: number;
  slowing_slope_ms: number | null;
}

export function extractMotorFeatures(taps: MotorTapWire[], expected = ["F", "J"]): MotorFeatures {
  let extra = 0;
  const valid: number[] = [];
  let last: string | null = null;
  for (const t of taps) {
    if (expected.includes(t.key) && t.key !== last) {
      valid.push(t.timestampMs);
      last = t.key;
    } else {
      extra += 1;
    }
  }
  if (valid.length < 2) {
    return { valid_taps: valid.length, mean_iti_ms: null, std_iti_ms: null, miss_rate: taps.length ? extra / taps.length : null, extra_tap_count: extra, slowing_slope_ms: null };
  }
  const iti = valid.slice(1).map((t, i) => t - valid[i]);
  const m = mean(iti)!;
  let slope: number | null = null;
  if (iti.length >= 3) {
    const n = iti.length;
    const sx = ((n - 1) * n) / 2;
    const sxx = ((n - 1) * n * (2 * n - 1)) / 6;
    const sy = iti.reduce((a, b) => a + b, 0);
    const sxy = iti.reduce((a, b, i) => a + i * b, 0);
    slope = (n * sxy - sx * sy) / (n * sxx - sx * sx);
  }
  return { valid_taps: valid.length, mean_iti_ms: m, std_iti_ms: std(iti), miss_rate: extra / taps.length, extra_tap_count: extra, slowing_slope_ms: slope };
}
