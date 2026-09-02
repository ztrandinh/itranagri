# Checklist: thay emoji thô bằng icon SVG màu tự vẽ

Lý do (đã thống nhất với chủ đầu tư): emoji hiển thị KHÁC NHAU tùy hệ điều hành (Android công nhân dùng ra khác Windows) — không nhất quán, đọc như bản MVP hơn phần mềm doanh nghiệp. Hướng đã chọn: **icon SVG MÀU, GIỮ ý nghĩa/hình tượng** (không đổi sang bộ icon outline chung chung — sẽ mất khả năng nhận diện tức thì mà công nhân cần).

Quy trình mỗi đợt: (1) vẽ icon mới → xem thử ở trang scratch tạm (xóa sau) → tự phản biện hình có rõ không → (2) gắn vào component dùng chung → (3) build/tsc/eslint sạch → (4) verify trực tiếp trên app thật (cả sáng/tối nếu icon không tự chứa màu nền cố định) → (5) commit + push → (6) tick vào đây.

Rà soát 2026-09-01 qua 5 agent độc lập (46 panel + toàn bộ component dùng chung + 2 trang top-level). Danh sách dưới đây là ĐẦY ĐỦ những gì tìm được — không phải ước lượng.

## ĐÃ XONG

- [x] **16 icon khu vực/phòng ban** (📝🎯🐄🌾♻🏭🏬💰🏨🌏📒👥✅🔧🧪🏢) — `src/components/icons/ZoneIcons.tsx`, gắn ở Shell.tsx (sidebar) + Home.tsx (trang chủ). Commit `4d57db7`.

## ĐỢT 2 — Component dùng chung, xuất hiện ở MỌI trang (ưu tiên cao nhất) — XONG (commit tiếp theo)

- [x] **✓** checkmark "xong/đạt" — CaPanel.tsx, ThreeTap.tsx, TodayBar.tsx, ModulePanel.tsx
- [x] **✗** cross "chưa đạt/sai" — ModulePanel.tsx boolean cell
- [x] **← / →** quay lại/tiếp — PageNav.tsx, ThreeTap.tsx, CaPanel.tsx (ProcessFlow.tsx "→ {dept}" để lại — nằm trong SVG sơ đồ phức tạp, xem Đợt 4)
- [x] **🏠** trang chủ/phòng tôi — PageNav.tsx, Shell.tsx
- [x] **▾ / ▸** mở rộng/thu gọn — Shell.tsx, TodayBar.tsx, Tabs.tsx ("Thêm ▾")
- [x] **✕** đóng/xóa — QrScan.tsx, Toast.tsx, Shell.tsx
- [x] **☰** hamburger menu mobile — Shell.tsx
- [x] **» / «** thu gọn/mở sidebar — Shell.tsx
- [x] **📋** việc/hồ sơ — BottomNav.tsx
- [x] **📷** quét/chụp — QrScan.tsx, BottomNav.tsx
- [x] **＋** thêm mới — Attachments.tsx, ModulePanel.tsx
- [x] **✍** ghi/viết — BottomNav.tsx, CaPanel.tsx (📝 handover note)
- [x] **👤** người/tài khoản — BottomNav.tsx
- [x] **⏳ / 📴** trạng thái đồng bộ — Shell.tsx header
- [x] **☀ / 🌙 / 🖥** chế độ sáng/tối/hệ thống — ThemeToggle.tsx
- [x] **🌤** chế độ nắng — SunMode.tsx
- [x] **🔍** tìm kiếm — Search.tsx (thêm icon overlay, bỏ emoji khỏi placeholder)
- [x] **⚖** cân BLE — ThreeTap.tsx
- [x] **−** giảm số lượng (stepper) — ThreeTap.tsx
- [ ] Search.tsx — bản đồ icon theo LOẠI đối tượng (🐄🐔🟩🌱🧬📦👤🤝⚙️🏠📍🏬📅🏷️🔁🏢🛏️, 17 loại) — CHƯA LÀM, để Đợt 4 (mỗi cái chỉ 1 chỗ trong code dù lặp nhiều lúc chạy, ưu tiên thấp hơn)

Bộ icon dùng: `src/components/icons/UiIcons.tsx` (đơn sắc, `currentColor`, tự đúng màu theo ngữ cảnh — khác `ZoneIcons.tsx` là icon MÀU tự chứa nền). Thêm 2 icon phát sinh khi làm: `IconRedo` (↷ nút tiến của PageNav), `IconPaperclip`/`IconFile` (kẹp giấy/tệp của Attachments.tsx).

## ĐỢT 3 — Icon hành động dùng LẶP LẠI nhiều nơi nhất (thiết kế 1 lần, dùng khắp app)

Đây là nhóm quan trọng nhất trong các panel — cùng 1 icon xuất hiện ở >5 file, nên thiết kế thống nhất trước khi sửa từng file:

- [ ] **＋** "thêm mới" — ~55+ lượt dùng, ~25+ file (add-record button phổ biến nhất toàn app)
- [ ] **✓ / ✗** cặp trạng thái đạt/không đạt — ~30+ lượt, ~20+ file
- [ ] **▶** chạy/thực thi — ~15+ lượt, ~10 file
- [ ] **✕** xóa dòng/đóng — ~10 lượt, ~8 file
- [ ] **⬇ / ⬆** xuất/nhập CSV — ~7 lượt, ~4 file
- [ ] **✎** sửa — ~6 lượt, ~5 file
- [ ] **⚠** cảnh báo — ~6 lượt, ~4 file
- [ ] **🔄 / ↻ / ⟳ / 🔁** làm mới — **4 KIỂU KHÁC NHAU cho cùng 1 ý nghĩa, cần gom về 1 icon** — DanPanel, Depts, Career, KeHoachNam, DuTru, GiamSat, ProcessDesigner, HuongDan
- [ ] **📣** công bố/xuất bản — SupplyPlan, ProcessDesigner, KeHoachNam
- [ ] **🛠** thiết kế/công cụ — ToChuc, ProcessDesigner
- [ ] **📈 / 📊** biểu đồ/số liệu — CanhTac, KhoPanel, MuaHang, DuLich, DuTru, GiamSat, SoLieuPanel
- [ ] **🔑 / 🔓** đổi PIN/mở khóa (cặp) — Depts.tsx
- [ ] **🔔** chuông thông báo — Notify.tsx

## ĐỢT 4 — Icon riêng từng file (thấp ưu tiên hơn nhưng vẫn cần làm để dứt điểm)

Danh sách đầy đủ theo file (không lặp icon đã có ở Đợt 2/3), để tick từng cái khi làm tới — KHÔNG bỏ sót:

- [ ] AnimalDetail.tsx — 📷 (đã có ở Đợt 2)
- [ ] CanhTac.tsx — 💰 📈 ⭐ (đã có dept icon cho 💰)
- [ ] Career.tsx — ☐ (chưa ký, cặp với ✓) · 💰 ⭐ 🪜 🖨 ⚙
- [ ] CheBien.tsx — ♻ 🔬
- [ ] DanPanel.tsx — 📋
- [ ] Dashboards.tsx — (không có icon riêng ngoài Đợt 3)
- [ ] Depts.tsx — 🎓 (🪜 trùng Career)
- [ ] DoiTuong.tsx — 👤 🐄 🌱 📦 (bộ chuyển tab loại đối tượng — 🐄 trùng dept icon)
- [ ] DuLich.tsx — (không có icon riêng ngoài Đợt 2/3)
- [ ] DuTru.tsx — 🌱 (icon tab; 🌾📦🔧 trùng dept icon)
- [ ] Extra.tsx — (không có icon riêng ngoài Đợt 3)
- [ ] FarmProfile.tsx — 🌡
- [ ] FinanceMore.tsx — 📆 🏦 💸 🛡 🧾 (🏢✍ trùng nhóm khác)
- [ ] Fulfillment.tsx — (không có icon riêng)
- [ ] GiamSat.tsx — 🔴 ⛔ 🚨 🎲
- [ ] GiayPanel.tsx — (📷 trùng Đợt 2)
- [ ] HerdIntake.tsx — 🔄 (trùng nhóm làm mới)
- [ ] HuongDan.tsx — chủ yếu tham chiếu icon đã có ở nơi khác trong văn bản hướng dẫn — rà lại SAU khi các đợt trên xong, để đồng bộ đúng icon mới
- [ ] KeHoachNam.tsx — ● ▲ (mốc lịch mùa vụ)
- [ ] KhoPanel.tsx — ❄ (lạnh) ▾▸ (trùng Đợt 2)
- [ ] KinhDoanh.tsx — ◀ (trùng ▶ Đợt 3)
- [ ] Marketing.tsx — (không có icon riêng ngoài Đợt 3)
- [ ] MeterReading.tsx — 🔌 ⛔ 🗺
- [ ] More.tsx — ■ ↗ (🖨 trùng Career)
- [ ] MuaHang.tsx — ↩ 📥
- [ ] Notify.tsx — (🔔 ở Đợt 3)
- [ ] Ops.tsx — ⚙ ←
- [ ] Pedigree.tsx — 🧬 🦠 ♀ ♂
- [ ] ProcessDesigner.tsx — ↑ ↓ (di chuyển bước) 🔁 (phát hành lại)
- [ ] SalesMore.tsx — (⚠ trùng Đợt 3)
- [ ] SoLieuPanel.tsx — ▲ ▼ (xu hướng)
- [ ] TaiKhoan.tsx — 🛡 (báo cáo ẩn danh)
- [ ] ToChuc.tsx — (✎▶🛠✍ trùng Đợt 3)
- [ ] TuanThu.tsx — (không có icon riêng ngoài Đợt 3)
- [ ] login/page.tsx, chuan/page.tsx — ◆ (trang trí, có thể giữ nguyên vì là ký tự trang trí không phải "icon chức năng" — cân nhắc khi tới)
- [ ] CommandPalette.tsx — ↑↓ ⌘ (gợi ý phím tắt — có thể giữ nguyên vì đây LÀ ký hiệu phím thật, không phải icon minh họa)

## Nguyên tắc khi làm

- Icon MỚI phải tự chứa màu nền (không phụ thuộc token/theme xung quanh) — giống 16 icon khu vực đã làm — để tránh lặp lại bug tương phản sidebar-tối/card-sáng đã gặp nhiều lần trong phiên này.
- Icon nào đã trùng với 1 trong 16 icon khu vực (💰🏢🐄🌾🔧 dùng lại ở tab khác) → dùng LẠI `ZoneIcon`, không vẽ icon mới.
- Ký hiệu KHÔNG phải icon minh họa (phím tắt ⌘↑↓ trong CommandPalette, ký tự trang trí ◆) → cân nhắc giữ nguyên, không bắt buộc đổi.
- Mỗi đợt xong đều commit + push riêng, không gộp nhiều đợt vào 1 commit lớn (dễ review, dễ rollback nếu có vấn đề).
