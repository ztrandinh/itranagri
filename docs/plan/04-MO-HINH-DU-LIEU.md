# 04 · MÔ HÌNH DỮ LIỆU ITRAN AGRI
*Nguồn: FILE-GỐC Phần IX mục 2–4 · Phụ lục B (sổ cái 9 kho, RC1–RC10, B4) · Quyển 4 mục 07 · Quyển 3 mục 15 (SOP). Nâng chuẩn theo GS1 EPCIS 2.0, ICAR ADE, ISO 11784/85, ISO 8601, GeoJSON.*

## 1. NGUYÊN TẮC MÔ HÌNH

| # | Luật | Cách thực thi |
|---|---|---|
| D1 | Mọi bảng có `farm_id` (FK FARM) — trừ bảng toàn hệ (PRODUCT/SKU, SOP template, chuẩn) có `scope = GLOBAL\|FARM` | Postgres RLS: `USING (farm_id = current_setting('app.farm_id')::uuid OR scope='GLOBAL')` |
| D2 | Khóa kỹ thuật `id UUIDv7` (sắp xếp theo thời gian, sinh được offline) + **mã nghiệp vụ** `code` theo chuẩn `[TRẠI]-[LOẠI]-[SỐ]` (unique) | Máy sinh mã: bảng `ID_SEQUENCE(farm_id, type, last_no)`; offline sinh mã tạm `TMP-…` rồi đổi khi sync (giữ `client_ref`) |
| D3 | Bảng sự kiện **append-only**: không UPDATE/DELETE; sửa = INSERT bản mới với `supersedes_id`, `reason`; bản cũ `status = SUPERSEDED` | Trigger cấm UPDATE/DELETE trừ cột `status`; hash-chain `row_hash = sha256(prev_hash ∥ payload)` chốt theo ngày vào `AUDIT_ANCHOR` |
| D4 | Mọi bản ghi sự kiện có: `id, farm_id, occurred_at (TIMESTAMPTZ), recorded_at, recorded_by (STAFF) hoặc recorded_by_device (DEVICE), source (APP\|DEVICE\|IMPORT\|BACKFILL\|PAPER\|API), backfilled BOOL, client_ref, sync_status, evidence[] (ảnh/cân/cảm biến), **paper_serial TEXT NULL** (bắt buộc NOT NULL khi `source='PAPER'` — bản ghi nhập từ phiếu giấy BM01–08)` | Cột chuẩn qua mixin `EventBase`; CHECK constraint `source<>'PAPER' OR paper_serial IS NOT NULL` |
| D4b | **Tầng giấy là luồng chính giai đoạn đầu** (SPEC-02 starter): bản mềm đã nhập & đối chiếu = bản chính để tính; bản cứng có số seri = bằng chứng gốc lưu 5 năm; hai bản nối bằng `paper_serial` | Bảng PAPER_SCANS + RC11/RC11b + màn "Nộp phiếu giấy"/"Nhập từ phiếu" |
| D5 | Master data có phiên bản khi ảnh hưởng tính toán (RECIPE, SOP, KPI_DEF, ALERT_RULE, RC_RULE, PRICE_LIST, NORM) | Bảng `*_VERSION` + `effective_from/to`; sự kiện tham chiếu đúng phiên bản |
| D6 | Thời gian ISO 8601, lưu UTC, hiển thị Asia/Ho_Chi_Minh; số lượng `NUMERIC(18,4)` + `uom` | Bảng UOM + bảng quy đổi |
| D7 | Địa lý: `GEOMETRY(Polygon/Point, 4326)` PostGIS | Lô đất, ô cỏ, geofence, tuyến viền, vị trí thiết bị |
| D8 | Chuỗi thời gian cảm biến: hypertable Timescale, nén sau 7 ngày, continuous aggregate 1'/15'/1h/1d, lưu thô 2 năm, tổng hợp 10 năm | `SENSOR_READ` |
| D9 | File/ảnh/video: MinIO, bảng `FILE(id, sha256, mime, size, taken_at, gps, device)`; bằng chứng gắn qua `EVIDENCE_LINK` | Không lưu binary trong DB |
| D10 | Xóa mềm chỉ với master data (`archived_at`); event không bao giờ xóa. **Tuân thủ Nghị định 13/2023/NĐ-CP (dữ liệu cá nhân VN):** consent khi thu GUEST/NPS/ADOPTION/khách QR, quyền yêu cầu xóa/ẩn danh (ẩn danh hóa thay vì xóa sự kiện), hồ sơ xử lý, DPO danh nghĩa = KS công nghệ; GDPR chỉ khi có khách EU (SaaS sau) | Bảng CONSENT(đối tượng, mục đích, thời điểm, kênh) + job ẩn danh |
| D11 | **PAPER_SCANS**(id, farm_id, form_code BM01–BM08, serial UNIQUE `F01-BM01-000123`, photo_file_id, scan_ts, uploaded_by, digitized BOOL, digitized_by, digitized_ts, linked_ids JSONB, anomaly TEXT) · **PAPER_FORM_TEMPLATE**(mã BM, phiên bản, file in, bảng đích, map cột) — seed 8 mẫu BM01–08 | RC11 (chưa số hóa >24h), RC11b (seri nhảy quãng); trang audit lọc theo `paper_serial` xem ảnh gốc cạnh dữ liệu |

## 2. QUY ƯỚC MÃ ĐỊNH DANH (mở rộng từ bộ gốc)

