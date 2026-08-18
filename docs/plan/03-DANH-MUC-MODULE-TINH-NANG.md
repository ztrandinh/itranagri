# 03 · DANH MỤC MODULE & TÍNH NĂNG ITRAN AGRI ("CƠ THỂ" PHẦN MỀM)
*Ẩn dụ bộ gốc: Xương = hạ tầng · Mạch = 5 trục · Thần kinh = FMS · Não = engine · Miễn dịch = an toàn + giám sát 3 lớp · Hormone = lệnh kế hoạch. Mỗi module = 1 "cơ quan": tự làm việc của mình, giao–nhận qua sự kiện & 12 SLA. Ký hiệu ưu tiên: **G1** (MVP) · G2 · G3 · G4. Nguồn: FILE-GỐC IX.8, Phụ lục A/B, Quyển 3–5, benchmark file 01.*

## 0. BẢN ĐỒ MODULE (20 nghiệp vụ + 1 nền + cơ chế mở rộng vô hạn)

| # | Module | Cơ quan | Phòng | GĐ |
|---|---|---|---|---|
| M0 | PLATFORM (identity, tenant, master, ID, audit, file, notify, workflow, rule, report, import/export, API hub, i18n) | Xương + thần kinh | Công nghệ | G1 |
| M1 | LIVESTOCK (bò · gà 2 khối · dê · RAS · tôm/bè) | Cơ quan chăn nuôi | Sản xuất CN | G1 |
| M2 | FEEDING (FEED_LOG, xe trộn, silo) | Mạch dinh dưỡng | SX CN | G1 |
| M3 | CROP (lô GIS, lịch vụ, work order, máy, NDVI, ủ chua, đồng cỏ, viền) | Cơ quan trồng trọt | Sinh học–TT | G1 |
| M4 | BIO (trùn, BSF, biogas, compost/biochar, IMO/EM, anolyte, cân bằng vật chất) | Trái tim tuần hoàn | Sinh học–TT | G1 |
| M5 | FEEDMILL D5 (recipe, formulation LP, mẻ, ép viên, QC) | Chủ trục dinh dưỡng | Sinh học–TT | G2 |
| M6 | PROCESSING (mẻ chế biến, HACCP/CCP, tem, kho lạnh, lưu mẫu, giết mổ thuê) | Cơ quan chế biến | KD–resort | G3 |
| M7 | INVENTORY (K1–K9, lô, FEFO, sổ cái, kiểm kê, điều chỉnh, cân, cổng) | Mạch vật chất | HC-TC / KD | G1 |
| M8 | SALES/CRM (5 kênh, hợp đồng, đơn, POS, giao, công nợ, nhận nuôi, marketplace) | Trục thị trường | KD | G2 |
| M9 | TRACEABILITY (EPCIS, hộ chiếu, QR resolver, recall, audit pack) | Thần kinh ra ngoài | KD / CN | G2 |
| M10 | RESORT (PMS, F&B, tour, MICE, NPS, an toàn khách) | Cơ quan trải nghiệm | KD–resort | G3 |
| M11 | HR-KPI-PAYROLL (14 vai, ca, checklist, chứng chỉ, KPI, lương 4 lớp, khoán, ESOP ảo) | Hormone + miễn dịch | HC-TC-NS | G2 |
| M12 | FINANCE (CC, chi–duyệt, ngân sách, quỹ, giá chuyển, P&L, cổng chặn, đối soát tiền) | Máu tài chính | HC-TC-NS | G3 |
| M13 | RISK-COMPLIANCE (19 rủi ro, INCIDENT/5-Why/CAPA, drill, audit nội bộ, chuẩn, hộ chiếu SKU, nghĩa vụ pháp lý) | Miễn dịch | GĐ + KS CN | G3 |
| M14 | SOP (thư viện 4 cấp, phiên bản, video, ký, đọc-hiểu, checklist template) | DNA | Toàn trại | G1 |
| M15 | IOT (thiết bị, cảm biến, hiệu chuẩn, gateway, camera AI) | Giác quan | Công nghệ | G2 |
| M16 | BRAIN (KPI, alert, RC, report, forecast, recommendation, AI assistant) | Não | Công nghệ | G1→G4 |
| M17 | HQ (công ty mẹ: ORG→REGION→FARM, đẩy SOP, so KPI, liên trại, hợp nhất, audit chéo, nhượng quyền, mua chung) | Hệ thần kinh trung ương | Công ty mẹ | A (lõi) → E |
| M18 | PARAM (tham số vùng/trại, engine thế số, Hồ sơ module 5 bước) | Bộ gen | Chủ đầu tư | A → E |
| M19 | R&D (giống, khảo nghiệm đối chứng, pilot, ươm/ấp/nhân men, lab, tri thức/IP) | Cơ quan tiến hóa | Sinh học–TT + Công nghệ (nhóm) | C → D |
| M20 | XNK & thương mại quốc tế (thị trường đích, hợp đồng ngoại thương, chứng từ, hải quan/logistics, nhập khẩu, thanh toán quốc tế) | Cửa khẩu | Kinh doanh (nhóm) | D → E |
| M21 | CUSTODY — chăm sóc hộ / nhận nuôi / ký gửi / đầu tư con vật, cổng khách "xem live" (mục 19e) | Cửa sổ ra khách | Kinh doanh + Chăn nuôi | C → D |
| M∞ | Module tương lai bất kỳ qua manifest + Hồ sơ module (mục 19d) | — | phòng có sẵn | — |

