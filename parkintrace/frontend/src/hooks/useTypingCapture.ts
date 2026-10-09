"use client";
/**
 * Browser typing capture (spec Phase 4).
 * - Monotonic high-resolution source ONLY: KeyboardEvent.timeStamp (DOM
 *   High-Resolution timestamp, ms). No Date.now(), no new Date(), no
 *   React state in the timing path — refs + in-memory buffers only.
 * - Handles repeats (counted, not re-pressed), modifiers/control keys
 *   (excluded from rhythm), unpaired keyup (dropped), window blur
 *   (recorded in quality, capture continues honestly).
 * - Raw key identity lives transiently in the pairing map for hand/row
 *   derivation and is never returned or persisted (only timing + hand).
 */
import { useCallback, useEffect, useRef, useState } from "react";
import type { KeystrokeEventWire, MotorTapWire } from "@/lib/types";

const LEFT_CODES = new Set([
  "KeyQ", "KeyW", "KeyE", "KeyR", "KeyT",
  "KeyA", "KeyS", "KeyD", "KeyF", "KeyG",
  "KeyZ", "KeyX", "KeyC", "KeyV", "KeyB",
  "Tab", "CapsLock", "ShiftLeft",
]);
const TOP_ROW = new Set(["KeyQ", "KeyW", "KeyE", "KeyR", "KeyT", "KeyY", "KeyU", "KeyI", "KeyO", "KeyP"]);
const BOTTOM_ROW = new Set(["KeyZ", "KeyX", "KeyC", "KeyV", "KeyB", "KeyN", "KeyM"]);

function classify(e: KeyboardEvent): "character" | "backspace" | "control" | null {
  if (e.code === "Backspace") return "backspace";
  const control =
    e.code.startsWith("Shift") || e.code.startsWith("Control") || e.code.startsWith("Alt") ||
    e.code.startsWith("Meta") || e.code === "Tab" || e.code === "Enter" ||
    e.code.startsWith("Arrow") || e.code === "Escape" || e.key.length !== 1;
  if (control) return "control";
  return "character";
}

export interface CaptureQuality {
  repeats: number;
  unpairedKeyups: number;
  blurs: number;
  invalidSequences: number;
}

export function useTypingCapture() {
  const eventsRef = useRef<KeystrokeEventWire[]>([]);
  const downRef = useRef(new Map<string, number>());
  const qualityRef = useRef<CaptureQuality>({ repeats: 0, unpairedKeyups: 0, blurs: 0, invalidSequences: 0 });
  const [active, setActive] = useState(false);
  const [count, setCount] = useState(0);
  const activeRef = useRef(false);
  const countRef = useRef(0);

  const onBlur = useCallback(() => {
    if (activeRef.current) qualityRef.current.blurs += 1;
  }, []);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (!activeRef.current) return;
      const kind = classify(e);
      if (kind === null || kind === "control") return;
      if (e.repeat || downRef.current.has(e.code)) {
        qualityRef.current.repeats += 1;
        return;
      }
      downRef.current.set(e.code, e.timeStamp);
    };
    const up = (e: KeyboardEvent) => {
      if (!activeRef.current) return;
      const kind = classify(e);
      if (kind === null || kind === "control") return;
      const press = downRef.current.get(e.code);
      downRef.current.delete(e.code);
      if (press === undefined) {
        qualityRef.current.unpairedKeyups += 1;
        return;
      }
      const release = e.timeStamp;
      if (!(release >= press)) {
        qualityRef.current.invalidSequences += 1;
        return;
      }
      eventsRef.current.push({
        pressTimestamp: press,
        releaseTimestamp: release,
        hand: LEFT_CODES.has(e.code) ? "left" : "right",
        row: TOP_ROW.has(e.code) ? 0 : BOTTOM_ROW.has(e.code) ? 2 : 1,
        keyType: kind,
      });
      countRef.current += 1;
      setCount(countRef.current);
    };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", onBlur);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
      window.removeEventListener("blur", onBlur);
    };
  }, [onBlur]);

  const start = useCallback(() => {
    eventsRef.current = [];
    downRef.current.clear();
    qualityRef.current = { repeats: 0, unpairedKeyups: 0, blurs: 0, invalidSequences: 0 };
    countRef.current = 0;
    setCount(0);
    activeRef.current = true;
    setActive(true);
  }, []);

  const stop = useCallback((): { events: KeystrokeEventWire[]; quality: CaptureQuality } => {
    activeRef.current = false;
    setActive(false);
    downRef.current.clear();
    return { events: [...eventsRef.current], quality: { ...qualityRef.current } };
  }, []);

  return { active, count, start, stop };
}

export function useMotorTaskCapture(durationMs = 15_000) {
  const tapsRef = useRef<MotorTapWire[]>([]);
  const [active, setActive] = useState(false);
  const [taps, setTaps] = useState(0);
  const [remaining, setRemaining] = useState(durationMs / 1000);
  const activeRef = useRef(false);
  const timerRef = useRef<number | null>(null);
  const tickRef = useRef<number | null>(null);

  const start = useCallback(() => {
    tapsRef.current = [];
    setTaps(0);
    activeRef.current = true;
    setActive(true);
    const t0 = performance.now();
    setRemaining(durationMs / 1000);
    tickRef.current = window.setInterval(() => {
      setRemaining(Math.max(0, (durationMs - (performance.now() - t0)) / 1000));
    }, 200);
    timerRef.current = window.setTimeout(() => {
      activeRef.current = false;
      setActive(false);
      if (tickRef.current) window.clearInterval(tickRef.current);
    }, durationMs);
  }, [durationMs]);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (!activeRef.current || e.repeat) return;
      const key = e.key.toUpperCase();
      if (key !== "F" && key !== "J") return;
      e.preventDefault();
      tapsRef.current.push({ timestampMs: performance.now(), key });
      setTaps(tapsRef.current.length);
    };
    window.addEventListener("keydown", down);
    return () => window.removeEventListener("keydown", down);
  }, []);

  useEffect(() => () => {
    if (timerRef.current) window.clearTimeout(timerRef.current);
    if (tickRef.current) window.clearInterval(tickRef.current);
  }, []);

  return { active, taps, remaining, start, getTaps: () => [...tapsRef.current] };
}