| Đối tượng | Mẫu | Ví dụ | Ghi chú |
|---|---|---|---|
| Trại | `F0x` | F01 | Đứng đầu mọi mã |
| Bò cá thể | `F01-BO-00001` | RFID ISO 11784/85 (15 chữ số) lưu `rfid_tag`; mã visual tai `visual_tag` | Bê sinh: app tự sinh |
| Dê cá thể | `F01-DE-0001` | | |
| Đàn/lô gia cầm | `F01-GA-L03` (đẻ) / `F01-GT-L07` (thịt) | Tách 2 khối bằng LOẠI | |
| Bể RAS / ao / lồng | `F01-RAS-B12` / `F01-AO-03` / `F01-BE-L05` | | |
| Lô đất canh tác | `F01-LO-G1A` + polygon | Ô cỏ luân phiên: `F01-LO-K07` | |
| Tuyến/cụm viền | `F01-LO-VIEN-012` | | Quyển 5 mục 10 |
| Luống trùn / khay BSF / hầm biogas / ô compost | `F01-TR-015` / `F01-BSF-04` / `F01-BG-01` / `F01-CP-03` | | |
| Mẻ sản xuất (D5, ủ, sấy, chế biến, trùn) | `F01-ME-240315-02` | In bao bì + GS1 lot | `batch_no` = YYMMDD-seq |
| Thiết bị | `F01-TB-021` | Kèm giờ máy | |
| Cảm biến/điểm đo | `F01-SS-0042` | Gắn DEVICE + vị trí | |
| Kho | `F01-K1`…`F01-K9` + vị trí `F01-K5-A03` | | |
| SKU | `SKU-PTR-25` toàn hệ | + GTIN-13/14 khi có GS1 | |
| Đối tác | `KH-0034` / `NCC-0012` | + GLN nếu có | |
| Nhân sự | `NS-014` | | |
| Trung tâm chi phí | `CC-BO`, `CC-TRUN`, `CC-D5`, `CC-RAS`, `CC-GA`, `CC-TT`, `CC-CB`, `CC-KD`, `CC-DL`, `CC-HC`, `CC-CN`, `CC-VIEN` | Cây CC có cha/con | |
| SOP | `SOP-BO-07.2` phiên bản `v3` | | |
| Sự cố | `F01-INC-2026-0007` | | |
| Đơn hàng / hợp đồng | `F01-DH-2026-00123` / `F01-HD-2026-004` | | |
| Booking | `F01-BK-2026-00045` | | |
| Lệnh sản xuất | `F01-LSX-2026-00088` | | |
| Phiếu điều chỉnh tồn | `F01-DC-2026-0009` | | |
| Kỳ đối soát | `F01-RC-20260817` | | |

## 3. SƠ ĐỒ MIỀN DỮ LIỆU (bounded contexts)

```
PLATFORM ─ ORG(công ty mẹ) · REGION(vùng) · FARM(F0x, pháp nhân con) · LEGAL_ENTITY · STAFF · ROLE · PERMISSION · DEVICE · FILE · AUDIT_ANCHOR · ID_SEQUENCE · SETTING · NOTIFICATION · JOB · MODULE_MANIFEST · FARM_MODULE(bật/tắt)
RND     ─ GENETIC_LINE(giống) · SEED_LOT/SEMEN_LOT/STRAIN(men, meo) · TRIAL(khảo nghiệm) · TRIAL_ARM(thử/đối chứng) · TRIAL_OBSERVATION · TRIAL_RESULT · PILOT(module 10%) · LAB_SAMPLE · LAB_RESULT · KNOWLEDGE_DOC · INNOVATION(sáng kiến)
TRADE   ─ MARKET_PROFILE(thị trường đích, HS, chuẩn) · TRADE_PARTNER(nhà NK, forwarder, ngân hàng) · TRADE_CONTRACT(Incoterms, tiền tệ, thanh toán) · SHIPMENT(container, cold-chain) · TRADE_DOCUMENT(invoice, packing list, C/O, phyto/health, B/L, Halal…) · CUSTOMS_DECLARATION · IMPORT_PERMIT · FX_RATE · INTL_PAYMENT(L/C, T/T) · LANDED_COST
MASTER  ─ SPECIES · BREED · UOM · PRODUCT(SKU) · RECIPE(+VERSION) · PARTNER · COSTCENTER · LOCATION(khu/nhà/kho) · NORM(định mức) · PRICE_LIST · TAX
LIVESTOCK ─ ANIMAL · ANIMAL_GROUP(đàn/lô/bể/ao/lồng) · EVENT_ANIMAL · TREATMENT_PLAN · VACCINE_SCHEDULE · WITHDRAWAL · SEMEN_LOT · WEIGH_SESSION
FEEDING ─ FEED_LOG · FEED_PLAN · MIXER_LOAD
CROP    ─ PLOT · SEASON_PLAN · CROP_LOG · MACHINE_HOUR · SILAGE_PIT · NDVI_LAYER · SOIL_TEST · WATER_TEST · IRRIGATION_LOG
BIO/D5  ─ BATCH_LOG · BATCH_INPUT · BATCH_OUTPUT · QC_RESULT · CCP_LOG · MATERIAL_BALANCE
INVENTORY ─ WAREHOUSE(K1–K9) · LOT · STOCK_BALANCE(view) · INVENTORY_MOVE · ADJUSTMENT · STOCKTAKE · GATE_LOG · WEIGH_TICKET
SALES   ─ CONTRACT · ORDER · ORDER_LINE · SALE(giao/hoá đơn) · PAYMENT · RECEIVABLE · ADOPTION("nhận nuôi") · CHANNEL(1–5) · PRICE_FLOOR
RESORT  ─ ROOM · RATE_PLAN · BOOKING · GUEST · FNB_ORDER · TOUR_STATION · NPS_SURVEY · KITCHEN_SAMPLE_LOG
HR      ─ POSITION · SHIFT · CHECKLIST_RUN · CERTIFICATE · TRAINING · KPI_RESULT · PAYROLL_RUN · BONUS_POOL · SKILL_MATRIX
FINANCE ─ JOURNAL(nhẹ, đối chiếu kế toán ngoài) · EXPENSE_REQUEST · APPROVAL · BUDGET · FUND(thiên tai/BD/đào tạo) · TRANSFER_PRICE · PL_SNAPSHOT · GATE(cổng chặn) · GATE_CRITERIA
RISK    ─ RISK_REGISTER(19) · RISK_INDICATOR · INCIDENT · FIVE_WHY · CAPA · NEAR_MISS · DRILL(diễn tập) · AUDIT_INTERNAL · STANDARD_CLAUSE · SKU_PASSPORT
SOP     ─ SOP · SOP_VERSION · SOP_STEP · SOP_SIGNOFF · CHECKLIST_TEMPLATE
TRACE   ─ EPCIS_EVENT · TRACE_LINK · QR_CODE · RECALL · RECALL_ITEM · AUDIT_PACK
IOT     ─ SENSOR_READ(hypertable) · CALIBRATION · DEVICE_STATE · ALERT · ALERT_RULE(+VERSION) · ALERT_ACK
BRAIN   ─ KPI_DEF(+VERSION) · KPI_VALUE · RC_RULE · RECON_RESULT · FORECAST · RECOMMENDATION · REPORT_SNAPSHOT
HQ/PARAM ─ FARM_PROFILE(20 tham số địa phương hóa) · PARAM_SET(S, K, tỷ lệ) · PARAM_OUTPUT(Lớp C) · SOP_DISTRIBUTION · CROSS_AUDIT · FRANCHISE
```

