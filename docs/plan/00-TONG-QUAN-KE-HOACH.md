# ITRAN AGRI — KẾ HOẠCH TỔNG THỂ PHÁT TRIỂN PHẦN MỀM QUẢN TRỊ TRANG TRẠI TUẦN HOÀN
**Phiên bản kế hoạch: v1.0 · Ngày: 18/08/2026 · Vai trò soạn: CTO / Kiến trúc sư trưởng**
**Căn cứ:** Bộ gốc ITRAN FARM 12 file (FILE-GỐC v3.1 Phần IX "Đặc tả nền phần mềm", Phụ lục A/B sổ tay 14 vai + sổ cái 9 kho + 10 luật đối soát, Quyển 1–5).

> **Luật thứ bậc:** Bộ gốc thắng kế hoạch này về NGHIỆP VỤ (5 trục, 5 phòng, ID, 6 chỉ số, KPI, alert, RC1–RC10). Kế hoạch này thắng về CÔNG NGHỆ & CÁCH LÀM. Mâu thuẫn → ghi INCIDENT "tài liệu", xử lý trong 7 ngày.

---

## 0. DANH MỤC BỘ KẾ HOẠCH (10 file — đọc theo thứ tự)

| # | File | Nội dung | Ai đọc |
|---|---|---|---|
| 00 | **TỔNG QUAN** (file này) | Tầm nhìn, nguyên tắc, kiến trúc 1 trang, lộ trình, đội ngũ, ngân sách, rủi ro dự án | Chủ đầu tư, GĐ, mọi thành viên |
| 01 | Benchmark thế giới | Đối chiếu 40+ phần mềm nông nghiệp/ERP hàng đầu → tính năng & chuẩn kế thừa | PO, kiến trúc sư |
| 02 | Kiến trúc hệ thống | C4, tech stack, offline-first, IoT edge, multi-tenant, bảo mật, audit bất biến | Toàn đội dev |
| 03 | Danh mục module & tính năng | "Cơ thể" phần mềm: 18 module, ~420 tính năng, màn hình theo 14 vai, phân quyền | PO, dev, KTT, GĐ |
| 04 | Mô hình dữ liệu | Master data + event tables + sổ cái + chuỗi truy xuất, ID, DDL khung | Backend, data |
| 05 | API & tích hợp | REST/GraphQL/Webhook/MQTT, import–export, đấu nối thiết bị & phần mềm ngoài | Backend, IoT, đối tác |
| 06 | Engine thông minh ("bộ não") | KPI engine, Alert engine, Reconciliation RC1–RC10, dự báo, gợi ý, trợ lý AI | Data/ML, backend |
| 07 | Lộ trình triển khai chi tiết | 5 giai đoạn · 24 sprint · epic/story · DoD · mốc nghiệm thu gắn cổng chặn trại | PM, toàn đội |
| 08 | Chất lượng – bảo mật – vận hành | NFR, test strategy, DevOps, SLO, DR/backup, ISO 27001 controls | QA, DevOps |
| 09 | Cấu trúc repo & chuẩn code | Monorepo, coding standards, ADR, review, CI gate | Toàn đội dev |

---

## 1. TẦM NHÌN SẢN PHẨM

**ITRAN AGRI** = hệ điều hành số của trang trại tuần hoàn: *"người tạo bản ghi — máy viết báo cáo — não gợi ý quyết định"*. Không phải phần mềm ghi chép; là **hệ thần kinh + bộ não** cho mô hình 5 trục · 5 phòng · 12 điểm giao nhận · 19 rủi ro · 4 cổng chặn — chạy được cho trại 4 ha lẫn 60 ha, và nhân bản F02, F03… chỉ bằng đổi mã trại + bộ tham số.

**3 khách hàng của phần mềm:**
1. **Trại F01 (nội bộ)** — vận hành hằng ngày, thay thế Google Sheets ngay từ bản ghi số 1.
2. **Chuỗi F0x + nhượng quyền** — công ty mẹ nhìn mọi trại, đẩy SOP, so KPI, audit chéo.
3. **Thương mại hóa (ITRAN AGRI SaaS)** — bán cho trại tuần hoàn khác; vì thế multi-tenant, API đầy đủ, dữ liệu xuất mở.

