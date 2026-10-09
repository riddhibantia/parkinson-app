/** Canonical session contract (mirrors backend Pydantic schema).
 *  External JSON: camelCase. All timing: MILLISECONDS.
 */

export type SessionType = "structured" | "free" | "motor_task";

export interface KeystrokeEventWire {
  pressTimestamp: number; // ms, monotonic (event.timeStamp basis)
  releaseTimestamp: number; // ms
  hand: "left" | "right";
  row: number;
  keyType: "character" | "backspace" | "control";
}

export interface MotorTapWire {
  timestampMs: number;
  key: string;
}

export interface SessionPayload {
  sessionId: string;
  userId: string;
  sessionType: SessionType;
  deviceId: string;
  startedAt: string; // ISO-8601
  endedAt: string; // ISO-8601
  durationMs: number;
  keystrokeCount: number;
  qualityFlags: string[];
  events: KeystrokeEventWire[];
  taps: MotorTapWire[];
  features: Record<string, number>;
}

export interface SessionRow {
  id: string;
  user_id: string;
  started_at: string;
  ended_at: string;
  session_type: SessionType;
  device_id: string;
  valid: boolean;
  quality_flags: string[];
}

export interface SessionMetricsRow {
  session_id: string;
  user_id: string;
  features: Record<string, number | null>;
  quality_metrics: Record<string, unknown>;
  layer1_result: Record<string, unknown> | null;
  layer2_result: Record<string, unknown> | null;
  within_session_series: {
    elapsed_ms: number[];
    rolling_ht_ms: number[];
    rolling_ft_ms: number[];
    rolling_ikl_ms: number[];
  } | null;
  created_at: string;
}

export class SessionNotFoundError extends Error {
  constructor(id: string) {
    super(`Session not found: ${id}`);
    this.name = "SessionNotFoundError";
  }
}