## 1. M0 · PLATFORM
| Tính năng | Chi tiết | GĐ |
|---|---|---|
| Tenant/Farm | ORG → FARM (F0x), hồ sơ trại, múi giờ, S, dải; bật/tắt module theo trại | G1 |
| Identity | OIDC Keycloak, vai 14 + hệ thống, MFA vai duyệt, PIN offline, phiên thiết bị, khóa từ xa | G1 |
| Phân quyền | RBAC + ABAC (phòng/CC/khu), ma trận mục 6, kiểm tra ghi≠duyệt, kiểm toán read-only | G1 |
| Master data | Loài/giống, UOM, SKU, đối tác, CC, vị trí, thiết bị, định mức, giá — import CSV, lịch sử thay đổi | G1 |
| Máy sinh mã | `[TRẠI]-[LOẠI]-[SỐ]`, sinh offline tạm, in QR/mã vạch hàng loạt (tai, luống, kho, thiết bị) | G1 |
| Audit trail | Append-only, hash-chain, xem lịch sử mọi bản ghi, "ai sửa gì lúc nào lý do gì" | G1 |
| File/bằng chứng | Ảnh/video/PDF nén, EXIF thời gian/GPS, gắn bản ghi, chống trùng sha256 | G1 |
| Thông báo | Push, in-app, SMS, Zalo ZNS, email, còi/đèn edge, TV; sở thích theo người; escalation | G1 (push/in-app) · G2 (ZNS/SMS) |
| Workflow | Duyệt đa cấp (chi, SOP, SKU, điều chỉnh, lệnh trại đóng), SLA, nhắc; DBOS | G2 |
| Rule engine | CEL cho alert/RC/validate; UI cấu hình có phiên bản | G1 (seed) · G2 (UI) |
| Report engine | Template Typst/HTML, lịch, snapshot, gửi kênh | G1 |
| Import/Export | Sheets/CSV/XLSX import có validate & rollback; export CSV/Parquet/JSON/PDF toàn bộ; xuất theo chuẩn (EPCIS, ICAR, ISOXML) | G1 |
| **Giấy–số (SPEC-02)** | Màn "📷 Nộp phiếu giấy" (chụp → form BM01–08 → nhập seri → upload, offline queue); màn "Nhập từ phiếu" (ảnh trái – form phải, lưu tự gắn `paper_serial` + `source=PAPER`, tick digitized); trang audit lọc theo `paper_serial` xem ảnh gốc cạnh dữ liệu; RC11/RC11b + AL-PAPER; in mẫu BM có seri; (backlog) OCR gợi ý điền — người vẫn xác nhận | **G1 — sprint đầu tiên có người dùng thật** |
| API hub | OpenAPI 3.1, API key/OAuth client, webhook, rate limit, log; connector marketplace | G2 |
| i18n | vi mặc định, en, (km/lo cho lao động, 3 ngôn ngữ trạm QR) | G1 vi/en |
| Trợ giúp | Hướng dẫn trong app theo vai, video SOP gắn màn hình, phản hồi lỗi 1 chạm | G1 |

## 2. M1 · LIVESTOCK
| Nhóm | Tính năng | GĐ |
|---|---|---|
| Hồ sơ cá thể (bò/dê) | Mã RFID + visual, giống, giới, ngày sinh, mẹ/cha (phả hệ 3 đời), nguồn, ảnh, trạng thái vòng đời, vị trí, cân gần nhất, ADG, ngưng thuốc, giá trị sổ đàn, sở hữu (nuôi rẽ/nhận nuôi %) | G1 |
| Nhóm/đàn (gà/RAS/tôm/bè/dê nhóm) | Số con, sinh khối, ngày vào, all-in-all-out, khối, thức ăn, KPI nhóm | G1 |
| Ghi sự kiện 2–3 chạm | Quét tai → chọn loại → xác nhận; hàng loạt (chọn nhiều/quét liên tục); giọng nói | G1 |
| Sinh sản | Danh sách động dục (vòng cổ) → phối (tinh lô từ K1) → khám thai (lịch 60–90 ngày) → sắp đẻ (280±) → đẻ (sinh mã bê, khó đẻ) → cai sữa → phân loại 3 hướng; đồng bộ hóa; KPI PR21, days open, calving interval | G1 |
| Sức khỏe | Bệnh nghi (từ A1 quét), khám, phác đồ thú y ký, điều trị (thuốc lô quét mã, liều, đường), **ngưng thuốc tự tính & chặn xuất**, vaccine lịch tỉnh, cách ly nhập 21 ngày, chết/xử lý xác, mổ khám | G1 |
| Cân & tăng trọng | Cân lối đi tự đổ (WEIGH_SESSION), **crush mode** (BLE cân + EID, ADG, giá trị, quyết định phân loại), pha vỗ 15-60-45, dự báo ngày xuất | G1 (tay) · G2 (BLE) |
| Di chuyển | Chuyển ô/chuồng/khu, luân phiên ô cỏ, geofence, lịch sử vị trí | G1 |
| Xuất bán | Chọn con đủ điều kiện (ngưng thuốc, kiểm dịch), cân xuất, giấy thú y ký, giá, kênh → SALE + K8 giảm | G2 |
| Gà 2 khối | Đẻ: trứng ngày (đếm băng), loại A/B, chết/loại, đệm lót/anolyte log, thay đàn cuốn chiếu; Thịt: lứa all-in-all-out, trống chuồng 14 ngày, sống/FCR/EPEF; chặn "chung người 2 khối trong ngày" (cảnh báo phân ca) | G1 |
| RAS/ao/bè | Bể/ao/lồng, thả (số/cỡ/nguồn), cho ăn theo cữ/máy, chết vớt, phân cỡ/tách/chuyển, thu; DO/pH/nhiệt live; KPI sống/FCR/SGR/TGC/sinh khối ước; SOP khẩn DO; kéo bè trú lũ | G1 (tay) · G2 (sensor) |
| Dê | Đàn ≤50, sinh sản đơn giản, đàn diễn resort | G2 |
| Kiểm đếm | Đếm tuần (STOCKTAKE K8), so camera AI, chênh → INCIDENT 24h | G2 (đếm) · G4 (camera) |
| Báo cáo | Sổ đàn K8, hồ sơ chăn nuôi TT 66/2025, medicine book, mortality book, hồ sơ kiểm dịch, GAP chăn nuôi | G2 |

