# 10 · PHẢN HỒI GÓP Ý RÀNG BUỘC v1.5 & STARTER KIT — Ý KIẾN CTO
*Đọc: `files/GOP-Y-RANG-BUOC-FILE-04-06.md` (v1.5) + `itran-agri-starter` (CLAUDE.md · ROADMAP 3 sprint · SPEC-01 SQL · SPEC-02 giấy–số · glossary · 8 biểu mẫu BM). Kết luận ngắn: **đồng ý ~85%, đã áp ngay vào bộ kế hoạch; phản biện 5 điểm; đề nghị 6 "cầu nối" để Ray A không phải đập đi khi lớn.***

## 1. ĐÃ ÁP NGAY (không cần bàn thêm)
| Góp ý | Đã sửa ở |
|---|---|
| Bảng RC chuẩn: RC11 = GIẤY–SỐ; tem → RC12; nước RC13; điện RC14; kiểm dịch RC15; rác bếp RC16 | 06 §3 (bảng chuẩn duy nhất), 03 M6/M7, 07, 00, CLAUDE.md.template |
| PAPER_SCANS + `paper_serial` trong EventBase (CHECK khi `source='PAPER'`) + PAPER_FORM_TEMPLATE seed 8 BM | 04 D4/D4b/D11, §6 seed |
| Alert mới AL-PAPER-24H · AL-PAPER-SERIAL · AL-BACKUP-FAIL · AL-DRILL-DUE | 06 §2.2 |
| Điều kiện bật não tầng cao ≥ 90 ngày dữ liệu sạch (≥95% hợp lệ); ASR = thử nghiệm; trần chi phí LLM + fallback; log Q&A 12 tháng | 06 §4b |
| Hard-code trái P8 (06:00/15:00, 35°C, lũ 3 cấp, 15:00, 24h, 20%…) → SETTING/NORM seed theo trại | 06 §2.2, 04 §6 |
| NĐ 13/2023 dữ liệu cá nhân (consent, ẩn danh, DPO = KS CN; GDPR chỉ khi khách EU) | 04 D10 |
| Màn "Nộp phiếu giấy" + "Nhập từ phiếu" + trang audit theo seri = **luồng chính sprint đầu tiên** | 03 M0, 07 Đợt B |
| Luật 72h: công nhân KHÔNG có nút UPDATE; ≤72h tạo bản supersede không cần duyệt; >72h qua ADJUSTMENT có KTT duyệt | 03 §21 |
| Formulation LP: chỉ bật sau khi D5 chạy thật ≥ 60 ngày | 03 M5, 07 C-D5 |
| Luật connector chống FOMO; thứ tự năm 1: VietQR → ZNS (OA đăng ký ngày 0) → xuất file MISA → import sao kê CSV; SMS = kênh ĐỎ dự phòng | 05 §6b, 07 C-Sales |
| Zalo OA/ZNS khởi động ngày 0; hóa đơn điện tử ngoài phạm vi năm 1 | 05, 07 §3 |
| Chỉ số dự án = chỉ số trại (không velocity/story point) | 07 (đã bỏ mục velocity) |
| Bàn giao đội trại: A13 nhận vận hành sau 90 ngày, bài kiểm tra "dựng lại từ backup trong 1 buổi"; MKT nhận trang QR/ZNS/nhận nuôi | ghi nhận vào 08 §6 (bổ sung dưới) |

## 2. PHẢN BIỆN — 5 ĐIỂM CẦN ĐỌC LẠI