## 4. ĐẶC TẢ BẢNG CHÍNH (cột nghiệp vụ; cột chuẩn `EventBase` không lặp lại)

### 4.1 Platform & Master
- **ORG**(id, tên công ty mẹ, thương hiệu, cấu hình toàn hệ, gói SaaS) · **REGION**(id, org_id, tên vùng, tỉnh[], tham số vùng JSON: giống, lịch vụ, vaccine bắt buộc, chính sách, giá tham chiếu, cốt lũ/hạn, nguồn phụ phẩm, đơn vị thú y/lab/lò mổ) · **LEGAL_ENTITY**(pháp nhân, MST, sổ sách, ngân hàng) · **MODULE_MANIFEST**(mã, phòng chủ quản, bảng, sự kiện, KPI, quyền, màn hình, phiên bản) · **FARM_MODULE**(farm, module, bật/tắt, ngày, hồ sơ module)
- **FARM**(id, code F0x, org_id, region_id, legal_entity_id, tên, loại: HUB\|CAMPUS\|VỆ_TINH, địa_chỉ, tọa_độ, tz, S_hữu_dụng_ha, dải_quy_mô, trạng_thái, hub_farm_id (nếu vệ tinh))
- **STAFF**(id, code NS-xxx, farm_id, họ_tên, vai[] (A1–A14), phòng, vị_trí, ngày_vào, trạng_thái, hđlđ, khám_sk_hạn, tập_huấn_attp_hạn, sđt, oidc_sub, pin_offline_hash)
- **ROLE / PERMISSION / ROLE_PERMISSION** — theo ma trận file 03 mục 6; ABAC theo `farm_id`, `department`, `cost_center`.
- **LOCATION**(id, farm_id, code, loại: KHU\|NHÀ\|CHUỒNG\|Ô\|KHO\|VỊ_TRÍ_KHO\|TRẠM, cha_id, geom, tầng_cao_độ T1/T2/T3, sức_chứa)
- **DEVICE**(id, code TB/SS, farm_id, loại: MÁY\|CÂN\|RFID_READER\|SENSOR\|CAMERA\|GATEWAY\|VÒNG_CỔ\|DRONE\|MÁY_IN_TEM\|POS, hãng, model, serial, location_id, giờ_máy_tích_lũy, chu_kỳ_bd_giờ, ngày_hiệu_chuẩn_kế, định_mức_lít_giờ, mqtt_topic, trạng_thái)
- **PRODUCT (SKU)**(sku, tên, loại: NGUYÊN_LIỆU\|BÁN_TP\|THÀNH_PHẨM\|VẬT_TƯ\|THUỐC\|VACCINE\|NHIÊN_LIỆU\|BAO_BÌ\|DỊCH_VỤ, uom, bậc_giá_trị 1–5, hạn_dùng_ngày, quy_cách, gtin, thuế_suất, kho_mặc_định K1–K9, theo_lô BOOL, theo_hạn BOOL, cần_coa BOOL, halal_flag, hộ_chiếu_chuẩn JSON {nội_địa:[…], xuất:[…]}, cost_center_mặc_định)
- **RECIPE**(id, tên, loài/pha, phiên_bản, hiệu_lực, đạm %, năng_lượng, cờ_halal, không_bsf BOOL, sai_số_cho_phép %, người_duyệt, trạng_thái) · **RECIPE_LINE**(recipe_id, sku, tỷ_lệ %, thứ_tự_nạp, ghi_chú "rỉ mật sau cùng")
- **PARTNER**(code KH/NCC, loại, tên, mst, gln, địa_chỉ, kênh 1–5, hạn_mức_công_nợ, ngày_công_nợ, trạng_thái_phê_duyệt NCC, ngày_đánh_giá, coa_bắt_buộc, halal_cert, hợp_đồng[])
- **COSTCENTER**(code, tên, cha, phòng, loại: PHÂN_HỆ\|HẠ_TẦNG\|CHUNG, gate_stage)
- **NORM**(farm_id\|GLOBAL, loại: PHÂN/CON/NGÀY · NƯỚC/CON · LÍT/GIỜ_MÁY · TIÊU_THỤ_TA/CON/PHA · CHUỒNG_M2/CON …, giá_trị, uom, hiệu_lực) — dùng cho RC4, RC7, thế số.

