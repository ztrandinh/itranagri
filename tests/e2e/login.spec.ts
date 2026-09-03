import { test, expect } from "@playwright/test";

/** Login thật qua UI (không gọi API trực tiếp) — xác nhận form thật hoạt động end-to-end:
 * nhập sai PIN báo lỗi đúng, nhập đúng chuyển trang đúng vai, và trang được bảo vệ chặn khi chưa đăng nhập. */
test.describe("Đăng nhập", () => {
  test("sai PIN báo lỗi rõ ràng, không chuyển trang", async ({ page }) => {
    await page.goto("/login");
    await page.getByPlaceholder("a1, gd, owner…").fill("owner");
    await page.getByPlaceholder("••••").fill("0000");
    await page.getByRole("button", { name: "Đăng nhập" }).click();
    await expect(page.getByText("Sai tài khoản hoặc PIN")).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
  });

  test("đúng tài khoản/PIN chuyển đúng trang theo vai (worker a1 → /ca)", async ({ page }) => {
    await page.goto("/login");
    await page.getByPlaceholder("a1, gd, owner…").fill("a1");
    await page.getByPlaceholder("••••").fill("1234");
    await page.getByRole("button", { name: "Đăng nhập" }).click();
    await page.waitForURL(/\/ca/);
    await expect(page).toHaveURL(/\/ca/);
  });

  test("chưa đăng nhập bị chặn khỏi trang nội bộ, chuyển về /login", async ({ page, context }) => {
    await context.clearCookies();
    await page.goto("/ca");
    await page.waitForURL(/\/login/);
    await expect(page).toHaveURL(/\/login\?next=/);
  });
});