### 2.1 Góp ý phán quyết file 07 & 08 dựa trên BẢN CŨ
Mục 9–11 (v1.3) và 12 (v1.4) nói "file 07 = 26 sprint/14 tháng, đội 9,5 FTE, k3s/Keycloak/NATS đã bị bác". **Bản 07 hiện hành đã viết lại hoàn toàn**: lộ trình Claude Code tính bằng **phiên/ngày** (Đợt A–F ≈ 15–20 ngày build), không có tháng, không có đội 9,5 FTE, chỉ số theo dõi = chỉ số trại, gắn cổng chặn trại, "thứ không nén được" tách riêng. Vì vậy **khác biệt Ray A ↔ Ray B bây giờ không còn là thời gian hay quy mô đội — chỉ còn là STACK** (Supabase + Next.js PWA ↔ Postgres tự host + NestJS + Expo/PowerSync + NATS…). Đề nghị góp ý v1.6 sửa lại định vị: "file 07/08/09 = bản đồ đích khi mở rộng (≥3 khách trả tiền hoặc ≥3 trại), Ray A dùng starter" — không phải "đóng băng vì sai giả định".

### 2.2 Stack Ray A (Supabase + Next.js PWA serwist): ĐỒNG Ý là lựa chọn đúng cho 90 ngày đầu — kèm 5 rủi ro phải chặn từ Sprint 1
Lý do đồng ý: 1 người + Claude Code, 0 vận hành hạ tầng, Auth/RLS/Storage/cron có sẵn, chi phí thấp, **vẫn là Postgres thuần** nên chuyển sang Ray B được nếu giữ kỷ luật.
| Rủi ro | Thực tế kỹ thuật | Cách chặn (đưa vào CLAUDE.md starter) |
|---|---|---|
| PWA offline trên iOS yếu | Safari không có Web Bluetooth; storage PWA có thể bị dọn sau 7 ngày không dùng; background sync gần như không | **Điện thoại công nhân = Android (Chrome)**; iOS chỉ cho quản lý xem; queue offline trong IndexedDB + nút "xuất bản sao offline" (JSON) khi chưa sync > 24h; cảnh báo trên màn hình khi hàng đợi > 0 quá 12h |
| Cân/RFID BLE từ PWA | Web Bluetooth (Android Chrome) chỉ GATT, không SPP classic | Chọn đầu đọc EID có BLE GATT (Agrident AWR300…) hoặc đi đường **ESP32/USR serial→MQTT/HTTP → Supabase Edge Function** cho cân cố định; giai đoạn 90 ngày: nhập tay + giấy là chính (đúng ROADMAP) |
| Không có TimescaleDB trên Supabase | Supabase đã ngừng cung cấp Timescale cho project mới | `sensor_reads` bảng partition theo tháng + pg_cron rollup 15'/1h; đủ cho vài triệu điểm/tháng; sang Ray B mới hypertable |
| Edge Function/cron | Cold start, cron tối thiểu 1 phút, timeout | RC/alert chạy đêm OK; alert ĐỎ thời gian thực (DO, kho lạnh) **chưa cam kết ở Ray A** — ghi rõ trong DoD |
| Khóa vendor | Auth/Storage/Realtime là API riêng Supabase | Migration SQL thuần; logic nghiệp vụ trong SQL function/TS module không phụ thuộc SDK; export CSV tuần; **bài test quý: dựng lại trên Postgres thường trong 1 buổi** (trùng bài kiểm tra bàn giao mục 8) |

### 2.3 Góc nhìn CÔNG TY MẸ (chỉ đạo mới của chủ đầu tư) — SPEC-01 & ROADMAP còn thiếu, sửa rẻ nếu làm ngay Sprint 1
Chủ đầu tư yêu cầu quản **nhiều trại, nhiều vùng** từ vị trí công ty. SPEC-01 chỉ có `farms(id, province, s_ha, k_factor)`; ROADMAP đến sprint 3 mới có "owner đa trại". Đề nghị (chi phí ≈ 0 ở Sprint 1, rất đắt nếu để sau):
1. Thêm `orgs` (công ty mẹ) + `regions` (vùng: tham số tỉnh/vùng JSON) + `farms.org_id / region_id / legal_entity / kind (HUB|CAMPUS|VE_TINH)`; mọi bảng nghiệp vụ giữ `farm_id` như đã có; RLS thêm nhánh `owner/auditor` thấy mọi trại của org.
2. Danh mục cấp ORG (scope GLOBAL): `products`, `sops`, `kpi_defs`, `alert_rules`, `rc_rules`, `norms` — trại kế thừa; SPEC-01 hiện `products/sops` chưa có `org_id` → thêm.
3. Sprint 3 "owner đa trại" giữ, thêm **đẩy SOP phiên bản → trại ký** (bảng `sop_distributions`) vì đây là cơ chế giữ chuẩn rẻ nhất khi có F02.
4. R&D và XNK (chỉ đạo mới): **không** đưa vào Ray A; nằm ở file 03 M19/M20 làm bản đồ; chỉ cần Ray A **không cản đường**: giữ `farm_id`, không đặt tên bảng xung đột (`trials`, `shipments`…), lots là bảng riêng (mục 2.4).