**Định vị so với thế giới:** không có phần mềm nào hiện nay bao trọn *chăn nuôi + trồng trọt + sinh học/chất thải + chế biến + kho + bán + resort + tài chính + tuân thủ* trong MỘT hệ với **cân bằng vật chất tuần hoàn** làm xương sống. Đó là khoảng trống ITRAN AGRI chiếm.

## 2. MƯỜI NGUYÊN TẮC THIẾT KẾ (bất biến — sửa phải qua hội đồng kiến trúc)

| # | Nguyên tắc | Hệ quả kỹ thuật |
|---|---|---|
| P1 | **Multi-farm từ dòng mã đầu** | `farm_id` trong mọi bảng; Row-Level Security; ID `[TRẠI]-[LOẠI]-[SỐ]` |
| P2 | **Offline-first** | Mobile ghi local, đồng bộ 2 chiều (PowerSync); edge gateway tại trại chạy độc lập khi mất internet; cờ `backfilled` cho nhập bù |
| P3 | **Audit trail bất biến** | Bảng sự kiện append-only, sửa = bản ghi mới có `supersedes_id`; hash-chain theo ngày; lưu ≥ 5 năm; sao lưu ngoài trại hằng ngày |
| P4 | **Dữ liệu là của công ty** | Xuất toàn bộ CSV/Parquet/JSON bất kỳ lúc nào; không khóa vendor; schema mở công bố |
| P5 | **Người tạo bản ghi – máy viết báo cáo** | Mọi báo cáo (ngày, thứ 6, P&L ngày 5, quý, năm) sinh tự động từ event; không có "màn hình nhập báo cáo" |
| P6 | **Ghi tại chỗ ≤ 3 chạm** | Màn hình theo vai; quét RFID/QR/mã vạch; cân, cảm biến tự đổ; xác nhận 1 chạm |
| P7 | **Quyền ghi tách quyền duyệt** | RBAC + ABAC; không ai vừa ghi vừa duyệt cùng bản ghi; GĐ không sửa số quá khứ |
| P8 | **Cấu hình, không hard-code** | KPI/alert/RC/SLA/định mức/công thức thế số = dữ liệu có phiên bản, không nằm trong code |
| P9 | **API-first, event-driven** | Mọi tính năng UI đều có API; mọi thay đổi phát sự kiện lên bus; webhook cho đối tác |
| P10 | **Chuẩn quốc tế từ bản ghi số 1** | GS1 (GTIN/SSCC/EPCIS 2.0), ISO 11784/85 RFID, ICAR, ISOXML/ADAPT, MQTT Sparkplug B, OpenAPI 3.1, OIDC, ISO 27001, WCAG 2.2 |

## 2b. GÓC NHÌN CÔNG TY MẸ — ĐA TRẠI · ĐA VÙNG · ĐA PHÁP NHÂN LÀ MẶC ĐỊNH (không phải tính năng thêm sau)

ITRAN AGRI được thiết kế **đứng ở vị trí công ty mẹ ITRAN FARM** (giữ thương hiệu – SOP – phần mềm), nhìn xuống nhiều trại F01, F02… ở nhiều vùng (Bắc bãi sông, ĐBSCL, trung du, miền núi…), mỗi trại có thể là pháp nhân con, S và tham số vùng khác nhau, module bật/tắt khác nhau — nhưng **cùng một Lớp A/B, cùng SOP, cùng chuẩn dữ liệu**.

