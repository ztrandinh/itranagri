# 01 · BENCHMARK PHẦN MỀM NÔNG NGHIỆP & ERP THẾ GIỚI → TÍNH NĂNG, CHUẨN KẾ THỪA
*Khảo sát thực tế (web, kiểm chứng 18/08/2026) 60+ sản phẩm & 20 chuẩn. Mục đích: đảm bảo ITRAN OS "thừa chứ không thiếu" và đồng bộ với thực hành tốt nhất. Mỗi mục: sản phẩm tham chiếu → điểm đáng học → quyết định áp dụng cho ITRAN OS (✅ áp dụng · ➕ mở rộng thêm so bộ gốc · ⏩ để sau · ❌ không).*

## 1. CHĂN NUÔI ĐẠI GIA SÚC (bò) — tham chiếu: Herdwatch, CattleMax, AgriWebb, BoviSync, UNIFORM-Agri, DairyComp 305, Breedr, Farmbrite, Ranchr; cảm biến: SenseHub (Allflex/MSD), smaXtec (bolus), Moocall

| Điểm đáng học | Nguồn | ITRAN OS |
|---|---|---|
| Cá thể **và** nhóm (mob/pen/lô) đều là thực thể hạng nhất, chuyển đổi qua lại | AgriWebb | ✅ ANIMAL + ANIMAL_GROUP |
| Vòng đời sinh sản đầy đủ: động dục, phối (tinh lô), đồng bộ hóa, khám thai, ngày đẻ dự kiến tự tính, khó đẻ, sẩy; KPI 21-day pregnancy rate, days open, conception rate, calving interval | DairyComp, BoviSync, UNIFORM | ✅ + ➕ 21-day PR, days open |
| **Tủ thuốc ảo:** quét mã vạch thuốc, lô/hạn, tự tính ngày ngưng thuốc thịt/sữa; **hiển thị trạng thái ngưng thuốc ngay tại cũi cân/bán và chặn bán** | Breedr, Herdwatch | ✅ RC8 + AL-WD chặn XUẤT ➕ quét mã vạch thuốc |
| **Crush mode:** phiên cân = cân Bluetooth + đầu đọc EID, hiển thị ADG, giá trị thị trường, ngưng thuốc, ra quyết định phân loại n-hướng ngay tại cũi | Breedr, AgriWebb | ➕ WEIGH_SESSION màn hình cũi, phân loại 3 hướng (GIỮ/VỖ/BÁN) |
| Chore list theo nhân viên hằng ngày, quét thẻ → hoàn thành việc; đăng nhập theo người để tính công | BoviSync | ✅ checklist ca theo vai (A1–A14) |
| Phả hệ ≥3 đời, EPD/EBV, đa sở hữu (nuôi rẽ), embryo | CattleMax | ➕ phả hệ 3 đời + đa sở hữu (nuôi rẽ/nhận nuôi) · ⏩ EPD |
| Đối chiếu tồn đàn (đầu kỳ + sinh + mua − chết − bán = cuối kỳ) | AgriWebb, Herdwatch | ✅ K8 + RC9 |
| Nộp sự kiện sinh/di chuyển/chết lên CSDL quốc gia (BCMS/NLIS/NAIT) | Herdwatch, AgriWebb | ➕ adapter "cơ quan quản lý": VN Thông tư 66/2025/TT-BNNMT (hồ sơ trại: đàn, xuất nhập, giống, thuốc/vaccine, xét nghiệm, giết mổ) + TE-FOOD Đồng Nai kiểu nền tảng tỉnh |
| Vòng cổ/bolus: nhai lại, nhiệt, uống, động dục yếu, sắp đẻ ~15h, stress nhiệt nhóm, cổng phân loại tự động; alert theo baseline từng con | SenseHub, smaXtec, Moocall | ✅ SENSOR_READ + AL-RUMI/HEAT/CALV ➕ baseline cá thể, cổng phân loại |
| Dự báo cân xuất, so chuẩn quốc gia/địa phương (benchmark) | Breedr | ➕ FORECAST cân xuất; benchmark giữa F0x (HQ) |
| Chuẩn ICAR ADE (JSON/REST, Apache-2) trao đổi dữ liệu vật nuôi | UNIFORM↔Datamars | ⏩ xuất ICAR ADE khi cần tích hợp thiết bị vắt/cân hãng lớn |