### 4.2 Livestock — định danh 3 cấp (cá thể · lô nhập · đàn) là LUẬT CỨNG
- **ANIMAL**(id, code, farm_id, loài, giống, giới, ngày_sinh, mẹ_id, cha_id/tinh_lot, rfid_tag, visual_tag, qr_public_token, ảnh_nhận_diện[], nguồn: SINH\|MUA\|CHUYỂN_TRẠI, **intake_lot_id** (lô nhập/cohort), **group_id** (đàn hiện tại), ngày_nhập, ncc_id, giá_nhập, trạng_thái_vòng_đời (nái: HẬU_BỊ→PHỐI→KHÁM_THAI→MANG_THAI→ĐẺ→NUÔI_CON→CAI_SỮA→CHỜ_PHỐI; bê: SƠ_SINH→THEO_MẸ→CAI_SỮA→PHÂN_LOẠI[GIỮ_NỀN\|VỖ\|BÁN_GIỐNG]; vỗ: PHA1\|PHA2\|PHA3→XUẤT; chung: BỆNH\|CÁCH_LY\|CHẾT\|XUẤT), location_id, cân_gần_nhất, ngày_cân, ngày_ngưng_thuốc_đến, đơn_giá_sổ_đàn, cost_center, **owner_type: TRẠI\|KHÁCH\|ĐỒNG_SỞ_HỮU**) · **ANIMAL_OWNERSHIP**(animal_id, partner_id, %, từ, đến, hợp đồng custody_id) · **INTAKE_LOT**(code F01-LN-…, loại: MUA\|SINH\|CAI_SỮA\|CHUYỂN_TRẠI, ngày, ncc/trại nguồn, giấy kiểm dịch, cách_ly_đến, giá, số con) · **ANIMAL_MEDIA**(animal_id, file_id, mốc: NHẬP\|CÂN\|KHÁM\|ĐẺ\|TUẦN\|KHÁCH_YÊU_CẦU, ts, công khai cho khách?) · **GROUP_MEMBERSHIP**(animal_id, group_id, từ, đến — tách/gộp có vết). Bắt buộc: bò/dê/đại-tiểu gia súc = cá thể; gia cầm/thủy sản = ANIMAL_GROUP (cá thể tùy chọn). Không tồn tại bản ghi vật nuôi thiếu định danh (CHECK).
- **ANIMAL_GROUP**(id, code GA-L03/RAS-B12/AO/BE, loài, số_đầu_con_hiện_tại, ngày_vào, all_in_all_out BOOL, location_id, khối GÀ_ĐẺ\|GÀ_THỊT, sinh_khối_ước_kg)
- **EVENT_ANIMAL**(EventBase + animal_id \| group_id, loại: NHẬP\|CÁCH_LY_VÀO\|CÁCH_LY_RA\|PHỐI(tinh_lot, kỹ_thuật_viên)\|ĐỘNG_DỤC(nguồn: vòng_cổ)\|KHÁM_THAI(kq +/-)\|ĐẺ(bê_id_mới[], khó_đẻ)\|CAI_SỮA\|PHÂN_LOẠI(hướng)\|CÂN(kg, weigh_session_id)\|BỆNH(triệu_chứng, mức)\|ĐIỀU_TRỊ(thuốc_lot, liều, đường, ngưng_thuốc_ngày, phác_đồ_id, thú_y_ký)\|VACCINE(loại, lot)\|CHUYỂN(từ→đến)\|CHẾT(nguyên_nhân, xử_lý_xác)\|LOẠI\|XUẤT(kh, giá, kiểm_dịch_số)\|SỐ_LƯỢNG_ĐÀN(±n cho group)\|GHI_CHÚ, giá_trị NUMERIC, đơn_vị, chi_tiết JSONB)
- **TREATMENT_PLAN**(phác đồ thú y ký: bệnh, thuốc, liều/kg, số ngày, ngưng thuốc, người ký, file)
- **VACCINE_SCHEDULE**(loài, tỉnh_param, loại vaccine, tuổi/tháng, tần suất) → sinh nhắc.
- **WEIGH_SESSION**(device_id cân lối đi, thời gian, số con) — cân tự đổ nhiều CÂN.
- **SEMEN_LOT**(mã tinh, giống, nguồn, ncc, số liều, hạn) → K1.

### 4.3 Feeding
- **FEED_LOG**(EventBase + mẻ_id/batch_ref, recipe_version_id, khu_nhận location_id \| group_id \| animal_id, kg_kế_hoạch, kg_thực (từ cân xe trộn/silo), sai_số %, cữ (SÁNG\|CHIỀU), thừa_máng %, ảnh_máng)
- **MIXER_LOAD**(mẻ, từng thành phần cân được kg, thứ tự, thời gian trộn phút) — chi tiết ra FEED_LOG.

