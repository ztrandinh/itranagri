# 19 · KẾ HOẠCH NÂNG CẤP UX/UI — TỪ "ĐẠT CHUẨN" LÊN "ĐẲNG CẤP"

> Mốc hiện tại: **6.0–6.5/10** (sau đợt sửa lỗi + refresh giao diện 19/08/2026).
> Đích: **8.5+/10** bằng kỹ thuật; **9+** chỉ đạt được sau nhiều vòng test với người dùng thật.
> Nguyên tắc: **không xoá tính năng**; mọi đợt phải verify được; commit từng đợt; không phá nhánh phiên khác.

## Cách nghiệm thu chung (áp cho mọi đợt)
- [ ] `pnpm exec tsc --noEmit` → exit 0
- [ ] `pnpm lint` → 0 error
- [ ] `pnpm build` → toàn bộ route compile
- [ ] Test runtime trên app thật (desktop + mobile 375px), console không lỗi mới
- [ ] Commit riêng từng đợt, mô tả rõ verify

---

## ĐỢT 1 — DESIGN SYSTEM NỀN
*Vì sao trước: mọi đợt sau dựa vào token & primitive này.*

### Token
- [ ] Màu **ngữ nghĩa** (không phải tên màu): `--bg / --surface / --surface-2 / --line / --ink / --muted / --brand / --success / --warning / --danger / --info`
- [ ] Spacing scale 4pt: `--s1..--s8`
- [ ] Radius: `--r-sm / --r-md / --r-lg / --r-full`
- [ ] Shadow: `--sh-1 / --sh-2 / --sh-3`
- [ ] Motion: `--dur-fast(120ms) / --dur(180ms) / --dur-slow(280ms)`, `--ease`
- [ ] z-index thang bậc: `--z-header / --z-sheet / --z-modal / --z-toast`
- [ ] **Dark mode** định nghĩa lại token dưới `prefers-color-scheme` + `[data-theme]`, có nút chuyển

### Primitives (`src/components/ui/`)
- [ ] `Button` (variant primary/secondary/danger/ghost · size sm/md/lg · loading · icon)
- [ ] `Field` (đã có — bổ sung select/textarea/checkbox)
- [ ] `Card`, `Badge` (semantic: success/warning/danger/neutral)
- [ ] `Skeleton` (text/row/card)
- [ ] `EmptyState` (icon + tiêu đề + mô tả + hành động)
- [ ] `Sheet` (bottom sheet cho mobile, dùng lại Modal ở desktop)
- [ ] `DataTable` (khung chung: sticky header, cột đầu dính, overflow, empty/loading)

### Tài liệu sống
- [ ] Trang `/design-system` — hiển thị toàn bộ token + primitive + trạng thái, để không trôi lại

**Nghiệm thu:** dark mode bật/tắt không vỡ màn nào; mọi primitive render đúng ở 2 theme; 0 hardcode màu mới.

---

## ĐỢT 2 — MOTION & OPTIMISTIC UI
*Đây là thứ tạo cảm giác "mượt" ngay lập tức.*

- [ ] Áp motion token: hover/active/focus của nút, thẻ, hàng bảng
- [ ] Chuyển **tab** có transition (fade/slide 180ms), không nhảy cụp
- [ ] **Skeleton** thay màn trống khi `loading` (dùng cờ `loading` của `useData`)
- [ ] **Toast** có animation vào/ra (slide-up + fade), stack nhiều toast
- [ ] **Modal/Sheet** có animation mở/đóng (scale+fade / slide-up)
- [ ] **Optimistic UI**: ghi 3 chạm hiện ngay "đã ghi" (queue offline đã có) — bổ sung phản hồi tức thì cho các nút hành động phổ biến (duyệt, xong việc)
- [ ] `@media (prefers-reduced-motion: reduce)` → tắt mọi animation

**Nghiệm thu:** không còn màn nhảy cụp khi đổi tab/tải dữ liệu; đo không rớt FPS; reduced-motion hoạt động.

---

## ĐỢT 3 — MOBILE-FIRST CHO CÔNG NHÂN
*80% người dùng thật là công nhân cầm điện thoại ngoài trời.*