## 2. GIA CẦM — tham chiếu: BigFarmNet/BFN Fusion (Big Dutchman), Fancom Lumina/FarmManager, Rotem/Munters Trio, Porphyrio (Evonik), BinSentry, MTech Amino/Sonar

| Điểm đáng học | ITRAN OS |
|---|---|
| Đàn/nhà/lứa là chủ thể; hằng ngày: chết/loại, ăn/uống, trứng đếm + phân loại, cân đàn tự động + độ đồng đều, khí hậu (nhiệt/ẩm/CO₂/NH₃/thông gió) setpoint vs thực | ✅ ANIMAL_GROUP + EVENT + SENSOR ➕ độ đồng đều cân, water:feed ratio |
| KPI: hen-day/hen-housed %, egg mass, feed/egg, livability, FCR, EPEF, so chuẩn giống & so nhà–nhà | ➕ thêm hen-housed, egg mass, EPEF, đường cong chuẩn giống |
| Đèn giao thông trạng thái nhà, cảnh báo lệch sớm (early-warning bằng thống kê) | ✅ alert; ➕ phát hiện lệch đường cong |
| Cảm biến silo 3D → tồn cám, dự báo hết cám, cảnh báo "out-of-feed" | ✅ silo sensor → K4/FEED_LOG ➕ dự báo hết cám |
| Tích hợp bộ điều khiển chuồng (đọc/ghi setpoint từ xa) | ⏩ driver Rotem/Fancom qua Modbus/OPC-UA khi có |
| Nhật ký an toàn sinh học, liên kết lò mổ/ấp | ✅ SLA7 + GATE_LOG |

## 3. THỦY SẢN / RAS — tham chiếu: AKVA Fishtalk, ScaleAQ Mercatus, aquaManager, XpertSea, Aquabyte, eFishery, Aquaconnect

| Điểm đáng học | ITRAN OS |
|---|---|
| Lô/cohort theo bể; thả (số, cỡ, nguồn), chuyển/phân cỡ/tách, thu; ăn (tay/máy/camera viên), chết, chất lượng nước (DO, nhiệt, pH, NH₃/NO₂, kiềm) tay + cảm biến | ✅ RAS group + BATCH chuyển cỡ ➕ phân cỡ/tách bể |
| KPI: sinh khối ước, FCR sinh học & kinh tế, SGR, TGC, sống, cost/kg, feed on hand | ➕ SGR, TGC, sinh khối ước, định giá tài sản sinh học |
| Kế hoạch kịch bản thả–tăng–thu, ngân sách thức ăn, định giá tài sản sinh học (bio-asset valuation) | ➕ FORECAST RAS + K8 định giá |
| Camera AI ước sinh khối/sức ăn; máy cho ăn tự động ghi tiêu thụ | ⏩ camera; ✅ feeder → FEED_LOG |
| Trợ lý GenAI cho người nuôi (eFishery "Mas Ahya") | ✅ trợ lý AI |

## 4. PHỐI TRỘN THỨC ĂN (D5) — tham chiếu: BESTMIX (Adifo), Format Solutions/Brill (Datacor), Feedsoft

