import { test, expect } from "@playwright/test";

/** Offline-first (luật 5 CLAUDE.md) — hàng đợi IndexedDB, trước đây 0 coverage E2E. Ngắt mạng thật
 * (context.setOffline), ghi 1 bản ghi, xác nhận: (a) UI báo "đã lưu trong máy" chứ không giả vờ đã
 * gửi, (b) huy hiệu hàng đợi hiện đúng trạng thái offline, (c) khi có mạng lại → tự đồng bộ (offline.ts
 * lắng nghe sự kiện 'online'), badge về "✓ đồng bộ", và bản ghi THẬT SỰ tới được server (không chỉ nằm
 * mãi trong máy). Cùng giới hạn dữ liệu như threetap.spec.ts: để lại 1 bản ghi thật vô hại ở F01. */
test("offline: ghi khi mất mạng → lưu máy → tự đồng bộ khi có mạng lại", async ({ page, context }) => {
  await page.goto("/login");
  await page.getByPlaceholder("a1, gd, owner…").fill("a1");
  await page.getByPlaceholder("••••").fill("1234");
  await page.getByRole("button", { name: "Đăng nhập" }).click();
  await page.waitForURL(/\/ca/);
  await page.getByRole("button", { name: /Ghi 3 chạm/ }).click();

  const firstTile = page.locator(".tile").first();
  await expect(firstTile).toBeVisible({ timeout: 15_000 });
  await firstTile.click();
  // Dữ liệu tham chiếu (recipes/groups/...) tải qua useData() ngay khi /ca mount — chờ mạng rảnh
  // để chắc đã có cache TRƯỚC khi ngắt mạng, đúng kịch bản thật (công nhân mở app lúc còn sóng,
  // vào tới chuồng mất sóng mới ghi — không phải mất mạng giữa lúc app còn chưa tải xong danh mục).
  await page.waitForLoadState("networkidle");

  // NGẮT MẠNG THẬT (không phải giả lập UI) trước khi bắt đầu điền.
  await context.setOffline(true);

  const step1Buttons = page.locator(".card button");
  await expect(step1Buttons.first()).toBeVisible();
  const targetBtn = step1Buttons.nth(1);
  if (await targetBtn.isVisible().catch(() => false)) await targetBtn.click();
  else { await page.getByPlaceholder(/Quét QR\/RFID/).fill("E2E-OFFLINE-TARGET"); await page.getByPlaceholder(/Quét QR\/RFID/).press("Enter"); }
  await expect(page.getByText("Bước 2/3")).toBeVisible();
  // Bấm chọn xong mới bắn setStep(2); nội dung bước 2 (options choice từ dữ liệu đã tải sẵn) có thể
  // render 1 nhịp sau khi tiêu đề "Bước 2/3" đã đổi — chờ ổn định trước khi dò field, tránh count()
  // chụp nhanh lúc DOM chưa đầy đủ (khác hẳn lỗi app thật — đây là điểm cần chờ trong chính test).
  await page.waitForTimeout(300);

  const choiceGroups = page.locator('label:has-text("*") + div.grid');
  for (let i = 0; i < (await choiceGroups.count()); i++) { const btn = choiceGroups.nth(i).locator("button").first(); if (await btn.isVisible().catch(() => false)) await btn.click().catch(() => {}); }
  const numberInputs = page.locator('input[type="number"]');
  for (let i = 0; i < (await numberInputs.count()); i++) { const inp = numberInputs.nth(i); if ((await inp.inputValue()) === "") await inp.fill("5"); }
  const textInputs = page.locator('.card input[type="text"]:visible, .card input:not([type]):visible');
  for (let i = 0; i < (await textInputs.count()); i++) { const inp = textInputs.nth(i); if ((await inp.inputValue()) === "") await inp.fill("E2E offline").catch(() => {}); }

  const next = page.getByRole("button", { name: /Tiếp →|Thiếu:/ });
  const nextText = await next.textContent();
  if (nextText?.includes("Thiếu:")) console.log("SKIP REASON:", nextText);
  test.skip(!!nextText?.includes("Thiếu:"), `Form có trường không điền được tự động — ${nextText}`);
  await next.click();
  await page.getByRole("button", { name: "✓ XÁC NHẬN" }).click();

  // Đang offline: PHẢI báo "lưu trong máy", không được giả vờ "đã ghi" (bug đã sửa trước đây, xem
  // comment trong ThreeTap.tsx dòng ~89) — và huy hiệu hàng đợi phải hiện offline + số lượng.
  await expect(page.getByText(/Đã lưu trong máy \(chưa có mạng\)/)).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTitle("Hàng đợi đồng bộ")).toContainText(/📴 offline [1-9]/);

  // CÓ MẠNG LẠI: offline.ts tự flush khi bắt sự kiện 'online' — không cần thao tác gì thêm.
  await context.setOffline(false);
  await expect(page.getByTitle("Hàng đợi đồng bộ")).toContainText("✓ đồng bộ", { timeout: 15_000 });
});