| Cấp | Thực thể | Nội dung quản lý |
|---|---|---|
| **ORG** (công ty mẹ / tổng hành dinh) | 1 tenant | Thương hiệu, danh mục SKU toàn hệ, thư viện SOP gốc + phiên bản, chuẩn (KPI/alert/RC/định mức Lớp B), Hồ sơ module, cổng chặn, quỹ, hợp đồng nhượng quyền, tổng hành dinh 3–5 người (chuẩn · đào tạo · kiểm định · phần mềm), mua chung, đối tác lớn (B2B đa trại), báo cáo hợp nhất, benchmark ẩn danh, audit chéo |
| **REGION** (vùng) | n | Bộ tham số vùng: giống, lịch vụ, vaccine bắt buộc tỉnh, chính sách hỗ trợ, giá tham chiếu vùng, cốt lũ/hạn, nguồn phụ phẩm, NCC vùng, đơn vị thú y/lab/lò mổ vùng; đơn vị đo giá/lương theo vùng |
| **FARM** (trại F0x, pháp nhân con) | n | Toàn bộ 18 module vận hành với `farm_id`; Phụ lục thế số riêng (Lớp C); P&L riêng; nhân sự riêng; module bật/tắt theo dải S và thị trường |
| **HUB + vệ tinh** | tùy vùng | Trại vệ tinh < 3 ha (không bò) gửi nguyên liệu/nhận xử lý cho hub — mô hình hóa bằng chuyển kho liên trại + giá chuyển nội bộ + SLA |

**Nghiệp vụ liên trại phải có ngay từ đầu:** mã trại đứng đầu mọi ID; đẩy SOP phiên bản mới xuống trại và theo dõi ký; so KPI/đỏ/cổng chặn giữa trại trên 1 màn hình; **chuyển giống/vật tư giữa trại = xuất kho trại A → nhập kho trại B qua cách ly 21 ngày như mua ngoài** (an toàn sinh học); giá chuyển nội bộ 70%; hợp nhất P&L theo pháp nhân và theo vùng; audit chéo trại A→B; bài học (INCIDENT/5-Why) chia sẻ toàn hệ; báo cáo cho chủ đầu tư đa trại; sandbox F99. Chi tiết module HQ/PARAM → file 03 (M17, M18) và lộ trình đưa HQ cơ bản lên **Đợt B** (file 07).

## 3. KIẾN TRÚC 1 TRANG

```
┌──────────────── LỚP TRẢI NGHIỆM ────────────────┐
│ Mobile (Expo/React Native, offline)  ·  Web (Next.js)  ·  Kiosk/TV dashboard  ·  Zalo/SMS/Email  │
└──────────────────────────┬────────────────────────┘
                           │ REST/OpenAPI 3.1 · GraphQL (đọc) · WebSocket/SSE · Webhook
┌──────────────────────────┴────────────────────────┐
│  ITRAN CORE (NestJS, modular monolith, TypeScript) │
│  Platform: identity · tenant · master-data · ID · audit · files · notify · workflow(Temporal) · rules · report · import/export · integration-hub │
│  Domain:  livestock · crop · bio(khu D) · feedmill(D5) · processing · inventory(K1–K9) · sales/CRM · resort · hr-kpi-payroll · finance · risk-compliance · sop · traceability · iot · hq-multifarm · parameterization("thế số") │
└───────┬───────────────┬───────────────┬───────────┘
        │ outbox (pg-boss)                │
   NATS JetStream 2.14  PostgreSQL 18.6   SeaweedFS (S3)   Valkey 9    Meilisearch   Keycloak 26 (OIDC)
   (event bus + MQTT)   +Timescale 2.28   (ảnh/video/PDF)  (cache)     (tìm kiếm)    OpenBao (secrets)
        │               +PostGIS 3.6 (CNPG)
┌───────┴────────────┐     ┌──────────────────────────┐    ┌───────────────────────┐
│ ITRAN BRAIN (Python)│     │ ITRAN EDGE (tại trại)     │    │ ITRAN SYNC (PowerSync) │
│ Nixtla/LightGBM     │     │ Mosquitto→NATS leaf, Chirp│    │ offline 2 chiều mobile │
│ RF-DETR camera      │     │ Stack LoRa, edge-rules ĐỎ │    │ (SQLite ↔ Postgres)    │
│ Claude API + MCP    │     │ driver cân·RFID·DO·OCR·AI │    │                        │
└─────────────────────┘     └──────────────────────────┘    └───────────────────────┘
Hạ tầng: Docker Compose (edge) · k3s + Argo CD (cloud VN) · OpenTelemetry + Grafana/Loki/Tempo · backup 3-2-1 offsite.
```

