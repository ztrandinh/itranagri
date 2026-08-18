# 07 · LỘ TRÌNH TRIỂN KHAI BẰNG CLAUDE CODE — ĐƠN VỊ LÀ PHIÊN/NGÀY
*Mô hình: **Claude Code viết ≥ 95% code, test, migration, tài liệu**; con người (chủ đầu tư/KS công nghệ điều phối, KTT nghiệm thu nghiệp vụ) chỉ ra quyết định, cắm thiết bị, chạy thử hiện trường. Không có "tháng phát triển"; chỉ có (a) **đợt build** tính bằng phiên làm việc, và (b) **thời gian thật không nén được** (thiết bị về, tài khoản đối tác duyệt, dữ liệu vận hành thật để kiểm chứng) chạy song song.*

## 0. Cách vận hành Claude Code cho dự án này (bắt buộc để không "trôi")
1. **Repo có "hiến pháp":** `CLAUDE.md` gốc chứa: link 10 file kế hoạch này + bộ gốc, 10 nguyên tắc (file 00), luật ID/append-only/RLS (file 04), chuẩn code (file 09), lệnh `pnpm check`. Claude Code đọc mỗi phiên.
2. **Mỗi phiên = 1 đợt có phạm vi đóng:** đầu phiên viết `docs/sessions/S{n}.md` (mục tiêu, story, DoD); cuối phiên phải: test xanh, migration chạy, OpenAPI cập nhật, ADR nếu có, ghi lại "đã làm/chưa làm/quyết định cần người".
3. **Cổng chất lượng là máy, không phải cảm giác:** `pnpm check` (Biome + typecheck + Vitest + integration container + RLS test + contract) chặn merge; e2e Playwright/Maestro cho luồng vai; seed F99 dữ liệu giả để demo ngay.
4. **Người quyết 5 việc, còn lại Claude tự quyết theo kế hoạch:** (1) chốt stack/vốn/cloud, (2) mua thiết bị, (3) tài khoản đối tác, (4) nghiệm thu nghiệp vụ với KTT, (5) go-live/đào tạo.
5. **Song song hóa:** nhiều phiên Claude Code chạy song song theo module (worktree riêng) khi ranh giới module đã chốt (từ đợt B trở đi): ví dụ Livestock ∥ Crop ∥ Inventory.
6. **Không mở rộng phạm vi trong phiên:** ý tưởng mới → `docs/backlog.md`, xử lý đợt sau.

## 1. TỔNG QUAN ĐỢT BUILD (ước lượng phiên Claude Code; 1 ngày ≈ 2–4 phiên dài)