| Điểm đáng học | ITRAN OS |
|---|---|
| **Least-cost formulation (LP):** CSDL nguyên liệu × chất dinh dưỡng × giá × tồn; ràng buộc min/max từng chất & nguyên liệu; shadow price; what-if; premix đa cấp; mẫu theo loài/pha (NRC/CVB) | ➕ **module FORMULATION** trong D5: tối ưu LP (HiGHS/OR-Tools) đề xuất RECIPE mới khi giá/tồn đổi; ràng buộc ≤35%/nguồn, không-BSF cho Halal |
| Xác thực công thức trước khi ban hành → xưởng; nhãn thức ăn tuân thủ; tích hợp cân định lượng, mẻ, QC, truy xuất lô | ✅ RECIPE_VERSION duyệt KTT + BATCH_LOG + QC |
| Quản lý báo giá/hợp đồng NCC, giá động | ✅ CONTRACT NCC + PRICE_LIST |

## 5. TRỒNG TRỌT / FMIS — tham chiếu: John Deere Ops Center, Climate FieldView, Cropwise (Syngenta), xFarm, Agworld, Granular, Conservis, Trimble/PTx, Farmbrite, AgriDigital, Bushel Farm, Agrivi, Cropin, FarmERP, Traction Ag, FBN; thời tiết Sencrop/Davis; tưới Netafim GrowSphere/Lindsay FieldNET; drone DJI Terra/Pix4Dfields/DroneDeploy

| Điểm đáng học | ITRAN OS |
|---|---|
| Ranh lô: vẽ/đi GPS/import SHP-KML-GeoJSON-ISOXML; phiên bản ranh theo vụ; ô con/zone; PostGIS + raster COG | ✅ PLOT PostGIS ➕ import SHP/KML/ISOXML, phiên bản ranh |
| Lớp bản đồ: NDVI/NDRE (Sentinel-2/drone), năng suất, as-applied, đất; cảnh báo bất thường NDVI → task khảo sát | ✅ NDVI_LAYER ➕ Sentinel-2 tự lấy 5 ngày/lần + cảnh báo bất thường |
| Rx/VRA (bón biến lượng) xuất ISOXML/SHP đẩy màn hình máy | ⏩ khi có máy ISOBUS; xuất ISOXML từ bản đồ năng suất lô sau 2 năm (bộ gốc mục 03.4) |
| Lệnh việc (work order): sản phẩm, liều, máy, người, lô; phát mobile; e-sign; AI xếp lịch đội máy | ✅ CROP_LOG lệnh lô ➕ WORK_ORDER + xếp lịch máy theo lịch vụ |
| Telematics máy: vị trí, giờ, nhiên liệu, trạng thái; **tự nhận diện việc từ track GPS**, phân bổ chi phí máy vào lô | ✅ giờ máy/nhiên liệu ➕ tracker GPS rẻ → tự tách việc theo lô, RC7 |
| Bảo dưỡng theo giờ/ngày, phụ tùng, downtime, dự báo | ✅ AL-DEV ➕ phụ tùng tồn K1 |
| Thời tiết trạm cục bộ + dự báo theo lô: mưa, GDD, ET0, mô hình bệnh; cảm biến ẩm đất; DSS tưới; điều khiển van qua MQTT | ➕ WEATHER (trạm LoRa + API dự báo), GDD/ET0, ẩm đất; ⏩ điều khiển van |
| Vé thu hoạch (harvest ticket): lô, máy, xe, cân, ẩm, đích; bản đồ năng suất; hố ủ chua: ngày đóng, phụ gia lô, tỷ trọng, lịch mở, feed-out; đo thể tích đống ủ bằng drone | ✅ WEIGH_TICKET + SILAGE_PIT ➕ drone volumetric |
| Nhật ký BVTV/phân bón đủ trường bắt buộc GAP (lô, ngày, sản phẩm, hoạt chất, liều, người, lý do, PHI, máy), **không cho ghi lùi ngày (VietGAP 3.1.4)**, hồ sơ nước, đất, dư lượng, đào tạo | ✅ CROP_LOG ➕ trường bắt buộc + khóa backdate (chỉ "nhập bù" có cờ) |
| Lợi nhuận/lô/vụ/ha, so giống–đầu vào–đất, benchmark liên trại | ✅ P&L CC + ➕ P&L theo lô, benchmark HQ |
| Chuẩn: ISOXML/ADAPT (import máy), OGC SensorThings (mô hình quan trắc), Sparkplug B (gateway PLC), LoRaWAN/ChirpStack, GS1 EPCIS 2.0, GlobalG.A.P IFA v6 Smart, VietGAP TCVN 11892-1:2017 | ✅ xem file 02/05 |

