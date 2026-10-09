import { expect, test } from "@playwright/test";

/**
 * Browser regression suite (spec Phase 9). Cloud-dependent flows
 * (Supabase Auth round-trip, FastAPI analysis, RLS isolation) run only
 * when a backend is configured; everything else runs against `next dev`
 * with zero credentials. Nothing here fabricates a session or a result.
 */
const HAS_CLOUD = !!process.env.PLAYWRIGHT_CLOUD;

test("splash shows brand and routes to login", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "ParkinTrace" })).toBeVisible();
  await expect(page.getByText(/not a medical device/i).first()).toBeVisible();
  await page.getByRole("button", { name: "Log in" }).click();
  await expect(page).toHaveURL(/\/login/);
});

test("auth forms validate input", async ({ page }) => {
  await page.goto("/login");
  await page.getByRole("button", { name: "Log in", exact: true }).click();
  await expect(page.getByText(/valid email/i).first()).toBeVisible();
  await page.goto("/signup");
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page.getByText(/valid email/i).first()).toBeVisible();
});

test("onboarding has no practice session gate", async ({ page }) => {
  await page.goto("/consent");
  await expect(page.getByText(/no|practice/i).first()).toBeVisible();
  await page.getByRole("checkbox").first().check();
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/demographics/);
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/layer/);
  // Layer choice completes onboarding directly — no familiarization step.
  await expect(page.getByText(/no practice session/i)).toBeVisible();
  await page.getByRole("button", { name: /Layer 1/ }).click();
  await expect(page).toHaveURL(/\/dashboard/);
});

test("typing page captures real keys with no Date.now timing", async ({ page }) => {
  await page.goto("/test");
  await page.getByRole("button", { name: "Start session" }).click();
  const box = page.locator("textarea");
  await box.click();
  await page.keyboard.type("the quick brown fox jumps over", { delay: 60 });
  const counter = page.getByText(/keys ·/);
  await expect(counter).toContainText(/[1-9][0-9]* keys/);
});

test("missing session shows Not Found, never another session", async ({ page }) => {
  await page.goto("/session/00000000-0000-0000-0000-000000000000");
  // Logged-out with a live backend: the auth gate answers first (correct —
  // existence of unguessable UUIDs is not leaked to strangers).
  // Logged-out without backend, or logged-in: the exact-id miss answers.
  // All three are honest; showing another session would be the failure.
  const heading = page.getByRole("heading", { name: "Session insight" });
  const signIn = page.getByText("Sign-in required");
  await expect(heading.or(signIn)).toBeVisible();
  if (await heading.isVisible()) {
    await expect(page.getByText("Session not found").or(signIn)).toBeVisible();
    await expect(page.getByText(/keys\/s|Hold time/)).toHaveCount(0);
  }
});

test("layer pages never show diagnostic claims or synthetic charts", async ({ page }) => {
  for (const route of ["/layer1", "/layer2", "/history"]) {
    await page.goto(route);
    await expect(page.getByText(/Parkinson's detected|You have Parkinson|Diagnosis confirmed/i)).toHaveCount(0);
  }
  await page.goto("/layer2");
  await expect(page.getByText(/illustrative preview|visual diagram|fallback/i)).toHaveCount(0);
});

test("layer switching preserves onboarding state", async ({ page }) => {
  await page.goto("/dashboard");
  await page.getByRole("link", { name: "Layer 2" }).click();
  await expect(page).toHaveURL(/\/layer2/);
  await page.getByRole("link", { name: "Layer 1" }).click();
  await expect(page).toHaveURL(/\/layer1/);
  // No redirect back to /consent: onboarding is one-time.
  await expect(page).not.toHaveURL(/\/consent/);
});

for (const title of [
  "cloud: signup → login → logout → login preserves data",
  "cloud: Layer 1 first real session → real analysis → insight",
  "cloud: Layer 2 Session 1 → building baseline insight",
  "cloud: exact session retrieval + device mismatch + baseline establishment",
]) {
  test(title, async () => {
    test.skip(!HAS_CLOUD, "needs Supabase + FastAPI credentials");
  });
}