### 2.4 SPEC-01 v1.0 → v1.1: danh sách nâng cấp bắt buộc trước khi Claude Code build Sprint 1
Góp ý mục 4 đã nói "lấy từ file 04"; đây là danh sách cụ thể, xếp theo mức đau nếu để sau:
| # | Thiếu trong SPEC-01 | Vì sao phải có ngay | Lấy từ |
|---|---|---|---|
| 1 | `lots` bảng riêng (SPEC-01 chỉ có cột `lot text`) — hạn, COA, NCC, trạng thái KHẢ_DỤNG/CÔ_LẬP/THU_HỒI, giá vốn | Không có → không FEFO, không recall, không chặn lô cách ly | 04 §4.6 |
| 2 | `animal_groups` (gà đẻ/thịt, bể RAS, ao, lồng) | Gà & RAS là dòng tiền năm 1 — SPEC-01 chưa có chỗ ghi đàn | 04 §4.2 |
| 3 | `id_sequences` + mã TMP offline → mã chính thức khi sync | Không có → mã trùng khi 2 máy offline | 04 D2 |
| 4 | `supersedes_id` trên bảng sự kiện (góp ý đã đồng ý) — thay cho chỉ dùng `adjustments` | Luật 72h | 04 D3 |
| 5 | `weigh_tickets` (cân cầu/cổng, biển số, gross/net, ảnh) | RC3/RC5, cổng lõi | 04 §4.6 |
| 6 | `settings` + `norms` (định mức phân/con, lít/giờ máy…) | RC4/RC7 và P8 | 04 §4.1 |
| 7 | Phiên bản cho `recipes`, `kpi_defs`, `alert_rules`, `rc_rules`, `sop_versions` (SPEC-01 chỉ có `version int` trên recipes/sops) | Lương lớp 2 phải giải trình theo phiên bản | 04 D5 |
| 8 | Chặn ngưng thuốc ở DB: trigger từ chối `XUAT` khi `withdrawal_until > now()` (không chỉ lưu cột) | Luật cứng, không tin UI | 06 AL-WD |
| 9 | Gộp `items` vào `products` (một bảng, cột `kind`) | Hai bảng song song phá truy xuất & sổ cái | 04 §4.1 |
| 10 | `orders` trước `sales`; `partners` có scope org/farm; `checklist_runs.template_id`; `paper_scans` (SPEC-02) | ROADMAP sprint 3 cần | 04 §4.7, 4.9, D11 |
| 11 | `orgs`/`regions` (mục 2.3) | Chỉ đạo chủ đầu tư | 04 §4.1 |
| 12 | **Định danh vật nuôi 3 cấp:** `animals.intake_lot_id + group_id + owner_type`, bảng `intake_lots`, `animal_ownership`, `animal_media`, `group_membership`; CHECK "không vật nuôi thiếu định danh" (bò/dê cá thể; gia cầm/thủy sản nhóm) | Chỉ đạo chủ đầu tư — nền cho kinh doanh "chăm sóc hộ – xem live" (M21) sau này; đổi sau rất đau | 04 §4.2, 03 §19e |
Đề nghị: **tôi viết SPEC-01 v1.1 (SQL Supabase, ~40 bảng, RLS policy mẫu, trigger append-only, seed) từ file 04 rút gọn** — 1 phiên — để Sprint 1 build đúng ngay từ đầu.