## 6. KHO – SẢN XUẤT – AN TOÀN THỰC PHẨM — tham chiếu: Odoo 18/19, SAP Business One (F&B), Dynamics 365 BC, ERPNext, SafetyChain, FoodLogiQ, TraceGains, MasterControl, Intelex, SafetyCulture (iAuditor)

| Điểm đáng học | ITRAN OS |
|---|---|
| Kho đa cấp (site→nhà→khu→bin), vị trí ảo (cách ly/hủy/đang chuyển); lô bắt buộc theo nhóm SP; thuộc tính lô: ngày SX, hạn, ngày loại bỏ, ngày cảnh báo; **FEFO** theo removal date; hạn tự tính từ shelf-life; báo cáo lô sắp hết hạn | ✅ K1–K9 + LOT FEFO ➕ bin, vị trí ảo, ngày cảnh báo |
| **Kiểm kê chu kỳ** theo tần suất vị trí, đếm mù trên mobile, phiếu điều chỉnh có lý do + duyệt + hạch toán chênh | ✅ STOCKTAKE luân phiên người ngoài + ADJUSTMENT |
| Catch-weight/2 đơn vị (kg + con/khay) cho thịt, cá, trứng | ➕ dual UoM |
| Tuyến nhiều bước (nhận → QC → nhập; lấy → đóng → giao); putaway theo vùng nhiệt; giữ/cách ly lô chặn bán; đóng gói item→thùng→pallet (SSCC) | ➕ trạng thái LOT CÔ_LẬP, tuyến QC-trước-nhập cho vật tư cần COA; ⏩ SSCC pallet |
| **HACCP plan builder:** bước → mối nguy (sinh/hóa/lý/dị ứng) → CCP + giới hạn + tần suất + hành động; QC point tự sinh check tại nhận/sản xuất/giao; check Pass/Fail/Đo/Ảnh; vượt → NC → CAPA; SPC | ✅ CCP_LOG + trường 11 SOP ➕ HACCP_PLAN builder, QC point tự sinh, SPC đơn giản |
| NCC được phê duyệt: chứng chỉ (VietGAP/GAP/HACCP/ISO/Halal), COA tự nhắc hạn, spec vật tư phiên bản | ✅ PARTNER phê duyệt + COA ➕ nhắc hạn giấy NCC |
| Kiểm soát tài liệu SOP: phiên bản, duyệt, ngày hiệu lực, đọc-hiểu, đào tạo lại khi đổi bản; template checklist có logic/điểm/ảnh/chữ ký; thư viện | ✅ SOP_VERSION + CERTIFICATE ➕ "đọc-hiểu" bắt buộc khi SOP đổi bản |
| Môi trường (swab), mẫu lưu, lab ngoài import | ✅ RETAINED_SAMPLE + QC lab |

## 7. TRUY XUẤT & THU HỒI — tham chiếu: GS1 EPCIS 2.0/CBV, GS1 Digital Link, OpenEPCIS (Apache-2), IBM Food Trust, TE-FOOD, iCheck Trace, TraceVerified; VN: TCVN 12850:2019, NĐ 13/2022, TT 02/2024/TT-BKHCN, TCVN 13274/13275:2020, Cổng truy xuất quốc gia; FSMA 204

