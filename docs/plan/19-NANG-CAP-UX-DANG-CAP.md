# 19 · KẾ HOẠCH NÂNG CẤP UX/UI — TỪ "ĐẠT CHUẨN" LÊN "ĐẲNG CẤP"

> Mốc hiện tại: **6.0–6.5/10** (sau đợt sửa lỗi + refresh giao diện 19/08/2026).
> Đích: **8.5+/10** bằng kỹ thuật; **9+** chỉ đạt được sau nhiều vòng test với người dùng thật.
> Nguyên tắc: **không xoá tính năng**; mọi đợt phải verify được; commit từng đợt; không phá nhánh phiên khác.
>
> **Cập nhật 31/08/2026 (audit frontend toàn diện, xác minh trực tiếp trên code + app chạy thật, không theo checkbox cũ):**
> phần lớn Đợt 1–3+6 đã merge vào `main` từ trước nhưng file này chưa từng tick lại — đã tick đúng thực tế bên dưới.
> Trong đợt audit này còn: phát hiện + sửa 1 bug tương phản dark mode thật (lớp bù class cứng chỉ chạy khi bấm nút chuyển tối, không chạy khi dark mode tự động theo hệ điều hành), đổi bảng màu thương hiệu (trước là emerald tự AI đặt không ai duyệt, trùng màu với "thành công" — nay tách bạch), và đang gắn `DataBoundary` (đã build ở Đợt 1 nhưng CHƯA từng dùng ở panel nào) vào toàn bộ nơi có bug nhấp nháy "chưa có dữ liệu" lúc tải.

## Cách nghiệm thu chung (áp cho mọi đợt)
- [ ] `pnpm exec tsc --noEmit` → exit 0
- [ ] `pnpm lint` → 0 error
- [ ] `pnpm build` → toàn bộ route compile
- [ ] Test runtime trên app thật (desktop + mobile 375px), console không lỗi mới
- [ ] Commit riêng từng đợt, mô tả rõ verify

---

## ĐỢT 1 — DESIGN SYSTEM NỀN ✅ (đã merge `main`; 1 bug dark-mode đã vá thêm 31/08)
*Vì sao trước: mọi đợt sau dựa vào token & primitive này.*

### Token
- [x] Màu **ngữ nghĩa**: `--bg / --surface / --surface-2 / --line / --ink / --muted / --brand / --success / --warning / --danger / --info` (+ `--gold` mới, cho mốc chứng nhận/cao cấp)
- [x] Spacing scale 4pt: `--s1..--s8`
- [x] Radius: `--r-sm / --r-md / --r-lg / --r-full`
- [x] Shadow: `--sh-1 / --sh-2 / --sh-3` (đã nâng độ nổi rõ hơn 31/08, bản gốc quá phẳng)
- [x] Motion: `--dur-fast(120ms) / --dur(180ms) / --dur-slow(280ms)`, `--ease`
- [x] z-index thang bậc: `--z-header / --z-sheet / --z-modal / --z-toast`
- [x] **Dark mode** định nghĩa lại token dưới `prefers-color-scheme` + `[data-theme]`, có nút chuyển — **nhưng đã có bug thật**: lớp bù cho các class Tailwind cứng (`text-slate-900`, `bg-white`...) chỉ áp dụng khi bấm nút chuyển tối thủ công (`[data-theme="dark"]`), KHÔNG áp dụng khi dark mode tự động theo hệ điều hành (`prefers-color-scheme`, không có `data-theme`) — chữ tối trên nền tối gần như vô hình cho bất kỳ ai có máy mặc định dark mode mà không bấm gì. Đã sửa 31/08 (mở rộng lớp bù cho cả 2 đường), xác minh bằng `getComputedStyle` thật trên app chạy.
- [x] Bảng màu thương hiệu: đã đổi từ emerald (do 1 phiên AI trước tự đặt, ghi "professional palette" trong commit message nhưng không ai duyệt, trùng màu với `--success`) sang hướng "Tín nhiệm quốc tế" (teal + vàng đồng) do chủ đầu tư chọn từ 3 phương án — 31/08.