## 3. M2 · FEEDING
Công thức mẻ QR tại xe (đúng RECIPE_VERSION), cân từng thành phần từ cân xe trộn (BLE) hoặc nhập, thứ tự nạp (rỉ mật sau cùng), thời gian trộn, rải 2 lượt, thừa máng % + ảnh, con bỏ ăn → BỆNH nghi; silo/vít tải tự ghi cám gà; máy cho ăn RAS; sai số ≤2%; SLA1 06:00/15:00; RC1/RC2. **G1** (nhập tay + ảnh) · **G2** (BLE/silo tự động).

## 4. M3 · CROP
| Nhóm | Tính năng | GĐ |
|---|---|---|
| Lô & bản đồ | Vẽ/import ranh (GeoJSON/KML/SHP), tầng cao độ, luân canh G1/G2/G3, ô cỏ 18–20, tuyến viền, mặt nước; layer NDVI/năng suất/đất; offline tile | G1 |
| Kế hoạch vụ | Lịch vụ 12 tháng theo tỉnh (tham số), cây/giống/lịch/năng suất KH, luân canh cảnh báo, ngân sách vụ | G1 |
| Lệnh việc (work order) | Lệnh lô: hoạt động, máy, người, vật tư lô; nhận trên app đầu bờ; bắt đầu/kết thúc = giờ máy; checklist máy 5'; xếp lịch đội máy | G1 |
| Nhật ký GAP | GIEO/BÓN/PHUN(sinh học; hóa học cục bộ cần lệnh GĐ + PHI cách ly)/TƯỚI(nguồn nước m³)/THU; trường bắt buộc GAP; khóa backdate; ảnh; nhiên liệu quét trạm dầu | G1 |
| Thu hoạch & ủ chua | Vé cân cầu tự động → K3; hào ủ (đóng/mở, tỷ trọng, phụ gia lô, ngày-tồn ≥60/45/30); mẫu ẩm; RC3 | G1 |
| Máy | Thiết bị, giờ máy, nhiên liệu/định mức, bảo dưỡng theo giờ, hỏng/downtime, thuê ngoài, dịch vụ máy cho ngoài (doanh thu CC), tracker GPS tự tách việc | G1 · G3 (GPS) |
| Đồng cỏ | Luân phiên ô, ngày nghỉ, số con, rào điện | G2 |
| Viễn thám/drone | NDVI 2 tuần drone; Sentinel-2 tự lấy; cảnh báo bất thường; drone volumetric hố ủ; kiểm cây viền lấn lối 2 lần/năm | G2 |
| Thời tiết/nước | Trạm cục bộ, dự báo lô, GDD/ET0, ẩm đất, mực sông (R1), test nước/đất lab | G2 |
| Kinh tế viền | Tuyến/cụm mã, ngày trồng, số cây, sản lượng nhặt/hái theo chuyến, checklist 6 câu | G2 |
| Báo cáo | Năng suất/lô/vụ, giá thành ủ chua, P&L lô, hồ sơ VietGAP/GAP, bản đồ năng suất 2 năm → Rx (ISOXML) | G2 · G4 |

## 5. M4 · BIO (Khu D sinh học)
Luống trùn (nạp/thu, nhiệt, ẩm, ủ sơ ≥7 ngày <35°C — chặn nạp nếu phân chưa đủ tuổi), BSF (chu trình khay, kén giống), biogas (m³, đuốc, điện phát), compost/biochar/giấm gỗ, IMO/EM/anolyte (mẻ, nồng độ, log khử trùng), rác bếp cân giao (SLA9), NH₃ KPI, cân bằng vật chất 6 dòng thứ 6, RC4, công suất trục chất thải (cảnh báo khi đàn > sức tải). **G1**.

## 6. M5 · FEEDMILL D5
Recipe theo loài/pha có phiên bản & duyệt KTT (recipe % thủ công có phiên bản là đủ cho giai đoạn đầu); **formulation LP least-cost** (nguyên liệu × dinh dưỡng × giá × tồn; ràng buộc ≤35%/nguồn, Halal không-BSF, đạm/năng lượng min) → đề xuất — **chỉ bật sau khi D5 chạy thật ≥ 60 ngày** (Góp ý v1.5); lệnh sản xuất từ KD (SLA10); mẻ: cân định lượng, lô nguyên liệu quét, kg ra, sai số, CCP (nhiệt/ẩm/kim loại), tem mẻ; ép viên/ủ; QC lab tháng; giá thành/kg vs cám công nghiệp (≤65%); tự chủ TA %; TMR bao bán ngoài (SKU). **G2**.

## 7. M6 · PROCESSING
HACCP plan builder (bước→mối nguy→CCP→giới hạn→giám sát→khắc phục), QC point tự sinh check, mẻ sơ chế/sấy/đóng gói/ép mo cau/than, kim loại/dị vật, lưu mẫu 15 ngày, tem GS1 số thứ tự (K9, RC12), kho lạnh nhiệt log, giết mổ thuê (lò cấp phép/Halal, giấy), truy xuất mẻ, giá thành SKU, thang bậc giá trị 1–5, checklist mở SKU (hộ chiếu chuẩn + pháp lý). **G3**.