| Điểm đáng học | ITRAN OS |
|---|---|
| Sự kiện EPCIS: Object/Aggregation/Transformation/Transaction/Association; 5W+How; bizStep/disposition; sensorElement | ✅ EPCIS_EVENT chiếu từ MOVE/BATCH/SALE/EVENT_ANIMAL |
| QR GS1 Digital Link `/01/{GTIN}/10/{lot}?17=…` + resolver linkset (trang hành trình, COA, thu hồi) | ✅ QR_CODE ➕ resolver riêng `id.itranfarm.vn` |
| Cây truy lùi/tiến, cân bằng khối lượng lô; recall: phạm vi, khách bị ảnh hưởng, giữ hàng, thông báo ZNS/SMS, thu hồi/hủy, báo cáo, kiểm hiệu quả; **mock recall ≥ 6 tháng/lần, mục tiêu 2–4h** | ✅ RECALL + AUDIT_PACK ≤24h |
| VN: kết nối Cổng truy xuất quốc gia (qua đơn vị được chỉ định), TCVN 13274/13275 GS1-aligned | ➕ adapter Cổng quốc gia / iCheck / TraceVerified (đối tác) |
| Chứng nhận/claim theo lô hiện trên trang QR | ✅ SKU_PASSPORT |

## 8. BÁN HÀNG – POS – TMĐT – THANH TOÁN – HÓA ĐƠN (VN) — tham chiếu: Odoo POS, KiotViet, Sapo, Haravan, Shopee/TikTok Shop API, Zalo OA/ZNS, VNPay/MoMo/VietQR, MISA meInvoice / Viettel S-Invoice / VNPT Invoice; NĐ 123/2020, TT 78/2021, NĐ 70/2025

| Điểm đáng học | ITRAN OS |
|---|---|
| POS offline, loyalty, khuyến mãi, chế độ nhà hàng (bàn, bếp, tách bill, QR gọi món) | ✅ POS quầy + ➕ nhà hàng trại/resort |
| Trung tâm đơn đa kênh (Shopee, TikTok Shop, web, Zalo, quầy) map SKU, phân bổ tồn theo kênh | ➕ ORDER.source + connector marketplace (⏩ G4) |
| Đăng ký/định kỳ (giỏ nông sản tuần), đặt trước theo vụ, "nhận nuôi" | ✅ ADOPTION ➕ SUBSCRIPTION |
| E-invoice mỗi lần bán; NĐ 70/2025 hóa đơn máy tính tiền kết nối thuế; ký số qua nhà cung cấp | ➕ adapter e-invoice (meInvoice/S-Invoice/VNPT) — G4 |
| Thanh toán VNPay/MoMo/VietQR + đối soát sao kê (RC10); ZNS mẫu thông báo | ➕ PAYMENT gateway + ZNS |
| Giao hàng GHN/GHTK/Viettel Post | ⏩ |

## 9. RESORT / FARM-STAY / MICE — tham chiếu: Cloudbeds, Mews, Opera Cloud (OHIP), Little Hotelier, ezCloud (VN), QloApps; NPS: Qualtrics/QuestionPro/Formbricks

| Điểm đáng học | ITRAN OS |
|---|---|
| Đơn vị lưu trú (villa/lều/trải nghiệm), rate plan/mùa/ràng buộc, gói (ở + tour + bữa); vòng đời đặt phòng; đoàn/rooming list; folio + charge từ nhà hàng/quầy/tour; đặt cọc; city ledger | ✅ ROOM/RATE_PLAN/BOOKING ➕ folio, đoàn |
| Channel manager OTA (Booking/Agoda) qua ezCloud/SiteMinder — không tự làm | ⏩ mua channel manager, tích hợp API |
| Buồng phòng (sạch/bẩn/kiểm), bảo trì; self check-in khóa mã; đăng ký lưu trú công an (VN) | ✅ + ➕ xuất đăng ký lưu trú |
| MICE: lịch phòng họp, BEO/function sheet, khối phòng đoàn, cut-off, hóa đơn master | ➕ EVENT/BEO đơn giản |
| NPS/CSAT sau checkout qua ZNS/QR, webhook về CRM | ✅ NPS_SURVEY |
| Báo cáo occupancy/ADR/RevPAR, kênh | ➕ KPI resort |