- [ ] **Bottom navigation** (vùng ngón cái) cho vai `worker`: Việc · Ghi · Quét · Tôi
- [ ] **Bottom sheet** thay modal trên mobile (Sheet primitive)
- [ ] **Chế độ nắng** (high-contrast outdoor): tăng tương phản, chữ đậm, bỏ nền nhạt — nút bật ở /tai-khoan, nhớ theo máy
- [ ] `safe-area-inset` cho máy có tai thỏ
- [ ] Pull-to-refresh ở danh sách chính
- [ ] Rà lại target chạm ≥48px ở mọi nút thao tác chính trên mobile
- [ ] Ẩn cột phụ trên mobile (bảng ưu tiên 3 cột quan trọng nhất)

**Nghiệm thu:** thao tác ghi 1 bản ghi bằng **một tay** ≤20s; không phải với lên góc trên; đọc được ngoài nắng.

---

## ĐỢT 4 — GIẢM MẬT ĐỘ + BỎ JARGON

- [ ] **Từ điển thuật ngữ** (`lib/glossary.ts`): RC1–RC12, FEFO, PHI, ROP, D5, K1–K9, EPCIS, TT66, CAPA, NC, S&OP…
- [ ] Component `Term` — gạch chân chấm, hover/chạm hiện giải thích
- [ ] Áp `Term` cho các nhãn kỹ thuật đang lộ trên màn chính
- [ ] **Progressive disclosure**: tab > 6 → gom phần ít dùng vào "Thêm ▾"
- [ ] `/quan-tri`: nhóm 124 bảng theo phòng ban + ô tìm (đã có group, cần gom + tìm)
- [ ] Viết lại nhãn khó hiểu sang ngôn ngữ đời thường (giữ mã trong ngoặc)

**Nghiệm thu:** người chưa từng dùng đọc hiểu được màn chính không cần hỏi; không còn mã kỹ thuật trần trên màn công nhân.

---

## ĐỢT 5 — BẢNG DỮ LIỆU & HIỆU NĂNG

- [ ] `DataTable`: sticky header + cột đầu dính khi cuộn ngang
- [ ] Virtualization cho danh sách > 200 dòng
- [ ] **Lazy-load recharts** (hiện ~400KB/trang biểu đồ) → `next/dynamic`, chỉ tải khi cần
- [ ] Code splitting các panel nặng
- [ ] Đo lại Core Web Vitals trên `next build` + `next start`, ghi số vào docs

**Nghiệm thu:** JS trang biểu đồ giảm ≥30%; cuộn bảng 1000 dòng mượt; CWV có số đo thật.

---

## ĐỢT 6 — A11Y HOÀN CHỈNH + COMMAND PALETTE

- [ ] Quét WCAG 2.2 AA toàn bộ: aria-label cho input chỉ có placeholder, `role`/`tabIndex`/`onKeyDown` cho hàng bảng bấm được
- [ ] Skip-link "Tới nội dung chính"
- [ ] Kiểm tra tương phản mọi cặp màu ở cả 2 theme
- [ ] Điều hướng bàn phím toàn app (Tab/Enter/Esc/mũi tên trong tab)
- [ ] **Command palette** `Ctrl/Cmd+K`: tìm trang, tìm đối tượng, chạy hành động nhanh
- [ ] Phím tắt: `g+d` (đàn), `g+k` (kho), `n` (ghi mới)…

**Nghiệm thu:** thao tác trọn vẹn 1 luồng chỉ bằng bàn phím; 0 lỗi contrast; palette mở <100ms.

---

## ĐỢT 7 — ANALYTICS HEART + TEST NGƯỜI DÙNG THẬT

- [ ] Bảng `ux_events` (append-only, có farm_id/staff_id/role)
- [ ] Instrument: bắt đầu/hoàn tất tác vụ, thời gian, hủy giữa chừng, lỗi form, đường đi
- [ ] Trang `/ux` (chỉ owner/it): task-success theo vai, time-on-task, màn hay bỏ dở, lỗi hay gặp
- [ ] **Kịch bản test** với công nhân thật: 6 tác vụ lõi (ghi cho ăn, cân bò, nhập kho, báo sự cố, xem việc, nộp phiếu giấy)
- [ ] Checklist quan sát (không nhắc, đo thời gian, đếm lần vấp, ghi câu hỏi họ hỏi)
- [ ] Biểu mẫu ghi nhận + cách tổng hợp thành backlog sửa

**Nghiệm thu:** có số liệu thật của ≥5 người dùng cho ≥6 tác vụ; ra được danh sách sửa theo mức độ vấp.

---

## Sau đợt 7
Vòng lặp: test → sửa → đo lại. Đây là chỗ 8 → 9+ được tạo ra, không phải trong editor.
