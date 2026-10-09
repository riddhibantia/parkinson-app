import { defineConfig, devices } from "@playwright/test";
import path from "path";

const PORT = 3111;
const API_PORT = 8101;
const BACKEND = path.resolve(__dirname, "../backend");
const VENV_PY = path.join(BACKEND, ".venv", "Scripts", "python");

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  retries: 0,
  use: { baseURL: `http://localhost:${PORT}`, ...devices["Desktop Chrome"] },
  webServer: [
    {
      // Local FastAPI (pinned venv, sklearn 1.6.1, real RF artifact).
      command: `"${VENV_PY}" -m uvicorn app.main:app --port ${API_PORT}`,
      url: `http://localhost:${API_PORT}/api/v1/health`,
      cwd: BACKEND,
      reuseExistingServer: true,
      timeout: 180_000,
    },
    {
      command: `npx next dev --port ${PORT}`,
      url: `http://localhost:${PORT}`,
      reuseExistingServer: false,
      timeout: 180_000,
      env: { PORT: String(PORT), NEXT_PUBLIC_API_URL: `http://localhost:${API_PORT}` },
    },
  ],
});