## 10. NHÂN SỰ – KPI – LƯƠNG (VN) — tham chiếu: BambooHR, Lattice, Base.vn, MISA AMIS, 1Office, Odoo HR/Planning, ERPNext HRMS

| Điểm đáng học | ITRAN OS |
|---|---|
| Ca/kíp Gantt theo vai, chấm công GPS/QR, làm khoán theo sản phẩm (kg hái), OT/lễ | ✅ SHIFT + checklist ➕ chấm công QR/GPS, piece-rate cho thời vụ |
| Lương VN: BHXH/BHYT/BHTN (8%/1,5%/1% NLĐ; 17,5%/3%/1% NSDLĐ, trần), TNCN lũy tiến 5–35%, giảm trừ 15,5 tr + 6,2 tr/người phụ thuộc (2026), phiếu lương, file ngân hàng | ➕ engine luật lương VN có phiên bản (hoặc xuất MISA/1Office) |
| OKR/KPI cây công ty→phòng→cá nhân, check-in, 1:1, 360, review; pulse survey | ✅ KPI 4 lớp ➕ mục tiêu quý (khoán) dạng OKR nhẹ |
| Chứng chỉ có hạn (ATTP, sơ cứu, PPE ký nhận), LMS đọc-hiểu SOP | ✅ CERTIFICATE/TRAINING |

## 11. TÀI CHÍNH – KẾ TOÁN — tham chiếu: Odoo Accounting (analytic plans), ERPNext, MISA AMIS/ASP, SAP B1, BC

| Điểm đáng học | ITRAN OS |
|---|---|
| Phân tích đa chiều đồng thời (CC × chu kỳ vụ/lứa × sản phẩm × kênh) với % phân bổ | ✅ CC ➕ chiều "chu kỳ" (vụ/lứa/mẻ) |
| Giá thành chu kỳ sinh học (WIP tài sản sinh học), by-product/co-product, hao hụt chế biến, landed cost | ➕ chi phí theo chu kỳ, phân bổ đồng sản phẩm |
| Ngân sách vs thực, dòng tiền, TSCĐ khấu hao theo giờ máy | ✅ BUDGET ➕ khấu hao theo giờ máy |
| Sổ sách thuế giữ ở MISA; ERP đẩy chứng từ qua API/CSV | ✅ tích hợp MISA (G3–G4) |

## 12. RỦI RO – TUÂN THỦ – AUDIT — tham chiếu: Intelex, MasterControl, LogicGate, isoTracker, SafetyCulture, OCA mgmtsystem; stage-gate tools

| Điểm đáng học | ITRAN OS |
|---|---|
| Sổ rủi ro (khả năng × mức độ, chủ, kiểm soát, rủi ro dư, chu kỳ rà); thư viện kiểm soát map chuẩn (ISO 9001/22000, VietGAP, GAP, NĐ) + bằng chứng | ✅ 19 rủi ro ➕ ma trận L×S, control ↔ STANDARD_CLAUSE |
| Sự cố/near-miss mobile ảnh → điều tra 5-Why/fishbone → CAPA hiệu quả | ✅ |
| Chương trình audit nội bộ theo điều khoản, phát hiện major/minor, CAPA, xem xét lãnh đạo | ✅ AUDIT_INTERNAL |
| Lịch nghĩa vụ pháp lý (giấy phép, báo cáo môi trường, PCCC) | ➕ OBLIGATION calendar |
| Stage-gate: cổng có tiêu chí chấm tự động, quyết định Go/Kill/Hold có log | ✅ GATE C1–C4 + Hồ sơ module 5 bước |