*(Stack đã kiểm chứng phiên bản & giấy phép 18/08/2026 — MinIO CE ngừng phát triển 4/2026 nên dùng SeaweedFS/Garage; Redis 8 AGPL → Valkey; Vault BSL → OpenBao; YOLO AGPL → RF-DETR; Prophet đóng băng → Nixtla. Chi tiết → file 02.)*

## 4. PHẠM VI CHỨC NĂNG (tóm tắt — chi tiết file 03)

**20 module nghiệp vụ** (+ cơ chế thêm module vô hạn) = 5 phòng + trục xuyên suốt + cấp công ty mẹ:

| Phòng (bộ gốc) | Module ITRAN AGRI |
|---|---|
| Sản xuất chăn nuôi | **LIVESTOCK** (bò cá thể RFID · gà 2 khối · dê · RAS · tôm/bè), **FEEDING** (FEED_LOG, xe trộn) |
| Sinh học – trồng trọt | **CROP** (lô PostGIS, lịch vụ, máy, NDVI, ủ chua), **BIO** (trùn/BSF/biogas/compost/IMO/anolyte), **FEEDMILL D5** (RECIPE, phối trộn, ép viên) |
| Công nghệ – dữ liệu | **IOT** (thiết bị, cảm biến, hiệu chuẩn, gateway), **BRAIN** (KPI/alert/RC/dự báo/AI), **PLATFORM** (ID, audit, workflow, import/export, API) |
| Kinh doanh – resort | **SALES/CRM** (5 kênh, hợp đồng, POS, "nhận nuôi", công nợ), **PROCESSING** (mẻ, CCP/HACCP, tem), **INVENTORY** (K1–K9, FEFO, sổ cái), **TRACEABILITY** (EPCIS, hộ chiếu lô, QR, mock recall), **RESORT** (booking, F&B, NPS, MICE) |
| HC-TC-NS | **HR-KPI-PAYROLL** (14 vai, chứng chỉ SOP, checklist ca, lương 4 lớp, khoán), **FINANCE** (CC, P&L phân hệ, giá chuyển 70%, cổng chặn, quỹ, phân quyền chi, 2 chữ ký), **RISK-COMPLIANCE** (19 rủi ro, INCIDENT/5-Why, audit nội bộ, ISO/GAP/HACCP/Halal, hồ sơ audit ≤ 24h), **SOP** (thư viện 4 cấp, phiên bản, video, ký điện tử) |
| Công ty mẹ / đa trại | **HQ** (ORG→REGION→FARM, so KPI, đẩy SOP, liên trại, hợp nhất, audit chéo, nhượng quyền, mua chung), **PARAM** (tham số vùng/trại, engine thế số S → Lớp C) |
| Nhóm bổ sung (ghép vào phòng có sẵn) | **R&D** (giống, khảo nghiệm đối chứng, pilot module, ươm/ấp/nhân men, lab, tri thức/IP), **XNK** (thị trường đích, hợp đồng ngoại thương, chứng từ, hải quan/logistics, nhập khẩu, thanh toán quốc tế) — và **bất kỳ bộ phận tương lai** qua cơ chế manifest module + Hồ sơ module 8 mục (file 03 mục 19d) |

## 5. LỘ TRÌNH TÓM TẮT — TRIỂN KHAI BẰNG CLAUDE CODE (chi tiết file 07)

Đơn vị là **phiên/ngày build**, không phải tháng. Claude Code viết ≥ 95% code/test/migration/tài liệu; người chỉ quyết định, cắm thiết bị, nghiệm thu nghiệp vụ.

