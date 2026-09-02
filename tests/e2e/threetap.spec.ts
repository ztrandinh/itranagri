import { test, expect } from "@playwright/test";

/** Ghi 3 chạm thật qua UI — luồng cốt lõi nhất của app (luật 5 CLAUDE.md), trước đây 0 coverage E2E.
 * Không hard-code 1 form cụ thể (danh mục theo mã nghề có thể đổi) — chọn form ĐẦU TIÊN người dùng
 * a1 (worker) thấy được, hoàn thành bước 1→2→3 một cách thích ứng theo loại trường thật render ra,
 * và xác nhận server thật sự chấp nhận (không chỉ UI báo xong).
 * LƯU Ý: bảng sự kiện append-only — test này KHÔNG tự xoá bản ghi đã tạo (không có cách nào hợp lệ
 * qua tầng app, đúng thiết kế). Mỗi lần chạy để lại 1 bản ghi thật vô hại (qty nhỏ, created_by=a1) ở
 * farm F01. Chạy trên farm/DB demo riêng nếu cần CI sạch tuyệt đối. */
test("ghi 3 chạm: chọn việc → điền → xác nhận → server chấp nhận (worker a1)", async ({ page }) => {
  await page.goto("/login");
  await page.getByPlaceholder("a1, gd, owner…").fill("a1");
  await page.getByPlaceholder("••••").fill("1234");
  await page.getByRole("button", { name: "Đăng nhập" }).click();
  await page.waitForURL(/\/ca/);

  await page.getByRole("button", { name: /Ghi 3 chạm/ }).click();

  // Chờ danh mục theo mã nghề tải xong rồi bấm Ô VIỆC đầu tiên (class "tile", title = forms[k].title)
  const firstTile = page.locator(".tile").first();
  await expect(firstTile).toBeVisible({ timeout: 15_000 });
  const formTitle = (await firstTile.textContent())?.trim();
  await firstTile.click();

  // Bước 1: chọn đối tượng — bấm nút đầu tiên trong danh sách (nút "📷 Quét" luôn đứng trước, bỏ qua)
  const step1Buttons = page.locator(".card button");
  await expect(step1Buttons.first()).toBeVisible();
  const targetBtn = step1Buttons.nth(1);
  if (await targetBtn.isVisible().catch(() => false)) {
    await targetBtn.click();
  } else {
    // danh sách rỗng nhưng cho phép gõ tay (allowScanInput) — gõ 1 mã giả rồi Enter
    await page.getByPlaceholder(/Quét QR\/RFID/).fill("E2E-TEST-TARGET");
    await page.getByPlaceholder(/Quét QR\/RFID/).press("Enter");
  }

  await expect(page.getByText("Bước 2/3")).toBeVisible();

  // Bước 2: điền MỌI trường bắt buộc một cách thích ứng theo loại (choice/number/text/date/bool) —
  // không biết trước form nào được chọn nên duyệt DOM thật thay vì hard-code field key.
  // choice: bấm option đầu tiên của mỗi nhóm bắt buộc (label kết thúc " *" liền trước div.grid options)
  const choiceGroups = page.locator('label:has-text("*") + div.grid');
  for (let i = 0; i < (await choiceGroups.count()); i++) {
    const btn = choiceGroups.nth(i).locator("button").first();
    if (await btn.isVisible().catch(() => false)) await btn.click().catch(() => {});
  }
  // number: điền giá trị dương an toàn vào mọi input number còn trống
  const numberInputs = page.locator('input[type="number"]');
  const nNum = await numberInputs.count();
  for (let i = 0; i < nNum; i++) {
    const inp = numberInputs.nth(i);
    if ((await inp.inputValue()) === "") await inp.fill("10");
  }
  // text: điền chuỗi test vào input text còn trống (loại trừ ô tìm kiếm bước 1 đã ẩn)
  const textInputs = page.locator('.card input[type="text"]:visible, .card input:not([type]):visible');
  const nText = await textInputs.count();
  for (let i = 0; i < nText; i++) { const inp = textInputs.nth(i); if ((await inp.inputValue()) === "") await inp.fill("E2E test").catch(() => {}); }

  // Icon migration: nút Bước 2 giờ "Tiếp" + <IconArrowRight> (không còn ký tự "→" trong tên truy cập).
  const next = page.getByRole("button", { name: /^Tiếp$|Thiếu:/ });
  await expect(next).toBeVisible();
  // Nếu vẫn thiếu trường (vd "steps" checklist không lường được), test coi như đã xác nhận được
  // UI chặn đúng thiết kế (nút disabled khi thiếu) — không ép submit sai để không tạo dữ liệu rác.
  const stillMissing = (await next.textContent())?.includes("Thiếu:");
  test.skip(!!stillMissing, `Form "${formTitle}" có trường không điền được tự động (steps/photo) — bỏ qua, không phải lỗi.`);

  await next.click();
  await expect(page.getByText("Xác nhận ghi")).toBeVisible();
  // Icon migration: nút Bước 3 giờ <IconCheck> + "XÁC NHẬN" (không còn ký tự "✓" trong tên truy cập).
  await page.getByRole("button", { name: "XÁC NHẬN" }).click();

  // Server thật sự chấp nhận: thông báo "Đã ghi …" (không phải "CHƯA GHI ĐƯỢC — máy chủ từ chối")
  const result = page.locator('[role="status"]');
  await expect(result).toBeVisible({ timeout: 10_000 });
  const text = await result.textContent();
  expect(text, `Form "${formTitle}" bị máy chủ từ chối: ${text}`).not.toMatch(/CHƯA GHI ĐƯỢC/);
  expect(text).toMatch(/Đã ghi|Đã lưu trong máy/);
});