### 4.4 Crop
- **PLOT**(code, farm_id, geom Polygon, ha, tầng_cao_độ, loại: HOA_MÀU\|CỎ_Ô\|LÂU_NĂM\|VIỀN\|MẶT_NƯỚC, cây_hiện_tại, luân_canh_nhóm G1/G2/G3, tình_trạng)
- **SEASON_PLAN**(plot_id, vụ, cây, giống, ngày_gieo_kh, ngày_thu_kh, năng_suất_kh, tham_số_tỉnh)
- **CROP_LOG**(EventBase + plot_id, hoạt_động: LÀM_ĐẤT\|GIEO\|BÓN\|PHUN(sinh_học\|hóa_học_cục_bộ + lệnh_GĐ)\|TƯỚI(nguồn_nước, m³)\|CẮT\|THU(kg, ẩm %)\|GIEO_LẠI\|KHẢO_SÁT_NDVI, giống_lot, vật_tư_lot[], device_id, giờ_máy_bắt_đầu/kết_thúc, nhiên_liệu_lít, người_lái, ndvi_layer_id, weigh_ticket_id, cách_ly_thu_hoạch_đến)
- **SILAGE_PIT**(hào/hố, thể_tích m³, tỷ_trọng, ngày_đóng, ngày_mở, tồn_ước kg) — tồn K3 theo thể tích.
- **NDVI_LAYER**(plot_id, ngày, nguồn drone/vệ tinh, file raster/COG, chỉ số TB)
- **SOIL_TEST / WATER_TEST**(mẫu, ngày, phòng lab, chỉ tiêu JSON, đạt/không, file) — bằng chứng GAP.
- **PASTURE_ROTATION**(ô cỏ, ngày vào/ra, số con, ngày nghỉ) — luân phiên 18–20 ô.

### 4.5 Bio / D5 / Processing (chung bảng mẻ)
- **BATCH_LOG**(EventBase + batch_code ME, dây_chuyền: D5_TMR\|D5_VIÊN\|Ủ_CHUA\|TRÙN_NẠP\|TRÙN_THU\|BSF\|BIOGAS\|COMPOST\|BIOCHAR\|IMO_EM\|ANOLYTE\|SƠ_CHẾ\|SẤY\|ĐÓNG_GÓI\|ÉP_MO_CAU\|THAN\|GIẾT_MỔ_THUÊ, recipe_version_id, lệnh_sx_id, location_id (ô/luống/máy), bắt_đầu, kết_thúc, nhiệt_đo, ẩm, trạng_thái: MỞ\|ĐÓNG\|CÔ_LẬP\|HỦY, cost_center)
- **BATCH_INPUT**(batch_id, sku/lot_id, kg, nguồn location) · **BATCH_OUTPUT**(batch_id, sku, lot_id_mới, kg, chất_lượng, tem_từ–đến)
- **QC_RESULT**(batch_id \| lot_id, chỉ_tiêu (ẩm, đạm, sai_số_trộn, dị_vật, vi_sinh…), giá_trị, giới_hạn, đạt, lab/nội_bộ, file)
- **CCP_LOG**(batch_id, ccp_code (nhiệt kho lạnh, kim loại, ẩm sấy, nước rửa…), giới_hạn_tới_hạn, giá_trị_đo, đạt, hành_động_khắc_phục, người, sop_id) — trường 11 SOP.
- **MATERIAL_BALANCE**(kỳ tuần, 6 dòng: sinh_khối_vào, TA_tiêu_thụ, sản_phẩm_ra, phân_sinh_ra, phân_xử_lý, phân_hữu_cơ_ra; chênh; sinh tự động)
- **RETAINED_SAMPLE**(lưu mẫu đối chứng 15 ngày / bếp 24h: batch, vị trí, hạn hủy)

### 4.6 Inventory (K1–K9)
- **WAREHOUSE**(code K1–K9, tên, farm_id, uom_mặc_định, chu_kỳ_kiểm_kê, kiểm_kê_theo: SKU\|KG\|M3\|CON, nhiệt_giám_sát BOOL) · **BIN**(vị trí)
- **LOT**(id, sku, lot_no (mã mẻ nội bộ hoặc lô NCC), ncc_id, ngày_sx, hạn, coa_file, trạng_thái: KHẢ_DỤNG\|CÔ_LẬP\|HẾT\|THU_HỒI, giá_vốn_bq)
- **INVENTORY_MOVE**(EventBase + sku, lot_id, ±qty, uom, từ_kho/bin, đến_kho/bin \| đối_tượng_nhận (chuồng/lô/mẻ/đơn), lý_do: NHẬP_MUA\|NHẬP_SX\|XUẤT_SX\|XUẤT_CHO_ĂN\|XUẤT_BÁN\|CHUYỂN\|TRẢ\|HỦY\|ĐIỀU_CHỈNH, điểm_ghi: CÂN_CẦU_D\|CỬA_KHO_QUÉT\|TRẠM_DẦU\|CÂN_CỔNG_LÕI\|SILO_SENSOR\|APP, weigh_ticket_id, gate_log_id, ref_type/ref_id (batch, order, feed_log…), giá_vốn)
- **STOCK_BALANCE** (materialized view theo sku×lot×kho: tồn đầu + nhập − xuất, giá vốn BQ di động, ngày_tồn)
- **ADJUSTMENT**(code DC, kho, sku, lot, ±qty, lý_do, người_đề_nghị, người_duyệt KTT, trạng_thái, hiện_trong_báo_cáo_chênh = TRUE)
- **STOCKTAKE**(kỳ, kho, người_kiểm (ngoài bộ phận), dòng: sku, lot, tồn_sổ, tồn_đếm, chênh %, camera_ai_count) → sinh ADJUSTMENT nếu duyệt.
- **WEIGH_TICKET**(device cân, biển_số, khối_lượng_vào/ra/net, thời gian, ảnh, mục đích, sku, đối tác)
- **GATE_LOG**(EventBase + biển_số OCR, ảnh, chiều vào/ra, qua_cân BOOL, weigh_ticket_id, qua_hố_anolyte BOOL, mục_đích, người_lái, bảo_vệ_id)