| Đợt | Nội dung | Build (Claude Code) | Gắn cổng chặn trại |
|---|---|---|---|
| **A · Nền** | Monorepo, infra compose, DB schema + RLS + audit, ID, Keycloak, API/mobile/web skeleton, CI, seed, import Sheets, export | ~1–1,5 ngày | Trước Cổng 1 |
| **B · Thần kinh (MVP)** | Platform + SOP/checklist · Inventory K1–K9 · Crop · Bio · Livestock/Feeding lõi · KPI/alert/report cơ bản · Dashboard 1 trang thứ 6 · INCIDENT | ~3–4 ngày (4 luồng ∥) | Vận hành GĐ1 trại → **go-live lớp 1** |
| **C · Mạch máu** | D5 + formulation LP · IoT edge thật · RC1–RC12 (RC11 = giấy–số) · KPI→lương · Sales/POS/thanh toán · Truy xuất EPCIS+QR+recall · HR ca/chấm công · xuất bán bò | ~3–4 ngày (∥) | Cổng 2 → nhập nái (Cổng 3) |
| **D · Miễn dịch & não** | Processing/HACCP · Finance (chi/duyệt/quỹ/P&L/cổng chặn/Hồ sơ module) · Risk 19/CAPA/audit · Resort PMS · Dự báo v1 · Gợi ý · Trợ lý AI · Payroll VN | ~3–4 ngày (∥) | Cổng 3 → Cổng 4 |
| **E · Nhân bản & tích hợp** | HQ multi-farm · Engine thế số · Camera AI · Sentinel-2/thời tiết/GPS máy · e-invoice/MISA/Shopee/cổng truy xuất/channel manager · SaaS onboarding · pentest tự động · DR script | ~3–4 ngày (∥) | Xét F02 |
| **F · Ổn định & bàn giao** | Hardening offline/hiệu năng/bảo mật, tài liệu 14 vai, runbook, đào tạo | ~1–2 ngày | — |
| **Tổng** | | **≈ 15–20 ngày build ≈ 3–4 tuần lịch** | |

**Thứ không nén được** (chạy song song từ ngày 1): thiết bị về (1–4 tuần), Zalo ZNS/VNPay/GS1/hóa đơn điện tử duyệt (1–6 tuần), **≥ 30 ngày dữ liệu vận hành thật** để kiểm chứng KPI/RC/dự báo, đào tạo & đổi thói quen nhân sự (1–2 tuần). Vì thế: **build hết A→F trong ~3–4 tuần với simulator/sandbox, go-live theo lớp** khi điều kiện thật sẵn sàng.

## 6. NHÂN SỰ & NGÂN SÁCH (mô hình Claude Code)

| Vai | Ai | Việc |
|---|---|---|
| Điều phối build (product owner kỹ thuật) | Chủ đầu tư hoặc KS công nghệ (A13) | Mở phiên Claude Code theo file 07, chốt quyết định, review, merge, deploy |
| Nghiệm thu nghiệp vụ | 2 KTT + GĐ | 30'/ngày xem màn hình vai, chạy kịch bản thật, ký `docs/acceptance` |
| Thiết bị & hiện trường | KS công nghệ + thợ điện/mạng thuê ngoài | Lắp edge, cân, RFID, LoRa, camera, Wi-Fi |
| Kế toán/pháp lý thuê ngoài | như bộ gốc | Review P&L, luật lương/thuế, hợp đồng vendor |
| Claude Code | — | ≥ 95% code, test, migration, tài liệu, seed, script |

Ngân sách tham chiếu: **LLM/Claude Code** theo mức dùng (ước 20–40 phiên dài/tuần trong 4 tuần build, sau đó 1–2 phiên/tuần) · cloud VN 8–15 tr/tháng cho F01 · thiết bị đợt 1 (điện thoại, edge + UPS, máy in tem, cân/RFID/LoRa/DO/silo/camera) 150–400 tr · dịch vụ (bản đồ, ZNS/SMS, thanh toán, hóa đơn điện tử, GS1) 30–80 tr/năm · thợ lắp đặt theo hạng mục. **Nằm gọn trong dòng "Công nghệ 0,8–1,6 tỷ" của Quyển 5**, phần lớn là thiết bị vật lý — phần mềm gần như chỉ tốn chi phí sử dụng Claude Code + cloud.