## 13. TỔNG HỢP: NHỮNG GÌ THÊM VÀO SO VỚI BỘ GỐC (để "thừa chứ không thiếu")
1. **Least-cost formulation** cho D5 (LP) — bộ gốc chỉ có RECIPE tĩnh.
2. **Crush mode** cân + EID + phân loại tại cũi; **tủ thuốc quét mã vạch**.
3. **KPI ngành mở rộng:** 21-day PR, days open; hen-housed, egg mass, EPEF; SGR, TGC, sinh khối ước, định giá tài sản sinh học.
4. **HACCP plan builder + QC point tự sinh + SPC**; trạng thái lô cách ly; dual UoM; bin/vị trí ảo.
5. **Sentinel-2 NDVI tự động + cảnh báo bất thường; thời tiết/GDD/ET0/ẩm đất; work order + xếp lịch máy; tracker GPS máy tự tách việc theo lô.**
6. **EPCIS 2.0 + GS1 Digital Link resolver riêng; adapter Cổng truy xuất quốc gia (TT 02/2024) & Thông tư 66/2025 chăn nuôi; e-invoice NĐ 70/2025; VNPay/MoMo/ZNS; marketplace connector.**
7. **PMS đầy đủ hơn:** folio, đoàn, BEO/MICE, đăng ký lưu trú, KPI khách sạn; NPS qua ZNS.
8. **Payroll VN engine có phiên bản**; chấm công GPS/QR; piece-rate thời vụ.
9. **Kế toán đa chiều theo chu kỳ vụ/lứa/mẻ**; khấu hao theo giờ máy; landed cost.
10. **OBLIGATION calendar; ma trận L×S; control ↔ điều khoản chuẩn.**
11. **Đọc-hiểu SOP bắt buộc khi đổi bản; template checklist có logic/điểm/ảnh.**
12. **Benchmark liên trại (HQ)** kiểu FBN/Porphyrio.

## 14. CHUẨN ÁP DỤNG (quyết định)
| Chuẩn | Dùng cho | Quyết định |
|---|---|---|
| ISO 11784/11785 (FDX-B/HDX) | RFID tai bò/dê | ✅ bắt buộc; đầu đọc BLE (Agrident/Allflex/Gallagher) — **NFC điện thoại không đọc được 134,2 kHz** |
| ICAR ADE | trao đổi dữ liệu vật nuôi | ⏩ export khi cần |
| GS1 GTIN/GLN/SSCC, EPCIS 2.0 + CBV, Digital Link | SKU, địa điểm, lô, truy xuất, QR | ✅ từ G2 |
| TCVN 12850:2019 · NĐ 13/2022 · TT 02/2024/TT-BKHCN · TCVN 13274/13275:2020 | truy xuất VN | ✅ mô hình dữ liệu tương thích; kết nối cổng ở G4 |
| Thông tư 66/2025/TT-BNNMT | hồ sơ chăn nuôi | ✅ báo cáo xuất theo mẫu |
| GlobalG.A.P IFA v6 Smart · VietGAP TCVN 11892-1:2017 · HACCP/ISO 22000 · ISO 9001 · Halal | tuân thủ | ✅ STANDARD_CLAUSE seed; khóa backdate |
| ISOXML/ADAPT | máy nông nghiệp | ⏩ import/export khi có máy ISOBUS |
| OGC SensorThings (mô hình), MQTT 5, Sparkplug B (gateway PLC), LoRaWAN | IoT | ✅ |
| ISO 8601/RFC 3339, GeoJSON/EPSG:4326, OpenAPI 3.1, OIDC/OAuth2 PKCE, WCAG 2.2 AA | nền | ✅ |
| NĐ 123/2020 + TT 78/2021 + NĐ 70/2025 | hóa đơn điện tử | ✅ qua nhà cung cấp (G4) |
| ISO/IEC 27001 (kiểm soát), ISO 25010 (chất lượng) | bảo mật/chất lượng | ✅ file 08 |