### 4.7 Sales / CRM
- **CONTRACT**(code HD, kh_id, loại: BAO_TIÊU\|B2B\|LIÊN_KẾT_HỘ\|NHƯỢNG_QUYỀN, sku[], sản_lượng_cam_kết, giá, kỳ, trạng_thái) — tính "% sản lượng có hợp đồng trước".
- **ORDER**(code DH, kh, kênh 1–5, ngày, giao_ngày, trạng_thái: NHÁP\|CHỐT(≤15h)\|LỆNH_SX\|ĐÓNG_GÓI\|GIAO\|HOÀN_TẤT\|HỦY, giá_sàn_kiểm BOOL, giảm_giá_lý_do, người_duyệt) · **ORDER_LINE**(sku, lot yêu cầu, qty, giá, thuế)
- **SALE**(EventBase + order_id, kh, sku, lot_id, qty, giá, kênh, hóa_đơn_số, thanh_toán: CK\|POS\|COD, khách_ký_ảnh, giao_bởi) — mỗi dòng giao thực = 1 SALE (bộ gốc).
- **PAYMENT**(kh, số tiền, phương thức, ref ngân hàng/POS, ngày, đối chiếu_status) · **RECEIVABLE** view công nợ ngày.
- **CUSTODY_CONTRACT** (thay ADOPTION — module M21 chăm sóc hộ: kh, loại NHẬN_NUÔI\|KÝ_GỬI\|ĐẦU_TƯ\|TẶNG, animal_id[]/plot, gói, phí/kỳ, tiền thu trước → nợ dịch vụ, đối_ứng_30%, quyền quyết định cuối kỳ, bảo hiểm, xử lý chết/bệnh, hợp đồng điện tử, consent NĐ13, trạng thái) · **CUSTODY_STATEMENT**(hợp đồng, kỳ, chi phí phân bổ, giá trị con, ảnh mốc, PDF gửi khách) · **CUSTOMER_PORTAL_ACCESS**(kh, animal_id, quyền xem live/ảnh/chat, lịch camera) · **LIVE_SCHEDULE**(camera_id, khung giờ, khu cho phép) · **CUSTOMER_MESSAGE**(kh, animal_id, nội dung, SLA trả lời, người trả lời)
- **PRICE_FLOOR**(sku, giá_thành_FMS, biên_tối_thiểu, giá_sàn, quý, GĐ duyệt)
- **CUSTOMER_TOUCH**(CRM nhẹ: liên hệ, khiếu nại → INCIDENT nếu ATTP)

### 4.8 Resort
- **ROOM / RATE_PLAN / BOOKING**(code BK, tệp: MICE\|GIA_ĐÌNH\|HỌC_TẬP, đoàn/khách, phòng[], ngày, giá, kênh, trạng_thái, check-in tự động mã khóa) · **GUEST**(ẩn danh hóa sau 5 năm) · **FNB_ORDER**(khung giờ, món, số suất, xuất kho K5/K6 → INVENTORY_MOVE) · **KITCHEN_SAMPLE_LOG**(lưu mẫu 24h) · **TOUR_STATION**(12 trạm QR, 3 ngôn ngữ, đàn diễn) · **NPS_SURVEY**(booking, điểm 0–10, nhận xét) · **SAFETY_CHECK**(checklist an toàn trẻ em/mặt nước theo ca).

### 4.9 HR – KPI – Payroll
- **POSITION**(vai A1–A14, phòng, khung 3P) · **SHIFT**(ca, người, khu) · **CHECKLIST_RUN**(EventBase + template/sop_id, ca, người, từng bước kết quả ✔/✘/ghi chú, ảnh, xanh_hết BOOL, duyệt_bởi) · **CERTIFICATE**(staff, sop_id, ngày đạt, người chấm, hạn rà) · **SKILL_MATRIX**(vị trí, staff, % kỹ năng, dự phòng ≥80%) · **TRAINING**(khóa, người, kết quả, ATTP/ATLĐ/sơ cứu) · **KPI_RESULT**(kỳ, staff/nhóm/CC, kpi_def_version, giá trị, mục tiêu, điểm, tiền thưởng lớp 2) · **BONUS_POOL**(khoán quý lớp 3: CC, lợi nhuận vượt, % chia, phân bổ) · **PAYROLL_RUN**(kỳ, staff, lớp1 3P, lớp2 KPI, lớp3 khoán, lớp4 năm/ESOP ảo, thưởng sáng kiến, khấu trừ, xuất file kế toán) · **PHANTOM_SHARE**(vị trí, % trao/năm, lịch, điều kiện mất).

### 4.10 Finance (nhẹ nội bộ; kế toán thuế thuê ngoài — tích hợp MISA)
- **EXPENSE_REQUEST**(số tiền, CC, hạn mức theo vai, người đề nghị, chuỗi duyệt: trưởng nhóm <2tr → trưởng phòng <10tr → GĐ <100tr → chủ; 2 chữ ký >20tr; SMS chủ >50tr; trạng_thái; file) · **APPROVAL**(đối tượng, người, thời gian, chữ ký điện tử/OTP) · **BUDGET**(CC, kỳ, kế hoạch/thực) · **FUND**(THIÊN_TAI 3% DT · BẢO_DƯỠNG 5% máy · ĐÀO_TẠO 1% lương · MARKETING 3–5% DT: trích tự động, số dư) · **TRANSFER_PRICE**(giữa CC, sku, = 70% giá thị trường tham chiếu, kỳ) · **PL_SNAPSHOT**(CC, tháng, doanh thu ngoài + nội bộ, chi phí trực tiếp, phân bổ, EBITDA, khóa ngày 5) · **GATE**(C1–C4, tiêu chí[], trạng thái, ngày đạt, người duyệt = chủ) · **GATE_CRITERIA**(gate, kpi_def, ngưỡng, kết quả tự tính) · **LOAN**(nợ/vốn chủ ≤0,8 cảnh báo) · **BANK_STATEMENT_LINE**(import sao kê → RC10) · **CASH_DRAWER**(két POS, 2 người ký chốt).