### 2.5 Nhịp "sprint 2 tuần" vs "vài ngày Claude Code"
Không mâu thuẫn nếu tách rõ: **build** = phiên/ngày (Sprint 1 của starter có thể xong trong 1–2 ngày build); **sprint** = nhịp nghiệm thu với trại (2 tuần) vì trại cần thời gian **dùng thật** để phát hiện sai. Đề nghị đổi tên trong ROADMAP: "Sprint" → "Mốc nghiệm thu 1/2/3", ghi rõ build xong sớm thì go-live sớm, mốc nghiệm thu vẫn theo dữ liệu thật ("trại ghi đều" 30 ngày).

## 3. SÁU "CẦU NỐI" ĐỂ RAY A KHÔNG PHẢI ĐẬP ĐI (đưa vào CLAUDE.md starter)
1. Schema = tập con của file 04 (tên bảng/cột theo glossary + file 04), không phát minh tên mới; SQL thuần.
2. `org_id/region_id/farm_id` từ Sprint 1; RLS 2 tầng (org, farm).
3. Cấu hình có phiên bản (recipes/kpi/alert/rc/norms/settings) — không hằng số.
4. Sự kiện đặt tên `domain.entity.action` ngay cả khi mới chỉ là log — sau này nối bus không đổi tên.
5. Logic nghiệp vụ trong SQL function/TS module thuần, SDK Supabase chỉ ở lớp gọi.
6. Xuất CSV tuần + bài test quý "dựng lại trên Postgres thường trong 1 buổi".

## 4. NHẬN XÉT STARTER (ngắn)
- **CLAUDE.md:** tốt, đủ luật; bổ sung 6 cầu nối trên + "Android cho công nhân" + "alert ĐỎ thời gian thực chưa cam kết Ray A".
- **ROADMAP 3 sprint:** thứ tự đúng (xương → kho → đối soát → bán/truy xuất/KPI); thêm giấy–số vào Sprint 1 (góp ý đã yêu cầu), thêm `orgs/regions` Sprint 1, `sop_distributions` Sprint 3.
- **SPEC-01:** đúng tinh thần bộ gốc nhưng còn mỏng (mục 2.4); text PK theo mã nghiệp vụ OK cho Ray A.
- **SPEC-02 giấy–số:** rất tốt — đây là điểm bộ kế hoạch của tôi thiếu (đã ghi là "mẫu dự phòng"); giữ nguyên làm chuẩn, tôi đã nâng thành D4b/D11.
- **glossary:** tốt; bổ sung: `org/region/legal_entity`, `lot`, `weigh_ticket`, `animal_group`, `supersede`, `norm/setting`, `trial` (R&D), `shipment/customs` (XNK) — để không xung đột về sau.
- **8 biểu mẫu BM:** đủ cho 8 bảng sự kiện lõi; đề nghị thêm BM-09 KIỂM KÊ (STOCKTAKE) và BM-10 SỰ CỐ (INCIDENT) vì hai việc này cũng làm bằng giấy giai đoạn đầu.

## 5. ĐỀ NGHỊ QUYẾT ĐỊNH (chủ đầu tư chốt 1 dòng)
1. **Ray A = starter (Supabase + Next.js PWA)** cho 90 ngày thực chiến — đồng ý, kèm 6 cầu nối + 5 chặn rủi ro.
2. **Bộ 10 file = bản đồ đích (Ray B)** — không "đóng băng vì sai", mà "chờ điều kiện" (≥3 trại hoặc ≥3 khách trả tiền, hoặc cần IoT thời gian thực/multi-tenant SaaS).
3. Duyệt cho tôi viết **SPEC-01 v1.1** + cập nhật ROADMAP/CLAUDE.md starter theo mục 2.3–2.5, 3, 4 (1 phiên) trước khi mở phiên build Sprint 1.
