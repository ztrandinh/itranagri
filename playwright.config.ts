import { defineConfig, devices } from "@playwright/test";

/** Playwright trước đây là dependency chết (cài nhưng không config/test nào) — quyết định chủ đầu
 *  tư: viết test thật. Chạy: `pnpm test:e2e` (tự khởi `pnpm dev` ở PORT nếu chưa có sẵn, xem webServer
 *  dưới) — cần DB đã migrate + seed (`pnpm db:migrate && pnpm db:seed:history`). */
const PORT = process.env.E2E_PORT ?? "3199";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1, // các test dùng chung 1 tài khoản a1/1 DB dev — chạy song song 2 file dễ đụng nhau
  retries: 0,
  reporter: [["list"]],
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: `pnpm dev --port ${PORT}`,
    url: `http://localhost:${PORT}/api/health`,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