### Primitives (`src/components/ui/`)
- [x] `Button`, `Field`, `Modal`, `Sheet`, `ConfirmDialog`, `PromptDialog`, `Toast`, `EmptyState`, `Skeleton`, `ThemeToggle`, `CommandPalette`, `BottomNav` — đã có, đã dùng
- [x] `Badge` (semantic qua `.b-red/.b-yel/.b-grn/.b-gray`, đã đổi sang token 31/08 để đúng cả 2 theme)
- [ ] `DataTable` (khung chung sticky+ảo hóa) — CHƯA có, xem Đợt 5
- [x] `DataBoundary` (chuẩn hoá loading/error/empty) — **đã build từ đầu nhưng 0 panel dùng tới đến 31/08** — đang gắn vào toàn bộ nơi có bug nhấp nháy "chưa có dữ liệu" lúc tải (43 vị trí / 22 file, xác nhận bằng grep + xác minh network trace thật)

### Tài liệu sống
- [x] Trang `/design-system` — có, đang phản ánh bảng màu mới

**Nghiệm thu:** dark mode bật/tắt không vỡ màn nào (đã fix bug tự động); mọi primitive render đúng ở 2 theme; 0 hardcode màu mới (đã dọn `bg-emerald-*`/`text-emerald-*` còn sót ở `ModuleIntro.tsx`, `More.tsx`).

---

## ĐỢT 2 — MOTION & OPTIMISTIC UI ✅ phần lớn (merge `main`, bổ sung 31/08)
*Đây là thứ tạo cảm giác "mượt" ngay lập tức.*

- [x] Áp motion token: hover/active/focus của nút, thẻ, hàng bảng (mở rộng 31/08: `.card`/`.kpi` giờ cũng nổi nhẹ khi hover, trước chỉ `.tile`)
- [x] Trang vào có transition mượt (`<main>` của `Shell.tsx` tự động, áp mọi trang — bổ sung 31/08, trước chỉ vài chỗ lẻ)
- [x] **Skeleton** thay màn trống khi `loading` — đúng nghĩa chỉ áp cho 43 vị trí vừa gắn `DataBoundary` (31/08); các chỗ khác vẫn cần rà thêm
- [x] **Toast** có animation vào/ra, stack nhiều toast
- [x] **Modal/Sheet** có animation mở/đóng
- [ ] **Optimistic UI** cho nút duyệt/xong việc phổ biến — CHƯA xác nhận đã áp rộng, cần rà riêng
- [x] `@media (prefers-reduced-motion: reduce)` → tắt mọi animation

**Nghiệm thu:** không còn màn nhảy cụp khi đổi tab/tải dữ liệu; đo không rớt FPS; reduced-motion hoạt động.

---

## ĐỢT 3 — MOBILE-FIRST CHO CÔNG NHÂN ✅ phần lớn (merge `main`)
*80% người dùng thật là công nhân cầm điện thoại ngoài trời.*

- [x] **Bottom navigation** — `BottomNav.tsx` có, đã merge
- [x] **Bottom sheet** thay modal trên mobile — `Sheet.tsx` có
- [x] **Chế độ nắng** — `SunMode.tsx` có, token `[data-sun="1"]` trong `globals.css`
- [ ] `safe-area-inset` — thấy 1 chỗ dùng (`BottomNav.tsx`), chưa xác nhận phủ hết
- [ ] Pull-to-refresh — chưa xác nhận
- [ ] Rà target chạm ≥48px toàn app — chưa audit riêng
- [ ] Ẩn cột phụ trên mobile — chưa xác nhận rộng khắp

**Nghiệm thu:** thao tác ghi 1 bản ghi bằng **một tay** ≤20s; không phải với lên góc trên; đọc được ngoài nắng.

---

## ĐỢT 4 — GIẢM MẬT ĐỘ + BỎ JARGON ⚠ MỘT PHẦN — tồn thật, không phải tài liệu cũ nói sai