### 4.11 Risk – Compliance – SOP
- **RISK_REGISTER**(R1–R19 + địa phương, nhóm, chỉ số sớm → RISK_INDICATOR(kpi/sensor, ngưỡng cấp 1/2/3), hành động viết sẵn (SOP link), người chịu trách nhiệm, nguồn lực chuẩn bị, rà quý) · **INCIDENT**(code INC, loại: VẬN_HÀNH\|ATTP\|ATLĐ\|AN_NINH\|MÔI_TRƯỜNG\|TÀI_LIỆU\|TRUYỀN_THÔNG\|NEAR_MISS, mức, mô tả, ảnh, thời gian, khu, người, phân loại: SAI_SÓT\|QUY_TRÌNH\|GIAN_LẬN, trạng thái) · **FIVE_WHY**(incident, 5 tầng, gốc, biện pháp) · **CAPA**(hành động, người, hạn 7 ngày, sop_sửa_version) · **DRILL**(lũ/cháy/recall, ngày, thời gian đạt <12h/4h, biên bản) · **AUDIT_INTERNAL**(2 lần/năm, chuẩn, checklist, phát hiện → CAPA) · **STANDARD_CLAUSE**(ISO 9001/22000/HACCP/GlobalG.A.P/VietGAP/Halal/ASC: mã điều khoản, mô tả) ↔ SOP.trường_11 · **SKU_PASSPORT**(sku, thị trường, chuẩn cần, giấy có, hạn, trạng thái sẵn sàng).
- **SOP**(code, tên, bộ phận, L1 chuỗi, L2 quy trình, trạng thái) · **SOP_VERSION**(v, 10 trường + trường 11 clause[], ccp?, video_file, người viết/chuẩn hóa/ký, ngày ban hành, ngày rà (12 tháng), lượt dùng) · **SOP_STEP**(thứ tự, hành động đo được, chuẩn đạt, bằng chứng bảng nào) · **CHECKLIST_TEMPLATE** sinh từ SOP_STEP · **SOP_SIGNOFF**(chữ ký điện tử KTT/GĐ).

### 4.12 Traceability (GS1 EPCIS 2.0 hóa)
- **EPCIS_EVENT**(loại: ObjectEvent\|AggregationEvent\|TransformationEvent\|TransactionEvent, bizStep (commissioning, receiving, shipping, transforming, packing…), epcList (lot/animal/sscc), inputs/outputs, readPoint (location), bizLocation, quantities, sourceList/destList, ilmd (COA, kiểm dịch, ngưng thuốc), sinh tự động từ INVENTORY_MOVE/BATCH/SALE/EVENT_ANIMAL) — bảng chiếu, không nhập tay.
- **TRACE_LINK**(from_lot → to_lot, batch, tỷ lệ) → cây 1-lùi-1-tiến. **QR_CODE**(GS1 Digital Link `https://id.itranfarm.vn/01/{gtin}/10/{lot}`, tem đánh số K9, trạng thái in/dán/hủy). **RECALL**(mock/thật, lot gốc, thời gian bắt đầu/kết thúc, cây truy, khách nhận[], biên bản, ≤4h) · **AUDIT_PACK**(yêu cầu: khoảng thời gian/SKU/chuẩn, sinh ZIP CSV+PDF, ≤24h, sha256).

### 4.13 IoT & Brain
- **SENSOR_READ**(hypertable: ts, device_id, metric (DO, pH, NH3, nhiệt, ẩm, mực_nước, silo_kg, nhai_lại, bước, vị_trí…), value, quality, farm_id) · **CALIBRATION**(device, ngày, chuẩn, trước/sau, người, hạn kế) · **DEVICE_STATE**(online, pin, rssi, fw).
- **ALERT_RULE**(+VERSION: tên, biểu thức (CEL/JSON-logic), nguồn (sensor/kpi/event/lịch), cửa sổ, mức VÀNG/CAM/ĐỎ, người nhận (vai + cấp trên), kênh (app/còi/SMS/Zalo), SOP kích hoạt, cooldown, người sửa, lý do) · **ALERT**(rule_version, đối tượng, giá trị, mức, thời gian, ack_by, ack_at, resolved, phản hồi phút, incident_id?)
- **KPI_DEF**(+VERSION: mã, tên, công thức (SQL/DSL), đơn vị, mục tiêu, ngưỡng vàng/đỏ, kỳ, gắn vai/CC, dùng lương lớp?) · **KPI_VALUE**(kpi, đối tượng, kỳ, giá trị, snapshot đầu vào).
- **RC_RULE**(RC1–RC10 + thêm: công thức 2 vế, ngưỡng, kỳ, người nhận) · **RECON_RESULT**(bất biến: kỳ, rule, vế A, vế B, lệch %, mức, bảng chi tiết JSON, ack, điều tra_incident_id).
- **FORECAST**(loại: sản lượng sữa/trứng, tồn ủ chua, giá bò, dòng tiền, đẻ dự kiến, thu hoạch, công suất trục; horizon; giá trị; mô hình; độ tin cậy) · **RECOMMENDATION**(ngữ cảnh, gợi ý, căn cứ, người nhận, chấp nhận?) · **REPORT_SNAPSHOT**(loại: NGÀY\|THỨ_6\|PL_THÁNG\|QUÝ\|NĂM, kỳ, file PDF/HTML, dữ liệu JSON, khóa).

### 4.14 HQ / Param
- **FARM_PROFILE**(20 tham số địa phương hóa: đất-nước, khí hậu, giống, thị trường, pháp lý, nguyên liệu ngoài) · **PARAM_SET**(S, K, tỷ lệ đất 8 nhóm, định mức/con, module bật/tắt) · **PARAM_OUTPUT**(bảng Lớp C: diện tích 17 khu, đàn, hạ tầng, checklist 17 khu ✔) · **SOP_DISTRIBUTION**(sop_version → farm[], trạng thái nhận/ký) · **CROSS_AUDIT**(trại A audit trại B, checklist, kết quả) · **FRANCHISE**(F0x, hợp đồng, phí, quyền kiểm tra, KPI theo dõi).