| Đợt | Nội dung | Ước lượng | Song song được? | Điều kiện người |
|---|---|---|---|---|
| **A · Nền** | Monorepo, compose infra, DB schema + RLS + audit, ID, Keycloak, **mô hình ORG→REGION→FARM (đa trại/đa vùng/đa pháp nhân) + module manifest + F99 sandbox**, API skeleton, mobile skeleton offline (PowerSync), web skeleton (chuyển ngữ cảnh trại/HQ), CI, seed, import Sheets, export | ~1–1,5 ngày | Không (nền chung) | Chốt file 00 mục 8; cloud/tài khoản GitHub |
| **B · Thần kinh (MVP)** | Platform hoàn chỉnh, SOP/checklist, Inventory K1–K9, Crop, Bio, Livestock lõi, Feeding, KPI/alert/report cơ bản, dashboard GĐ, INCIDENT, **HQ cơ bản: dashboard đa trại + đẩy SOP/chuẩn xuống trại + báo cáo chủ đầu tư hợp nhất; PARAM bản tính cho F01** | ~3–4 ngày | Có: 4–5 luồng module ∥ | KTT review màn hình vai (30'/ngày) |
| **C · Mạch máu** | D5 + formulation LP, IoT edge (driver cân/RFID/DO/silo/kho lạnh), RC1–RC12 (RC11 = giấy–số), KPI→lương, Sales/CRM/POS/thanh toán, Traceability EPCIS+QR+recall, HR ca/chấm công/đọc-hiểu, xuất bán bò, **liên trại (chuyển kho/giống qua cách ly, giá chuyển 70%, hub–vệ tinh), R&D lõi (hồ sơ giống, ươm/ấp/nhân men, lab)** | ~3–4 ngày | Có | **Thiết bị thật để test driver** (nếu chưa về: simulator, ghép sau 0,5 ngày) |
| **D · Miễn dịch & não** | Processing/HACCP, Finance (chi/duyệt/quỹ/P&L/cổng chặn/Hồ sơ module, **hợp nhất theo trại/vùng/pháp nhân**), Risk 19/CAPA/drill/audit/nghĩa vụ, Resort PMS/F&B/MICE/NPS, Forecast v1, Recommendation, AI assistant (Claude+MCP), Payroll VN, **R&D khảo nghiệm đối chứng + pilot module + tri thức/IP, XNK lõi (thị trường đích, đối tác, nhập khẩu/landed cost), tổng hành dinh (audit chéo, bài học liên trại)** | ~3–4 ngày | Có | Quy tắc lương/thuế hiện hành xác nhận; kế toán ngoài review P&L |
| **E · Nhân bản & tích hợp** | HQ đầy đủ (franchise, benchmark, mua chung), Param engine + mô phỏng, camera AI edge, Sentinel-2/thời tiết/GPS máy, e-invoice/MISA/Shopee/TikTok/cổng truy xuất/channel manager adapter (mock + thật khi có tài khoản), **XNK đầy đủ (hợp đồng ngoại thương, chứng từ, hải quan/logistics, L/C, hoàn thuế, truy xuất xuyên biên giới)**, SaaS onboarding, pentest tự động, DR drill script | ~3–4 ngày | Có | Tài khoản đối tác (sandbox) |
| **F · Ổn định & bàn giao** | Hardening offline, hiệu năng k6, bảo mật (ZAP/Semgrep), tài liệu người dùng 14 vai + video script, runbook, đào tạo | ~1–2 ngày | — | Đào tạo nhân sự trại |
| **Tổng** | | **≈ 15–20 ngày build** (2–3 tuần lịch nếu chạy song song) | | |

> Con số trên là công sức Claude Code; **lịch thực tế** kéo dài bởi các mục ở phần 3 (thiết bị, tài khoản, chạy thật). Chiến lược: build hết A→F trong ~3 tuần với simulator/sandbox, **go-live theo lớp** khi điều kiện thật sẵn sàng.

## 2. CHI TIẾT TỪNG ĐỢT (phiên → đầu ra kiểm chứng được)

### Đợt A · Nền (≈ 6–8 phiên)
| Phiên | Đầu ra | Kiểm chứng |
|---|---|---|
| A1 | Monorepo (file 09), Biome/TS/Vitest/Turbo, CI GitHub Actions, `pnpm check` | CI xanh trên commit rỗng |
| A2 | Compose infra dev: PG18+Timescale+PostGIS, NATS, Keycloak realm ITRAN + 14 vai, SeaweedFS, Valkey, Meilisearch, Mosquitto, ChirpStack; `pnpm dev:infra` | tất cả healthcheck OK |
| A3 | `packages/db`: schema toàn bộ file 04 (Drizzle) **kể cả ORG/REGION/FARM/LEGAL_ENTITY/MODULE_MANIFEST**, RLS policy mọi bảng (org + farm), trigger append-only + hash-chain, hypertable SENSOR_READ, view `v_*` + `hq_*`, seed (ORG ITRAN, 3 vùng mẫu, F01 + F99, 9 kho, 12 CC, 14 vai, KPI/alert/RC seed, SOP L2, chuẩn, định mức, ví dụ VD1/2/3) | test RLS tự sinh cho mọi bảng (trại A không thấy B; HQ thấy tất cả); test cấm UPDATE/DELETE |
| A4 | `packages/domain` + `schemas`: ID generator (offline TMP→chính thức), trạng thái vòng đời, EventBase, Zod cho mọi bảng sự kiện; sinh OpenAPI | 100% schema có test |
| A5 | `apps/api` skeleton NestJS: auth OIDC, tenant middleware (SET LOCAL), module template, outbox pg-boss → NATS, `/events` batch idempotent, `/exports`, `/imports` (Sheets/CSV), file pre-signed | e2e: ghi 1 sự kiện → outbox → NATS → consumer |
| A6 | `apps/mobile` skeleton Expo: login PKCE + PIN offline, PowerSync sync rules theo vai/farm, màn "Scan→Chọn→Xác nhận" chuẩn, queue upload, chế độ ngoài trời | Maestro: tắt mạng, ghi 20 bản ghi, bật mạng → sync khớp |
| A7 | `apps/web` skeleton Next.js: layout theo vai, dashboard khung, MapLibre lô, bảng dữ liệu, export; `/tv` kiosk | Playwright smoke |
| A8 | Edge compose (Mosquitto→NATS leaf, ChirpStack, edge-agent simulator cân/RFID/DO), OTel → Grafana; docs ADR-001…012; `CLAUDE.md` | sự kiện giả từ edge hiện lên web < 5 s |

### Đợt B · Thần kinh MVP (≈ 16–24 phiên; chạy 3–4 luồng ∥)
| Luồng | Phiên/đầu ra |
|---|---|
| B-Platform/SOP | Vai & ma trận quyền (file 03 mục 21), master data UI + import, máy sinh mã in QR hàng loạt, thông báo push/in-app, SOP library (cây, 10+1 trường, phiên bản, ký, video), checklist template & CHECKLIST_RUN mobile, INCIDENT + 5-Why, GATE_LOG tay; **GIẤY–SỐ là luồng chính giai đoạn đầu (SPEC-02): màn "Nộp phiếu giấy" + "Nhập từ phiếu" + PAPER_SCANS + RC11/RC11b + in 8 mẫu BM có seri — thuộc luồng ĐẦU TIÊN có người dùng thật** |
| B-Inventory | K1–K9, lô/hạn/COA, nhập/xuất quét, sổ cái + giá vốn BQ, ngày-tồn, kiểm kê mù + ADJUSTMENT duyệt, K7 trạm dầu, K9 tem, vé cân tay, dual UoM, trạng thái lô |
| B-Crop/Bio | Lô GIS + import ranh, lịch vụ theo tỉnh, lệnh lô/work order, CROP_LOG GAP (khóa backdate), giờ máy/nhiên liệu, hào ủ + ngày-tồn, vé cân → K3; BATCH_LOG trùn/BSF/compost/IMO/anolyte (chặn phân non), cân bằng vật chất 6 dòng, RC3/RC4 |
| B-Livestock/Feeding | ANIMAL/GROUP, sự kiện đầy đủ (sinh sản, sức khỏe, ngưng thuốc tự tính & chặn, vaccine lịch, cách ly, chết), gà 2 khối, RAS tay, dê; FEED_LOG tay + ảnh + thừa máng, SLA1 |
| B-Brain v1 | KPI engine (DSL + incremental), KPI seed đủ file 06, alert engine CEL + seed + escalation, báo cáo ngày + 1 trang thứ 6 (Typst→PDF, Zalo sau), dashboard GĐ/KTT, drill-down 2 chạm |
| B-HQ/PARAM | Màn hình công ty mẹ: danh sách trại/vùng, dashboard so KPI/đỏ/tồn tiền giữa trại, chuyển ngữ cảnh trại, đẩy SOP/KPI/alert phiên bản → trại ký (SOP_DISTRIBUTION), báo cáo chủ đầu tư hợp nhất, tham số vùng (REGION) áp vào lịch vụ/vaccine/giá; bản tính thế số cho F01 (Lớp B → C) |
| B-Đóng đợt | e2e 14 vai (Maestro/Playwright), hiệu năng ghi 10k/ngày, tài liệu 1 trang/vai, mẫu giấy dự phòng có QR, seed F99 |
**Nghiệm thu B (người):** KTT + 2 công nhân chạy kịch bản 1 ngày làm việc trên F99 → sửa UX → go-live lớp 1 (Sheets chỉ đọc).

### Đợt C · Mạch máu (≈ 16–24 phiên; ∥)
| Luồng | Đầu ra |
|---|---|
| C-D5 | RECIPE_VERSION duyệt, mẻ D5 (cân/lô/sai số/tem), QC lab, giá thành viên, tự chủ TA %, ≤35%/nguồn; **formulation LP** (HiGHS) chỉ bật sau khi D5 chạy thật ≥ 60 ngày |
| C-IoT | `edge-agent` driver thật: cân cầu/cân xe trộn/cân lối đi (RS-232→MQTT), RFID BLE mobile (crush mode), DO/pH/nhiệt LoRa codec, silo, nhiệt kho lạnh, DEVICE_STATE/heartbeat, CALIBRATION, edge-rules ĐỎ + còi, OCR biển số cổng (v1) |
| C-RC/KPI-lương | RC1–RC12 (RC11 = giấy–số) job đêm + drill-down, RECON_RESULT bất biến, KPI_RESULT → lớp 2, BONUS_POOL lớp 3, giải trình lương |
| C-Sales | CRM/HĐ (% sản lượng HĐ), đơn ≤15h → lệnh SX, giá sàn/giảm giá duyệt, POS quầy offline, giao (quét 2 lần, ký), SALE, **VietQR + CK + đối chiếu sao kê CSV (RC10)** — VNPay/MoMo chỉ khi kênh có doanh thu thật (luật connector file 05 mục 6b), công nợ, nhận nuôi + đăng ký giỏ, ZNS (OA đăng ký ngày 0) + SMS dự phòng |
| C-Trace | EPCIS projector, cây 2 chiều, GTIN/lot, QR Digital Link + resolver + trang công khai, tem GS1 ZPL, mock recall (đo ≤4h), audit pack ZIP |
| C-HR/Livestock+ | Phân ca (chặn 2 khối gà), chấm công QR/GPS, đọc-hiểu SOP đổi bản, chứng chỉ; xuất bán bò (chặn ngưng thuốc, giấy thú y), phả hệ, geofence (API vòng cổ mock), hồ sơ TT 66/2025 |
**Nghiệm thu C:** thiết bị thật đổ số ổn định (hoặc simulator + hẹn ghép), RC chạy trên dữ liệu thật ≥ 7 đêm, 1 SKU có QR bán thử.

### Đợt D · Miễn dịch & não (≈ 16–24 phiên; ∥)
| Luồng | Đầu ra |
|---|---|
| D-Processing | HACCP builder, QC point tự sinh, CCP_LOG + dừng dây chuyền, lưu mẫu, kho lạnh, tem RC12, giết mổ thuê, checklist mở SKU |
| D-Finance | CC + chu kỳ, đề nghị chi/duyệt (hạn mức, 2 chữ ký, SMS chủ), ngân sách, quỹ tự trích, giá chuyển 70%, P&L ngày 5 khóa, dòng tiền 90 ngày, RC10 sao kê, TSCĐ giờ máy, xuất MISA CSV; GATE C1–C4 tự chấm; Hồ sơ module 8 mục/5 bước |
| D-Risk | 19 rủi ro + chỉ số sớm + kích SOP, ma trận L×S, CAPA 7 ngày, drill, audit nội bộ, control↔chuẩn, hộ chiếu SKU, nghĩa vụ pháp lý, lệnh trại đóng/lũ, SOP khủng hoảng |
| D-Resort | PMS, F&B → kho, lưu mẫu bếp, rác→BSF, tour QR, NPS, an toàn trẻ em, MICE/BEO, đăng ký lưu trú, KPI |
| D-Brain v2 | Forecast v1 (Nixtla/LightGBM), Recommendation engine + phản hồi, AI assistant (Claude + MCP tools có phân quyền, view whitelist), soạn nháp SOP từ video/ghi âm, tóm tắt 5-Why; payroll VN engine v1 |
**Nghiệm thu D:** kế toán ngoài review P&L mẫu; GĐ chạy thử duyệt chi/cổng; bộ 100 câu chuẩn cho AI ≥ 90%.

### Đợt E · Nhân bản & tích hợp (≈ 16–24 phiên; ∥)
HQ (đa trại, đẩy SOP, audit chéo, benchmark, franchise) · Param engine + 3 ví dụ test · camera AI edge (RF-DETR, RC9, PPE) · Sentinel-2/thời tiết/GPS máy/drone volumetric · adapter: e-invoice, MISA API, Shopee/TikTok, cổng truy xuất/iCheck, channel manager, khóa thông minh (mock trước, thật khi có tài khoản) · SaaS onboarding tenant + billing + developer portal · pentest tự động (ZAP/Semgrep) + sửa · DR drill script.
**Nghiệm thu E:** tạo F02 mô phỏng ≤ 1 giờ; ZAP không lỗi cao; restore từ backup thành công.

### Đợt F · Ổn định & bàn giao (≈ 6–10 phiên)
Hardening offline 72h, k6 theo NFR file 08, tối ưu chi phí, tài liệu người dùng 14 vai + kịch bản video 2', runbook, checklist go-live, kế hoạch đào tạo, roadmap G5.

## 3. NHỮNG THỨ CẦN THỜI GIAN THẬT (làm ngay từ ngày 1, song song với build)
| Việc | Thời gian thật | Ai | Không có thì sao |
|---|---|---|---|
| Chốt 5 quyết định file 00 mục 8 | ngày 0 | Chủ đầu tư | Đợt A không bắt đầu |
| Mua điện thoại Android tầm trung ×(số nhân sự), mini-PC edge + UPS, máy in tem, Wi-Fi/4G trại | 3–7 ngày | KS CN | Test bằng máy sẵn có |
| Cân (RS-232), đầu đọc RFID BLE FDX-B, gateway LoRa + cảm biến DO/nhiệt/silo, camera cổng | 1–4 tuần (nhập) | KS CN | Simulator; ghép driver sau 0,5 ngày |
| Zalo OA + ZNS template duyệt, brandname SMS | 1–2 tuần | KD | Push/in-app trước |
| VNPay/MoMo merchant, VietQR | 1–2 tuần | KT | CK thủ công + đối soát tay |
| Mã GS1 (GTIN/GLN) | 1–2 tuần | KD | QR nội bộ trước, đổi sang GS1 sau (mapping) |
| Nhà cung cấp hóa đơn điện tử, MISA API, kết nối cổng truy xuất | 2–6 tuần | KT | Xuất file thủ công |
| Vòng cổ bò (API hãng) | theo mua nái | KTT | Ghi tay |
| **Dữ liệu vận hành thật để kiểm chứng KPI/RC/dự báo** | ≥ 30 ngày ghi liên tục | Toàn trại | Không có cách nén — đây là lý do go-live lớp 1 càng sớm càng tốt |
| Đào tạo & thay đổi thói quen 9 nhân sự | 1–2 tuần kèm | GĐ/KTT | KPI ghi chép trong lương lớp 2 |
| Chứng nhận (VietGAP/HACCP…) | theo lộ trình Quyển 4 | GĐ | Phần mềm sẵn sàng hồ sơ từ ngày 1 |

## 4. LỊCH ĐỀ XUẤT (nếu bắt đầu ngay)
- **Tuần 1:** Đợt A (ngày 1–2) → Đợt B (ngày 3–7, 4 luồng ∥). Cuối tuần: nghiệm thu B trên F99, đào tạo lớp 1, **go-live ghi chép lớp 1** (SOP, kho, crop, bio, livestock, checklist).
- **Tuần 2:** Đợt C (∥) + ghép thiết bị đã về; go-live lớp 2 (D5, RC, KD, truy xuất) khi KTT duyệt.
- **Tuần 3:** Đợt D (∥) + Đợt E bắt đầu; kế toán review; go-live lớp 3 (finance, risk, resort nếu mở).
- **Tuần 4:** Đợt E hoàn tất + Đợt F; tích hợp thật khi tài khoản về; bàn giao. Sau đó G5 vận hành: mỗi tuần 1–2 phiên bảo trì/cải tiến theo backlog + dữ liệu thật.

## 5. DoD MỖI PHIÊN / MỖI ĐỢT (không thương lượng)
Phiên: `pnpm check` xanh · migration có down · OpenAPI/SDK cập nhật · seed/F99 cập nhật · docs/sessions ghi · không TODO ẩn (mọi TODO thành issue).
Đợt: e2e vai xanh · RLS test toàn bảng · hiệu năng đạt NFR đợt · tài liệu 1 trang/tính năng · demo trên thiết bị thật · KTT/GĐ ký nghiệm thu nghiệp vụ trong `docs/acceptance/{đợt}.md`.

## 6. RỦI RO ĐẶC THÙ KHI BUILD BẰNG AI & CÁCH CHẶN
| Rủi ro | Chặn |
|---|---|
| Code "trông đúng" nhưng sai nghiệp vụ | Golden tests từ ví dụ số trong bộ gốc (VD3, RC ngưỡng, KPI công thức); KTT nghiệm thu bằng kịch bản thật |
| Trôi khỏi kiến trúc qua nhiều phiên | `CLAUDE.md` + ADR + dependency-cruiser + review khác biệt kiến trúc mỗi đợt |
| Bảo mật lỏng (RLS quên, secret lộ) | Test RLS tự sinh cho mọi bảng; scan secret CI; ZAP mỗi đợt |
| Phình phạm vi | Backlog riêng; phiên chỉ làm story đã ghi |
| Phụ thuộc thiết bị chưa về | Simulator chuẩn cho mọi driver; hợp đồng giao diện `packages/drivers` |
| Người dùng chưa quen | Go-live lớp, kèm 1-1, KPI ghi chép, giấy dự phòng có QR |