- [x] **Từ điển thuật ngữ** — `Term.tsx` component có sẵn
- [x] Component `Term` hoạt động đúng
- [ ] Áp `Term` cho nhãn kỹ thuật — **xác nhận qua grep: chỉ dùng ở 2/44 panel** (`Ops.tsx`, `KhoPanel.tsx`). Đây là việc thật còn tồn, cần làm tiếp — không chỉ là checkbox quên tick.
- [x] **Progressive disclosure** ("Thêm ▾") — thấy dùng nhiều panel
- [ ] `/quan-tri` nhóm 124 bảng + tìm — chưa xác nhận riêng
- [ ] Viết lại nhãn khó hiểu — chưa audit riêng

**Nghiệm thu:** người chưa từng dùng đọc hiểu được màn chính không cần hỏi; không còn mã kỹ thuật trần trên màn công nhân. **Chưa đạt** — độ phủ `Term` quá thấp.

---

## ĐỢT 5 — BẢNG DỮ LIỆU & HIỆU NĂNG ⚠ MỘT PHẦN — tồn thật

- [x] Sticky header khi cuộn (`table.tbl thead th { position: sticky }` — xác nhận trong `globals.css`)
- [ ] **Virtualization cho danh sách > 200 dòng — XÁC NHẬN CHƯA LÀM**: không có `react-window`/`react-virtual` trong dependency, không tìm thấy import nào. Tồn thật, không phải quên tick.
- [x] Lazy-load recharts — commit "Đợt 5: Hiệu năng — lazy-load thư viện biểu đồ (−40% JS)" đã merge
- [ ] Code splitting panel nặng — chưa audit riêng
- [ ] Đo Core Web Vitals thật, ghi số vào docs — **không tìm thấy số đo nào trong repo**, chưa làm

**Nghiệm thu:** JS trang biểu đồ giảm ≥30% (đã làm, có bằng chứng commit); cuộn bảng 1000 dòng mượt (**chưa** — không có ảo hóa); CWV có số đo thật (**chưa**).

---

## ĐỢT 6 — A11Y HOÀN CHỈNH + COMMAND PALETTE ⚠ MỘT PHẦN (merge `main`)

- [ ] Quét WCAG 2.2 AA toàn bộ — chưa audit đầy đủ; **đã tìm + sửa 1 lỗi tương phản dark-mode nghiêm trọng** (xem Đợt 1) trong đợt audit 31/08, nhưng chưa quét hết
- [x] Skip-link — `.ui-skip` có trong `globals.css`
- [ ] Kiểm tra tương phản mọi cặp màu ở cả 2 theme — mới kiểm tra 1 phần (nav/badge), chưa toàn bộ
- [ ] Điều hướng bàn phím toàn app — chưa audit riêng
- [x] **Command palette** `Ctrl/Cmd+K` — `CommandPalette.tsx` có, đã merge, xác nhận hoạt động
- [ ] Phím tắt `g+d`/`g+k`/`n` — chưa xác nhận

**Nghiệm thu:** thao tác trọn vẹn 1 luồng chỉ bằng bàn phím; 0 lỗi contrast (còn 1 lỗi lớn mới vá, có thể còn sót); palette mở <100ms.

---

## ĐỢT 7 — ANALYTICS HEART + TEST NGƯỜI DÙNG THẬT ⚠ HẠ TẦNG CÓ, TEST THẬT CHƯA

- [x] Hạ tầng HEART analytics — commit "Đợt 7: HEART analytics + test scripts" đã merge (bảng/instrument tồn tại)
- [ ] Trang `/ux` — chưa xác nhận riêng
- [ ] **Kịch bản test với công nhân thật, ≥5 người, ≥6 tác vụ — KHÔNG CÓ BẰNG CHỨNG đã thực hiện.** Script test có thể đã viết nhưng chưa tìm thấy biên bản/số liệu thật nào trong repo. Đây là việc còn tồn thật, cần chủ đầu tư bố trí người thật để làm — không phải việc code có thể tự "làm xong".
- [ ] Checklist quan sát / biểu mẫu ghi nhận — chưa xác nhận

**Nghiệm thu:** có số liệu thật của ≥5 người dùng cho ≥6 tác vụ — **CHƯA ĐẠT**, đây là việc cần con người thật ngoài đời, không thể đánh dấu xong qua audit code.

---

## Sau đợt 7
Vòng lặp: test → sửa → đo lại. Đây là chỗ 8 → 9+ được tạo ra, không phải trong editor.