## 8. M7 · INVENTORY
9 kho + bin; lô/hạn/COA; nhập (mua có COA/QC-trước-nhập, sản xuất), xuất (cho ăn, sản xuất, bán, hủy), chuyển; 4 điểm ghi (cân cầu, cửa kho quét, trạm dầu, cân cổng); FEFO gợi ý & cảnh báo <20% hạn; dual UoM; trạng thái lô (khả dụng/cách ly/thu hồi); sổ cái tự động, giá vốn BQ; kiểm kê chu kỳ (người ngoài bộ phận, đếm mù mobile), phiếu điều chỉnh duyệt KTT; sổ đàn K8 giá trị; nhật ký cổng (OCR biển số, cân, anolyte, ảnh); tem K9; ngày-tồn từng nguyên liệu; RC1/3/5/6/7/8/11; đơn mua/NCC phê duyệt/hợp đồng 2 NCC/loại. **G1** (lõi) · G2 (cổng OCR, RC đủ).

## 9. M8 · SALES/CRM
Khách/NCC (CRM nhẹ), 5 kênh, hợp đồng bao tiêu/liên kết hộ (% sản lượng có HĐ), đơn hàng chốt ≤15h → lệnh SX, giá sàn (giá thành + biên) và giảm giá có duyệt, POS quầy + nhà hàng (offline), giao hàng (quét kiện 2 lần, khách ký), SALE từng dòng, thanh toán CK/POS/VNPay/MoMo/VietQR, công nợ (≤15 ngày, chặn giao >30), "nhận nuôi" (thu trước, đối ứng 30%, cập nhật ảnh định kỳ), đăng ký giỏ tuần, khiếu nại → INCIDENT ATTP, ZNS thông báo, KPI kênh/khách/quay lại; marketplace connector (Shopee/TikTok) & e-invoice (G4). **G2**.

## 10. M9 · TRACEABILITY
EPCIS 2.0 event tự chiếu; cây 1-lùi-1-tiến; QR GS1 Digital Link `id.itranfarm.vn/01/{gtin}/10/{lot}` → trang công khai (hành trình, chứng nhận, CCP tóm tắt, thu hồi); tem in hàng loạt; recall (mock/thật, phạm vi, khách, giữ hàng, ZNS, thu hồi/hủy, biên bản, ≤4h) lịch 2 lần/năm; audit pack ≤24h; xuất EPCIS JSON-LD; adapter Cổng truy xuất quốc gia/iCheck (G4). **G2** (lõi) · G4 (cổng).

## 11. M10 · RESORT
Đơn vị lưu trú, rate plan/mùa/gói, booking (online/walk-in/đoàn), check-in tự động khóa mã, buồng phòng, folio + charge quầy/nhà hàng/tour, đặt cọc, F&B đặt trước khung giờ → xuất K5/K6, lưu mẫu bếp 24h, rác bếp → BSF, 12 trạm QR 3 ngôn ngữ, đàn diễn lịch (SLA11), MICE (phòng họp, BEO), khóa học 5 ngày/STEM, NPS QR/ZNS, checklist an toàn trẻ em/mặt nước, đăng ký lưu trú, KPI công suất/ADR/NPS/chi tiêu/khách; channel manager qua đối tác. **G3**.

## 12. M11 · HR-KPI-PAYROLL
Hồ sơ NS (HĐLĐ, khám SK, ATTP, PPE ký nhận), vị trí/vai/phòng, ca & phân ca (không chung người 2 khối gà), chấm công QR/GPS + thời vụ khoán, checklist ca (từ SOP, xanh hết/ghi chú, duyệt trưởng nhóm), chứng chỉ SOP nội bộ (chấm, hạn), ma trận kỹ năng dự phòng 80%, luân chuyển chéo, đào tạo/đọc-hiểu SOP đổi bản, KPI tháng tự chấm → lớp 2, khoán quý CC → lớp 3, chia năm + ESOP ảo → lớp 4, thưởng sáng kiến/quý không dịch, hoa hồng HĐ; payroll VN engine (BHXH/TNCN phiên bản) hoặc xuất MISA; đánh giá hành vi 2 chiều; phép/lịch khóa cao điểm; hợp đồng GĐ/cố vấn khung; kịch bản mất 2 vị trí lõi. **G2** (checklist/KPI/chứng chỉ) · G3 (payroll).

## 13. M12 · FINANCE
CC cây + chiều chu kỳ; đề nghị chi theo hạn mức vai → duyệt (2 chữ ký >20tr, SMS chủ >50tr); ngân sách; quỹ tự trích (thiên tai 3%, BD 5%, đào tạo 1%, marketing 3–5%); giá chuyển 70%; P&L phân hệ ngày 5 (khóa); dòng tiền 90 ngày; quỹ lưu động ≥60 ngày; nợ/vốn ≤0,8; **cổng chặn C1–C4** tiêu chí tự tính + hồ sơ + duyệt chủ; **Hồ sơ module 8 mục + 5 bước** (kiểm công suất trục tự động, pilot 10%, nghiệm thu số liệu); đối soát tiền RC10 (import sao kê/POS); TSCĐ khấu hao theo giờ máy; xuất/đồng bộ MISA; nợ dịch vụ nhận nuôi. **G3**.