### 4.15 R&D
- **GENETIC_LINE**(loại: cây/con/vi sinh, tên, nguồn, thế hệ, đặc tính JSON, pháp lý, trạng thái) · **TRIAL**(mã, mục tiêu, giả thuyết, đối tượng lô/ô/bể/luống, ngày, thiết kế) · **TRIAL_ARM**(trial, tên: THỬ\|ĐỐI_CHỨNG, đối tượng, tham số) · **TRIAL_OBSERVATION**(arm, ngày, chỉ tiêu, giá trị, nguồn: tay/CROP_LOG/EVENT/BATCH/SENSOR) · **TRIAL_RESULT**(thống kê, kết luận, đề xuất → SOP/RECIPE/danh mục, người duyệt) · **PILOT**(module dossier, quy mô 10%, KPI nghiệm thu, quyết định) · **LAB_SAMPLE/LAB_RESULT**(mẫu, phòng lab, phương pháp phiên bản, kết quả, file) · **KNOWLEDGE_DOC**(quyền hạn chế) · **INNOVATION**(người, mô tả, giá trị tiết kiệm, thưởng).

### 4.16 XNK
- **MARKET_PROFILE**(quốc gia/khách, sku[], mã HS, chuẩn cần[], nhãn, ngôn ngữ, thuế/quota, ghi chú) · **TRADE_PARTNER**(loại: NHÀ_NK\|ĐẠI_LÝ_XK\|FORWARDER\|HÃNG_TÀU\|NGÂN_HÀNG\|ĐẠI_LÝ_HQ, KYC) · **TRADE_CONTRACT**(số, đối tác, incoterm, tiền tệ, điều kiện thanh toán, dòng SKU/qty/giá, lịch giao, phạt) · **SHIPMENT**(contract, container/số seal, lạnh?, cảng đi/đến, ETD/ETA, trạng thái, nhiệt log → SENSOR, chi phí) · **TRADE_DOCUMENT**(shipment, loại, số, ngày, file, trạng thái, checklist bắt buộc theo thị trường) · **CUSTOMS_DECLARATION**(shipment, dữ liệu tờ khai, trạng thái) · **IMPORT_PERMIT**(hàng nhập, giấy phép, kiểm dịch, cách ly liên kết ANIMAL/LOT) · **FX_RATE**(tiền tệ, ngày, nguồn) · **INTL_PAYMENT**(contract, loại L/C\|T/T\|D/P, số tiền, ngoại tệ, ngày, ngân hàng, đối soát) · **LANDED_COST**(lot nhập, giá + cước + thuế + phí → giá vốn).

## 5. LUẬT TÍNH TOÁN GẮN DỮ LIỆU

- **Sổ cái kho:** `tồn cuối = tồn đầu + Σnhập − Σxuất` theo sku×lot×kho; giá vốn bình quân di động; không bút toán tay — chỉ qua ADJUSTMENT có duyệt.
- **Sổ đàn K8:** tồn = COUNT(ANIMAL trạng thái sống) + Σ group.số_con; giá trị = Σ(con × đơn giá theo trạng thái) từ PRICE_LIST nội bộ.
- **Ngày-tồn:** tồn / tiêu thụ bình quân 14 ngày (ủ chua ≥60/45/30; nguyên liệu mua).
- **Ngưng thuốc:** ANIMAL.ngày_ngưng_thuốc_đến = max(ĐIỀU_TRỊ.ngưng_thuốc_ngày); chặn XUẤT/giết mổ khi chưa hết.
- **% sản lượng có hợp đồng trước** = Σ CONTRACT.sản_lượng_cam_kết kỳ / sản lượng dự kiến kỳ.
- **Giá chuyển nội bộ** = 70% giá thị trường tham chiếu (PRICE_LIST loại THỊ_TRƯỜNG, cập nhật tuần).

## 6. DỮ LIỆU KHỞI TẠO (seed) BẮT BUỘC
UOM · loài/giống · 9 kho · 12 CC · 14 vai + quyền · 19 rủi ro khung · KPI_DEF (mục 6 file gốc) · ALERT_RULE mặc định (mục 7 + AL-PAPER-24H, AL-PAPER-SERIAL, AL-BACKUP-FAIL, AL-DRILL-DUE) · **RC1–RC16 theo bảng chuẩn file 06 mục 3 (RC11 = giấy–số)** · 8 mẫu phiếu giấy BM01–08 · SETTING/NORM giá trị mặc định (giờ cữ ăn 06:00/15:00, chốt đơn 15:00, nhiệt chuồng 35°C, ngưỡng lũ 3 cấp, ngày-tồn 60/45/30…) · 12 SLA điểm giao nhận · STANDARD_CLAUSE (ISO 9001/22000/HACCP/GlobalG.A.P IFA/VietGAP/Halal cốt lõi) · SOP khung 66 L2 (mã, chưa nội dung) · NORM (định mức/con) · PARAM công thức Lớp B · trạng thái vòng đời · loại sự kiện · lịch vaccine theo tỉnh (tham số).

## 7. NHẬP DỮ LIỆU CŨ (Google Sheets GĐ1)
Bảng đích ↔ sheet nguồn 1-1 theo đúng schema Phần IX; công cụ import: upload CSV/XLSX → validate (ID đúng mẫu, FK tồn tại, ngày hợp lệ, số dương) → báo cáo lỗi từng dòng → nạp với `source = IMPORT`, `backfilled = TRUE`, `import_batch_id`; có nút rollback theo `import_batch_id` trong 24h (đánh dấu SUPERSEDED, không xóa).
