import { defineConfig } from "vitest/config";

// Chỉ chạy test NGUỒN trong tests/. Trước đây vitest quét cả bản build trong
// .next/standalone/tests/ — bản copy CŨ, chạy trên schema mới nên báo lỗi giả
// (audit INSERT vs UPDATE, gl_post, workflow) khiến `pnpm test` đỏ oan.
export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    exclude: ["**/node_modules/**", "**/.next/**", "**/dist/**"],
    testTimeout: 30000,
  },
});