## 14. M13 · RISK-COMPLIANCE
Sổ 19 rủi ro + địa phương (chỉ số sớm gắn KPI/sensor, ngưỡng cấp, hành động SOP, người, nguồn lực), ma trận L×S, INCIDENT mobile (ảnh, loại, mức, near-miss), 5-Why/fishbone, CAPA 7 ngày → sửa SOP, drill (lũ <12h, cháy, recall <4h) biên bản, audit nội bộ 2 lần/năm theo điều khoản, control ↔ chuẩn, hộ chiếu SKU (nội địa/xuất), lịch nghĩa vụ pháp lý (giấy phép, môi trường, PCCC, bảo hiểm, nhãn hiệu), lệnh "trại đóng"/lũ, khủng hoảng truyền thông SOP-KD-05.3, xem xét lãnh đạo quý, sổ bài học chia sẻ F0x. **G3** (INCIDENT G1).

## 15. M14 · SOP
Cây 8 chuỗi → 66 L2 → ~410 L3 → bước; mã `SOP-BP-L2.n`; 10+1 trường; trạng thái nháp→chuẩn hóa→ký ban hành (chữ ký điện tử KTT/GĐ); phiên bản, ngày rà 12 tháng, lượt dùng, khai tử; video ≤5' (quay từ app, nén); AI soạn nháp từ video/ghi âm; template checklist sinh từ bước; gắn CCP/điều khoản chuẩn; "không SOP ký = không giao việc" (chặn phân ca vào việc chưa có SOP); đọc-hiểu khi đổi bản; xuất bộ SOP thành gói nhượng quyền/giáo trình (bậc 5). **G1**.

## 16. M15 · IOT
Danh mục thiết bị, gán vị trí, MQTT topic/codec, trạng thái/heartbeat/pin, hiệu chuẩn (lịch, trước/sau), OTA, gateway edge quản lý (Portainer), ChirpStack tenant, camera AI (đếm, biển số, PPE, thức ăn thừa), dashboard cảm biến live (ECharts), chất lượng dữ liệu (quality flag), driver: cân, RFID, DO, silo, đồng hồ điện/nước, thời tiết, vòng cổ (API hãng), tracker GPS. **G2** (cân/RFID/DO/silo) · G3 (điện/nước/thời tiết/GPS) · G4 (camera).

## 17. M16 · BRAIN → xem file 06. G1: KPI/alert/report cơ bản; G2: RC đầy đủ, KPI→lương; G3: forecast v1, recommendation, AI assistant; G4: camera, benchmark, forecast v2.

## 18. M17 · HQ — CÔNG TY MẸ QUẢN NHIỀU TRẠI, NHIỀU VÙNG (lõi từ Đợt A, đầy đủ Đợt E)
| Nhóm | Tính năng | Đợt |
|---|---|---|
| Mô hình tổ chức | ORG (công ty mẹ) → REGION (vùng: tham số tỉnh/vùng) → FARM (F0x, pháp nhân con, S, dải, module bật/tắt) → HUB/vệ tinh; người dùng có thể thuộc nhiều trại/HQ; chuyển ngữ cảnh trại 1 chạm | **A** |
| Danh mục toàn hệ vs trại | SKU/SOP/KPI/alert/RC/định mức/chuẩn cấp ORG (scope GLOBAL) — trại kế thừa, chỉ ghi đè tham số cho phép (Lớp C), không sửa Lớp A/B | **A** |
| Dashboard đa trại | So KPI/đỏ/cổng chặn/tồn tiền/chênh kiểm kê giữa trại & vùng; xếp hạng; drill xuống trại; báo cáo chủ đầu tư đa trại (1 trang thứ 6 hợp nhất) | **B** |
| Đẩy SOP & chuẩn | SOP_DISTRIBUTION: phiên bản mới → trại nhận → KTT ký → đọc-hiểu nhân sự; theo dõi % trại đã áp dụng; đẩy KPI/alert/RC phiên bản | **B** |
| Liên trại | Chuyển kho liên trại (xuất A → nhập B, giá chuyển 70%, SLA); chuyển giống liên trại bắt buộc cách ly 21 ngày như mua ngoài; hub nhận nguyên liệu/xử lý cho vệ tinh; hợp đồng B2B đa trại (một khách nhiều trại giao) | **C** |
| Hợp nhất | P&L theo trại/vùng/pháp nhân, intercompany loại trừ, quỹ tập trung (thiên tai) vs quỹ trại, cổng chặn từng trại + tổng | **D** |
| Tổng hành dinh | 4 chức năng (chuẩn · đào tạo · kiểm định · phần mềm): lịch audit chéo A→B, kết quả, CAPA; thư viện bài học từ INCIDENT mọi trại; đào tạo/chứng chỉ liên trại; ươm GĐ dự bị (ma trận kỹ năng liên trại) | **D–E** |
| Nhượng quyền F0x | Hồ sơ franchise (hợp đồng, phí quản lý, quyền kiểm tra đột xuất, KPI, thu hồi thương hiệu), tenant riêng cho đối tác, gói SOP+video xuất bản | **E** |
| Benchmark & mua chung | Benchmark ẩn danh giữa trại/vùng (FCR, giá thành, đẻ %…), sức mua chung (đơn gộp NCC, giá vùng) | **E** |
| Sandbox | F99 dữ liệu giả để đào tạo/demo/thử nghiệm không ảnh hưởng trại thật | **A** |

## 19. M18 · PARAM — BỘ GEN NHÂN BẢN
Hồ sơ địa phương hóa 20 tham số (theo REGION + FARM), engine thế số (S → 17 khu, đàn, hạ tầng, biên chế, vốn), checklist không sót khu, 3 ví dụ kiểm chứng (VD1/VD2/VD3 = test tự động), Hồ sơ module 8 mục/5 bước, in Phụ lục thế số F0x, mô phỏng "nếu S/K/vùng đổi", so sánh trại thực tế vs thế số (lệch → cảnh báo). **A** (mô hình tham số vùng/trại) · **B** (bản tính cho F01) · **E** (engine đầy đủ + mô phỏng).

