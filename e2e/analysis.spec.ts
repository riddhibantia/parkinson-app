import { expect, test } from "@playwright/test";

/**
 * Local integration E2E (Phases 13/14/16/18 without cloud): real Chromium
 * typing against the REAL local FastAPI (pinned venv, authoritative RF).
 * No Supabase here — persistence assertions use the exact-id snapshot
 * path; Supabase round-trips stay cloud-gated in session.spec.ts.
 */
const API = "http://localhost:8101";

const FEATS = {
  ht_mean: 105, ht_std: 11, ft_mean: 190, ft_std: 21, ikl_mean: 290, ikl_std: 26,
  left_ht_mean: 104, right_ht_mean: 106, hand_asymmetry: 0.03,
  pause_frequency: 1.2, typing_speed: 2.6, session_consistency: 0.12,
};

const bodyFor = (sid: string, uid: string, extra = {}) => ({
  sessionId: sid, userId: uid, sessionType: "structured", deviceId: "kbd-a",
  startedAt: "2026-09-01T10:00:00Z", endedAt: "2026-09-01T10:02:00Z",
  durationMs: 120000, keystrokeCount: 120, qualityFlags: [],
  features: FEATS, ...extra,
});

test("backend health is fail-closed and explicit", async ({ request }) => {
  const r = await request.get(`${API}/api/v1/health`);
  expect(r.ok()).toBeTruthy();
  const j = await r.json();
  expect(j.layer1.loaded).toBe(true);
  expect(j.layer1.match).toBe(true);
});

test("real typing session → same sessionId → real Layer 1 insight", async ({ page }) => {
  await page.goto("/test");
  await page.getByRole("button", { name: "Start session" }).click();
  await page.locator("textarea").click();
  await page.keyboard.type(
    "the morning light moves slowly across the quiet garden wall and river stones",
    { delay: 35 },
  );
  await page.getByRole("button", { name: "Finish & analyze" }).click();
  await expect(page).toHaveURL(/\/session\/[0-9a-f-]{36}/, { timeout: 60_000 });
  const id = page.url().split("/session/")[1];
  // Exact id displayed, single canonical id end-to-end.
  await expect(page.getByText(id.slice(0, 8), { exact: false }).first()).toBeVisible();
  const stored = await page.evaluate(() => localStorage.getItem("parkintrace-last-session"));
  expect(stored).toBe(id);
  // Real insight: categorical status + real metric values with units.
  await expect(page.getByText(/normal|watch|attention|preview/)).toBeVisible();
  await expect(page.getByText(/ms/).first()).toBeVisible();
  // Never a diagnosis, never a probability percentage.
  await expect(page.getByText(/Parkinson's detected|You have Parkinson|Diagnosis confirmed|%/i)).toHaveCount(0);
});

test("analysis echoes the exact sessionId; Layer 2 device mismatch is explicit", async ({ request }) => {
  const sid = crypto.randomUUID();
  const uid = crypto.randomUUID();
  const r = await request.post(`${API}/api/v1/analysis/session`, { data: bodyFor(sid, uid) });
  expect(r.ok()).toBeTruthy();
  const j = await r.json();
  expect(j.sessionId).toBe(sid);
  expect(["normal", "watch", "attention"]).toContain(j.layer1.status);
  const p = j.layer1.pdProbability;
  expect(typeof p === "number" && p >= 0 && p <= 1).toBe(true);
  expect(j.layer2.baselineStatus).toBe("building");

  const baseline = {
    features: { ht_mean: { mean: 100, std: 5, median: 100, mad: 3 } },
    anchor_device_id: "kbd-a",
  };
  const r2 = await request.post(`${API}/api/v1/analysis/session`, {
    data: bodyFor(crypto.randomUUID(), uid, { deviceId: "other-kbd", baseline }),
  });
  const j2 = await r2.json();
  expect(j2.layer2.status).toBe("device_mismatch");
});