## 7. RỦI RO DỰ ÁN PHẦN MỀM & PHÒNG NGỪA

| Rủi ro | Phòng ngừa |
|---|---|
| Phạm vi quá rộng, không ra được MVP | Ưu tiên theo cổng chặn trại; Đợt B chỉ làm đúng cái GĐ1 trại cần; "walking skeleton" ngay ngày 1–2 (Đợt A) |
| Build bằng AI "trông đúng nhưng sai nghiệp vụ" / trôi kiến trúc qua nhiều phiên | `CLAUDE.md` hiến pháp repo + ADR + golden tests từ số liệu bộ gốc + KTT nghiệm thu kịch bản thật mỗi đợt (file 07 mục 0, 6) |
| Người dùng là công nhân, kháng app | ≤ 3 chạm; màn hình theo vai; test hiện trường mỗi sprint với 2 công nhân thật; giấy dự phòng in sẵn |
| Mất mạng, thiết bị hỏng | Offline-first + edge; giấy → nhập bù có cờ |
| Dữ liệu bẩn từ Sheets | Import có validate + báo cáo lỗi; ID kỷ luật ngay từ Sheets |
| Phụ thuộc 1 dev | Monorepo chuẩn, ADR, tài liệu sinh từ code, ma trận kỹ năng 80% như trại |
| Chi vượt trần 4–6% DT | Roadmap quý duyệt bởi GĐ; mọi tính năng ≥ 2 tuần công phải có "bài toán hoàn vốn" |
| Bảo mật (dữ liệu đàn, tài chính) | OIDC, MFA vai duyệt, RLS, mã hóa at-rest, backup offsite, pentest trước SaaS |

## 8. QUYẾT ĐỊNH CẦN CHỦ ĐẦU TƯ CHỐT (để bắt đầu Đợt A)

1. **Cloud & vị trí dữ liệu** — khuyến nghị: cloud VN (Viettel/VNG/FPT) hoặc AWS ap-southeast-1 + bản sao offsite thứ 2; edge mini-PC tại trại. (Có thể bắt đầu Đợt A–B trên máy local/VPS nhỏ, chuyển cloud sau.)
2. **Google Sheets GĐ1:** khuyến nghị bỏ qua — go-live lớp 1 trên ITRAN AGRI ngay cuối tuần 1; nếu đã có Sheets thì import 1 lần.
3. **Tên miền/thương hiệu số:** itranfarm.vn, `id.itranfarm.vn` (QR truy xuất), app "ITRAN AGRI".
4. **Bộ thiết bị đợt 1** để dev driver thật (mua ngay để về kịp Đợt C): cân cầu/cân bàn RS-232, đầu đọc RFID BLE FDX-B (Agrident/Allflex/Gallagher), gateway LoRa + cảm biến DO/nhiệt/silo, mini-PC edge + UPS, máy in tem, điện thoại Android tầm trung.
5. **Ai điều phối build** (chủ đầu tư hay KS công nghệ) và ai nghiệm thu nghiệp vụ mỗi ngày (KTT).

## 9. VIỆC LÀM NGAY (hôm nay – ngày mai)

1. Duyệt bộ kế hoạch 10 file này (chủ đầu tư + GĐ + KS công nghệ) — sửa gì ghi thẳng vào file.
2. Chốt 5 quyết định mục 8; đặt mua thiết bị đợt 1; nộp hồ sơ Zalo OA/ZNS, VNPay/MoMo, GS1 (chạy song song).
3. Mở phiên Claude Code **Đợt A** theo file 07: tạo monorepo (file 09) + `CLAUDE.md` + infra compose + schema (file 04) + skeleton — mục tiêu cuối ngày 1–2 có "walking skeleton" ghi offline → sync → dashboard.
4. KTT chuẩn bị: danh sách nhân sự/vai, danh mục SKU/kho/CC/lô đất thực tế (CSV) để seed F01; kịch bản 1 ngày làm việc để nghiệm thu Đợt B.
5. Đo hiện trường: mạng/điện/vị trí đặt edge, số điện thoại cần cấp.