## 19b. M19 · R&D — GIỐNG · KHẢO NGHIỆM · CÔNG NGHỆ (nhóm trong phòng Sinh học–TT & Công nghệ; khu ② giống & R&D của checklist 17 khu)
| Nhóm | Tính năng | Đợt |
|---|---|---|
| Hồ sơ giống | Giống cây/con/vi sinh (IMO/EM/meo nấm/tinh bò/kén BSF/trùn giống): nguồn, thế hệ, phả hệ, đặc tính, hồ sơ pháp lý (giấy phép lưu hành, kiểm dịch), tồn giống (K1/K8), nhân giống theo lô | C |
| Khảo nghiệm có đối chứng | Thiết kế thí nghiệm (lô/ô/bể/luống thử vs đối chứng, lặp lại), biến số, lịch đo, thu số liệu tự động từ CROP_LOG/EVENT/BATCH/SENSOR, phân tích (t-test/ANOVA cơ bản), kết luận → đề xuất đưa vào SOP/RECIPE/danh mục | D |
| Pilot module 10% | Gắn với Hồ sơ module 5 bước: pilot 1 quý, KPI nghiệm thu bằng số liệu, quyết định scale/khoán/dừng | D |
| Vườn ươm – ương cá – ấp trứng – nhân men | Mẻ ươm/ấp/nhân men (BATCH_LOG dây chuyền R&D), tỷ lệ nảy mầm/nở/sống, cấp giống cho trại/vệ tinh, bán giống (bậc 5) | C |
| Tri thức & IP | Sổ tay kỹ thuật, kết quả thí nghiệm, bí quyết (quyền hạn chế), sáng kiến nhân sự (thưởng 10% tiết kiệm), gói tri thức nhượng quyền/đào tạo | D |
| Lab | Mẫu (đất, nước, thức ăn, phân, vi sinh, dư lượng), gửi lab ngoài/nội bộ, kết quả có phiên bản phương pháp, hiệu chuẩn thiết bị lab | C |
| KPI R&D | Số khảo nghiệm/quý, tỷ lệ chuyển vào SOP, giá trị tiết kiệm/tăng thu từ R&D, giống tự chủ % | D |

## 19c. M20 · XUẤT NHẬP KHẨU & THƯƠNG MẠI QUỐC TẾ (nhóm trong phòng Kinh doanh; phục vụ mo cau, BSF sấy, cá chình, ĐTHT thăng hoa… và nhập giống/tinh/premix/thiết bị)
| Nhóm | Tính năng | Đợt |
|---|---|---|
| Hồ sơ thị trường đích | Theo quốc gia/khách: chuẩn bắt buộc (GlobalG.A.P, HACCP/ISO 22000, Halal JAKIM/MUI/GCC, ASC, tiếp xúc thực phẩm mo cau SGS/Intertek), mã HS, thuế/quota, nhãn, ngôn ngữ; gắn SKU_PASSPORT | D |
| Đối tác quốc tế | Nhà nhập khẩu/đại lý xuất khẩu ủy thác (2 năm đầu không tự xuất trực tiếp), forwarder, hãng tàu, ngân hàng; KYC; hợp đồng khung | D |
| Hợp đồng ngoại thương | Incoterms 2020, tiền tệ/tỷ giá (đa tiền tệ, tỷ giá ngày, chênh lệch), điều kiện thanh toán (T/T, L/C, D/P), lịch giao, phạt/khiếu nại; % sản lượng có hợp đồng trước (trục 5) | E |
| Chứng từ xuất | Proforma/Commercial Invoice, Packing List (SSCC/pallet), C/O (form theo FTA), Phytosanitary/Health/Veterinary certificate, Halal cert, COA lab, Bill of Lading, bảo hiểm; checklist thiếu chứng từ chặn xuất | E |
| Hải quan & logistics | Tờ khai (dữ liệu chuẩn cho VNACCS/đại lý hải quan), booking container/lạnh, cold-chain log (nhiệt container → SENSOR), lịch cắt máng, theo dõi lô hàng, chi phí logistics phân bổ vào giá thành xuất | E |
| Nhập khẩu | Giống/tinh/premix/thiết bị: giấy phép nhập, kiểm dịch nhập, cách ly 21 ngày (liên kết LIVESTOCK), COA/hồ sơ vật tư (K1), landed cost (giá + cước + thuế + phí) | D |
| Thanh toán quốc tế & thuế | Theo dõi L/C/T/T, công nợ ngoại tệ, hoàn thuế GTGT xuất khẩu, hóa đơn xuất khẩu; đối soát ngân hàng (RC10 mở rộng ngoại tệ) | E |
| Truy xuất xuất khẩu | EPCIS shipping/receiving quốc tế, GS1 GTIN/SSCC/GLN, QR đa ngôn ngữ, mock recall xuyên biên giới, hồ sơ audit theo yêu cầu nước nhập | E |
| KPI XNK | Doanh thu xuất theo thị trường/SKU, biên sau logistics, lead time, tỷ lệ chứng từ đúng lần 1, khiếu nại | E |

## 19e. ĐỊNH DANH VẬT NUÔI 3 CẤP & MODULE "CHĂM SÓC HỘ – XEM LIVE" (M21 · CUSTODY) — luật cứng theo chỉ đạo chủ đầu tư
**Nguyên tắc:** *Không con gia súc nào không có định danh.* Bò, dê (và mọi đại gia súc/tiểu gia súc) = **cá thể** bắt buộc; gia cầm, cá, tôm = **đàn/lô** bắt buộc (cá thể tùy chọn khi có giá trị: gà giống, cá bố mẹ). Mỗi con vật luôn thuộc đồng thời 3 cấp để tra cứu theo bất kỳ cấp nào:

| Cấp | Mã | Nội dung |
|---|---|---|
| **Cá thể** | `F01-BO-00123` (RFID ISO 11784/85 + số tai nhìn + QR hồ sơ + ảnh nhận diện) | Hồ sơ suốt đời: phả hệ, mọi sự kiện (sinh sản, sức khỏe, thuốc/ngưng thuốc, vaccine, cân/ADG, di chuyển, khẩu phần), ảnh/video theo mốc, giá trị sổ đàn, chủ sở hữu (trại/khách/đồng sở hữu %), trạng thái vòng đời, "sổ sức khỏe" xuất PDF/QR |
| **Lô nhập / cohort** | `F01-LN-2026-003` (đợt mua/đợt sinh/đợt cai sữa) | Nguồn NCC/giấy kiểm dịch/cách ly 21 ngày chung, giá nhập, so sánh hiệu quả lô, thu hồi theo lô |
| **Đàn / nhóm** | `F01-DAN-NAI-01`, `F01-GA-L03`, `F01-RAS-B12` | Chuồng/khu/ô cỏ, khẩu phần theo nhóm, KPI nhóm, kiểm đếm, camera đếm |
Chuyển cấp có vết (tách/gộp đàn, đổi lô); tra cứu 1 chạm từ bất kỳ mã nào; hồ sơ TT 66/2025 sinh từ đây.

**M21 · CUSTODY — chăm sóc hộ / nhận nuôi / ký gửi / đầu tư con vật (mở rộng ADOPTION thành module; kinh doanh "chăm sóc live hộ người dùng"):**
| Nhóm | Tính năng | Đợt |
|---|---|---|
| Hợp đồng chăm sóc | Loại: NHẬN_NUÔI (khách trả trước, nhận sản phẩm/quà) · KÝ_GỬI (khách sở hữu con, trại chăm phí/tháng) · ĐẦU_TƯ/NUÔI_RẼ (góp vốn, chia lợi nhuận %) · TẶNG/DOANH_NGHIỆP (quà tặng CSR); điều khoản, phí, kỳ, đối ứng 30%, quyền quyết định (bán/giết mổ thuê/nhận thịt/tái đầu tư), bảo hiểm, xử lý khi chết/bệnh (đổi con/hoàn/bảo hiểm) | C |
| Sở hữu & hạch toán | ANIMAL.owner (trại/khách/đồng sở hữu %); tiền thu trước = **nợ dịch vụ**, ghi nhận doanh thu theo kỳ chăm; chi phí chăm phân bổ vào con (thức ăn, thuốc, công) → báo cáo minh bạch cho khách; giá trị con theo cân/giá thị trường | C–D |
| Cổng khách hàng ("app của người nuôi hộ") | Web/PWA + Zalo Mini App: chọn/nhận con (ảnh, phả hệ, vị trí), **hồ sơ live** (sự kiện, cân/ADG, sức khỏe, khẩu phần), ảnh/video định kỳ tự động từ mốc SOP (cân, khám, đẻ) và theo lịch (tuần), **camera live theo khung giờ** (chuồng/đàn diễn — không vào lõi an toàn sinh học), thông báo (Zalo/push) khi có sự kiện, chat hỏi trại (trả lời có SLA), đặt tour thăm (resort), đặt mua sản phẩm từ con mình (trứng/thịt/phân), gia hạn/thanh toán VietQR, giới thiệu bạn | C (hồ sơ + ảnh) · D (live camera, chat, mua) |
| Vận hành trại | Việc "chăm con của khách" vào checklist ca (chụp ảnh mốc bắt buộc), SLA phản hồi khách, cảnh báo con khách bệnh/chết → quy trình thông báo & xử lý theo hợp đồng, báo cáo tháng tự sinh cho từng khách | C |
| Marketing/kinh doanh | Gói giá theo loài/giai đoạn, số suất mở, danh sách chờ, mã giới thiệu, đo chuyển đổi khách resort → nhận nuôi (KPI ≥25% quay lại), đánh giá/NPS | D |
| Pháp lý & dữ liệu | Hợp đồng điện tử, NĐ 13/2023 (consent, ẩn danh), quyền riêng tư camera (chỉ khu cho phép), điều khoản rủi ro sinh học, hóa đơn/biên nhận | C |
| KPI | Số con đang chăm hộ, doanh thu định kỳ (MRR), tỷ lệ gia hạn, NPS khách nuôi hộ, thời gian phản hồi, sự cố con khách | D |

## 19d. CƠ CHẾ THÊM BỘ PHẬN/MODULE MỚI (bất kỳ, tương lai) — "thêm nhà ga, không vẽ thêm đường ray"
Mỗi module = 1 bounded context có **manifest** (`module.json`: tên, phòng chủ quản, bảng, sự kiện phát/nhận, 6 chỉ số chuẩn, KPI, alert, SLA giao nhận, vai/quyền, màn hình, seed) đăng ký với PLATFORM. Kernel cung cấp sẵn: ID, audit, RLS, sự kiện, workflow, rule, KPI/alert/RC engine, báo cáo, import/export, API, i18n. Quy trình bật module mới = **Hồ sơ module 8 mục** (Lớp A) + kiểm công suất 5 trục + pilot 10% → bật flag theo trại. Nhờ đó R&D, XNK, hay bất kỳ nhóm nào sau này (logistics, đào tạo/Academy, năng lượng, tín chỉ carbon…) đều cắm vào mà không sửa lõi và không lập "phòng thứ 6".

## 20. MÀN HÌNH THEO VAI (mobile ≤3 chạm; nguồn Phụ lục A)
| Vai | Màn hình chính (mobile) | Nút nhập chính | Web thêm |
|---|---|---|---|
| A1 TMR | Checklist ca · Mẻ hôm nay (QR công thức) · Cân từng thành phần (BLE) · Ảnh máng · Con bỏ ăn (quét) | FEED_LOG, EVENT BỆNH nghi | — |
| A2 Sinh sản–bê | Cảnh báo động dục/sắp đẻ · Danh sách việc (phối/khám/đẻ/cai) · Quét tai → sự kiện · Crush mode | EVENT_ANIMAL | Hồ sơ nái, KPI |
| A3 Gà | Khối của tôi (khóa khối khác) · Trứng cuối ca · Chết/loại · Anolyte log · Cám xác nhận | INVENTORY_MOVE trứng, EVENT đàn, FEED_LOG | — |
| A4 RAS | Đồ thị DO/pH đêm · Cho ăn cữ/bể · Chết vớt · SOP khẩn 1 chạm | FEED_LOG, EVENT bể | — |
| A5 Lái máy | Lệnh lô hôm nay · Checklist máy 5' · Bắt đầu/kết thúc (giờ máy) · Quét dầu · Vé cân | CROP_LOG, MOVE K7 | Bản đồ lô, lịch vụ |
| A6 Khu D | Ô hôm nay (nạp/thu) · Nhiệt/ẩm · Cân khu D · Chặn nạp phân non | BATCH_LOG | Cân bằng vật chất |
| A7 D5/Chế biến | Lệnh SX · Mẻ (quét lô NL, kg ra, CCP) · In tem · Vệ sinh đầu ca | BATCH_LOG, MOVE K4/5/6, CCP_LOG | Recipe, QC |
| A8 Kho–giao | Nhập/xuất quét mã · FEFO gợi ý · Kiểm kê · Giao (quét kiện, khách ký) · Nhiệt kho lạnh | INVENTORY_MOVE, SALE giao | Sổ cái, chênh |
| A9 KD | Đơn (chốt ≤15h) · Khách · Công nợ · POS · Nhận nuôi · Khiếu nại | ORDER, SALE, PARTNER | Hợp đồng, kênh, giá sàn |
| A10 Resort | Booking hôm nay · Check-in · Bàn/bếp · Lưu mẫu · Rác bếp cân · NPS | BOOKING, FNB, MOVE | PMS, MICE |
| A11 Bảo vệ | Tuần tra QR · Cổng (ảnh xe OCR, cân, anolyte) · Sự cố | GATE_LOG, INCIDENT | — |
| A12 KTT | Đỏ đêm qua · Duyệt checklist/điều chỉnh/phác đồ · Sửa RECIPE/SOP · Kiểm kê đột xuất · Đối chiếu chéo | APPROVAL | Toàn khối, KPI, RC |
| A13 KS công nghệ | Uptime · Thiết bị offline · Hiệu chuẩn · Backup · Cấu hình alert · Audit pack | CALIBRATION, ALERT_RULE | Toàn hệ |
| A14 GĐ | 15' sáng: 1 trang + tiền + đỏ · Duyệt chi/SOP/SKU/lệnh · Cổng chặn · Rủi ro | APPROVAL | Toàn trại |
| Chủ đầu tư | Đa trại, cổng, SMS >50tr, 3 quyền không ủy | Duyệt cổng/vốn | HQ |
| Kiểm toán | Read-only toàn bộ + audit pack | — | — |
| Khách QR | Trang hành trình sản phẩm | — | — |

## 21. MA TRẬN PHÂN QUYỀN (rút gọn; R đọc · W ghi · A duyệt · X không)
| Đối tượng | Công nhân (vai mình) | Trưởng nhóm | KTT | GĐ | Chủ | KS CN | Kiểm toán |
|---|---|---|---|---|---|---|---|
| Sự kiện phân hệ mình | W — **không có nút UPDATE**; trong 72h được tạo bản ghi *supersede* (bản mới thay bản cũ, không cần duyệt, có vết); sau 72h chỉ qua ADJUSTMENT có KTT duyệt | W + A ca | R + A | R | R | R | R |
| Sự kiện phân hệ khác | X | X | R (khối) | R | R | R | R |
| RECIPE/SOP | R (được cấp) | R | W + A (không tự duyệt bản mình viết) | A ban hành | R | R | R |
| Tồn kho/điều chỉnh | W move | W | A điều chỉnh | R | R | R | R |
| Chi tiền | X | W <2tr | W <10tr | A <100tr | A >100tr | X | R |
| KPI/lương của mình | R | R (nhóm) | R (khối) | R | R | X | R |
| Alert rule/định mức | X | X | đề xuất | A | R | W (có vết) | R |
| Cổng chặn/Lớp A | X | X | X | đề xuất | A | X | R |
| Dữ liệu quá khứ | X sửa | X | X | X (không sửa số ai) | X | X | X |
| Xuất dữ liệu toàn bộ | X | X | khối | trại | tất cả | trại | tất cả (read) |

## 22. 12 SLA GIAO NHẬN → THỰC THI TRONG PHẦN MỀM
Mỗi SLA = 1 rule: điều kiện đo được + bằng chứng bảng + bên giao chịu KPI. Ví dụ SLA1: `FEED_LOG(khu, cữ) trước 06:00/15:00 kèm phiếu cân` → trễ = AL-SLA cho A7/D5. SLA2 phân chuồng→trùn ≤24h: so EVENT dọn chuồng vs BATCH nạp. SLA7: XUẤT phải có giấy thú y ký (RC14). SLA10: ORDER chốt ≤15h mới sinh lệnh SX. SLA12: lệnh dừng an toàn = trạng thái khóa nghiệp vụ tức thời.
