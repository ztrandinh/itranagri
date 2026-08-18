# 12 · DASHBOARD THEO BỘ PHẬN · KIỂM KÊ DỮ LIỆU ĐẦU VÀO · TỰ TÍNH · MÃ NGUỒN MỞ
*Trả lời 3 câu: (A) mỗi bộ phận nhìn gì mỗi sáng và có gì trong app; (B) hệ có bao nhiêu loại dữ liệu đầu vào (cảm biến / ghi chép / tự sinh) và bao nhiêu chỉ số tự tính; (C) mã nguồn mở nào dùng được. Ký hiệu: ✅ đã có trong app · 🔧 đang/đợt tới · 📅 kế hoạch.*

## A. DASHBOARD THEO BỘ PHẬN — "mỗi sáng nhìn 8 ô, mỗi ô bấm xuống được bản ghi"

### A1. Quản lý VÙNG NUÔI TRỒNG (KTT chăn nuôi + KTT sinh học/trồng trọt) — trang `/ktt` + `/dan` tầng + `/so-lieu`
| Ô | Nội dung | Nguồn | TT |
|---|---|---|---|
| Đỏ đêm qua theo khu | alerts ĐỎ/CAM chưa ack, gom theo khu | alerts, locations | ✅ (gom theo luật; theo khu 🔧) |
| Con/đàn cần chú ý | bệnh, cách ly, ngưng thuốc, chờ tai, có việc — theo khu | v_location_summary | ✅ |
| Việc đến hạn theo đội | khám thai/phối/cai sữa/vaccine/bảo dưỡng | tasks | ✅ |
| Sinh sản 30 ngày | đậu thai %, động dục phát hiện, đẻ, khoảng cách lứa | v_kpi_*, v_animal_parity | ✅ |
| Cho ăn hôm nay | mẻ đã ghi / KH, sai số, thừa máng, thiếu ảnh | feed_logs | ✅ |
| Cỏ – bắp – ủ chua | ngày-tồn ủ, cắt tuần này vs KH, năng suất lô | v_days_silage, agg harvest | ✅ (KH vụ 🔧 season_plan) |
| Khu D | tấn nạp tuần, phân trùn ra, NH₃ (khi có sensor), RC4 | batch_logs, recon | ✅ |
| Gà/RAS | đẻ %, chết, DO min đêm, FCR đợt | v_kpi_lay_rate, sensor, cycles | ✅ |
| Bản đồ khu (sơ đồ ô/chuồng tô màu) | trạng thái từng ô/bể/luống | locations + attention | 📅 (SVG sơ đồ) |
| Vùng: so trại cùng vùng | KPI chuẩn hóa theo vùng | hq_kpis + regions | ✅ (so trại) · 📅 (chuẩn hóa) |

### A2. Quản lý KHO GIỐNG · LƯƠNG THỰC (thức ăn) · THỰC PHẨM (thành phẩm/kho lạnh) — `/kho` tầng
| Ô | Nội dung | TT |
|---|---|---|
| Ngày-tồn theo mặt hàng (K2/K3/K4): ≥60/45/30 | v_days_of_stock | ✅ |
| FEFO đỏ, lô cách ly/thu hồi | v_fefo_red, lots.status | ✅ |
| Kho lạnh K6: nhiệt 24h, mở cửa quá 5' | sensor TEMP_COLD | ✅ (sensor) · 📅 (cửa) |
| Kho giống K1: tinh (liều), vaccine (hạn), giống cây (lô, nảy mầm) | lots + products kind GIONG | ✅ (bảng) · 🔧 (form phối trừ tinh) |
| Kiểm kê đến hạn, chênh, điều chỉnh chờ duyệt | tasks KIEM_KE, stocktakes, adjustments | ✅ |
| Nhập không PO, NCC hết hạn phê duyệt/COA | governance, partners | ✅/🔧 |
| Sổ đàn K8 giá trị (tài sản sinh học) | v_herd_value, herd_daily | ✅ |
| Tồn tại ngày bất kỳ (đối chiếu kế toán) | stock_daily | ✅ (bảng) · 🔧 (màn tra ngày) |
| Dự báo hết hàng 14/30 ngày | ngày-tồn + KH tiêu thụ | 🔧 |

### A3. VẬT TƯ – MÁY MÓC – CÔNG NGHỆ (KS công nghệ + xưởng cơ khí + A5)
| Ô | Nội dung | TT |
|---|---|---|
| Máy: giờ máy, đến hạn bảo dưỡng, hỏng chờ sửa (%), nhiên liệu/giờ vs định mức (RC7) | devices, crop_logs, tasks | ✅ |
| Thiết bị IoT: online/offline, pin, hiệu chuẩn đến hạn | devices, calibrations, sensor heartbeat | ✅ bảng · 🔧 heartbeat từ sensor_reads |
| Vật tư tiêu hao (dầu, phụ tùng, PPE, tem) tồn & tiêu thụ | K7/K9/K1 | ✅ |
| Uptime hệ thống, backup đêm, hàng đợi offline lỗi, phiếu giấy trễ | jobs log, paper_scans | 🔧 (job log table) |
| Sự cố thiết bị (INCIDENT kind THIET_BI) + 5-Why | incidents | ✅ |
| Dịch vụ máy cho ngoài (doanh thu CC-TT) | sales channel 5 / cost center | 📅 |
| Điện – nước theo khu vs định mức (RC13/14) | sensor điện/nước | 📅 (khi có đồng hồ) |

### A4. BÁN HÀNG – MARKETING (A9 + KD)
| Ô | Nội dung | TT |
|---|---|---|
| Doanh thu ngày/tuần/tháng theo kênh 1–5, ≤40%/kênh | sales, agg | ✅ |
| Đơn hôm nay & lệnh SX (chốt ≤15h) | orders (🔧 bảng orders), sales | 🔧 |
| Công nợ theo tuổi (0–15/16–30/>30), khách bị ngừng giao | v_receivable_aging | ✅ |
| % sản lượng có hợp đồng trước (≥70%) | contracts (🔧 bảng) | 🔧 |
| Giá bán vs giá sàn (bán dưới sàn cần duyệt) | price_list SAN | ✅ |
| Khách quay lại ≥25%, khách mới, nhận nuôi (MRR, gia hạn) | sales partner history, custody (📅) | 🔧/📅 |
| Tồn thành phẩm bán được (K5/K6) + hạn | stock | ✅ |
| Truy xuất/QR quét (lượt, sản phẩm nào được quan tâm) | public trace log | 📅 |
| Marketing: chi 3–5% DT, chiến dịch, kênh dẫn về (UTM) | expense CC-KD, campaigns (📅) | 📅 |
| NPS resort/khách | nps (📅 resort) | 📅 |

### A5. KẾ TOÁN (thuê ngoài/nội bộ)
| Ô | Nội dung | TT |
|---|---|---|
| Bảng kê bán/mua tháng (CSV) → MISA | exports sales-tax/purchases | ✅ |
| Đối soát tiền RC10 (SALE vs sao kê) | recon (cần import sao kê 🔧) | 🔧 |
| Đề nghị chi: chờ ký, quá hạn mức, thiếu chữ ký 2 | expense_requests | ✅ |
| Khóa kỳ (sau ngày 5 không ghi lùi) | period_locks | ✅ |
| Tồn kho & sổ đàn cuối kỳ (giá trị) | stock_daily/herd_daily | ✅ (bảng) 🔧 (báo cáo kỳ) |
| Giá thành theo CC / chu kỳ (P&L phân hệ ngày 5) | cost allocation | 📅 (Đợt D) |
| Quỹ tự trích (thiên tai 3%, BD 5%, đào tạo 1%) | funds | 📅 |
| Nợ dịch vụ nhận nuôi (thu trước 30% đối ứng) | custody | 📅 |

### A6. Những bộ phận bạn chưa nghĩ tới (nên có ô riêng)
| Bộ phận | Ô chính | TT |
|---|---|---|
| **An toàn – cổng – an ninh (A11)** | xe không cân/không anolyte, tuần tra đủ điểm, sự cố an ninh, danh sách xe hôm nay | ✅ gate_logs (rule AL-GATE 🔧) |
| **Thú y (hợp đồng)** | con đang điều trị, ngưng thuốc sắp hết, vaccine đến hạn, xét nghiệm 2 lần/năm, thuốc K1 sắp hết/hạn | ✅ dữ liệu · 🔧 màn riêng |
| **Nhân sự – đào tạo** | chứng chỉ SOP còn thiếu/hết hạn, khám SK, ATTP, checklist xanh %/người, sổ giao ca | 🔧 |
| **Chất lượng – tuân thủ (thư ký chất lượng)** | SOP quá hạn rà, CCP vi phạm, mock recall kỳ, hồ sơ audit sẵn sàng, phiếu giấy trễ | ✅ một phần (/suc-khoe) |
| **Môi trường – tuần hoàn** | 6 dòng cân bằng vật chất, phân xử lý/sinh ra, NH₃, nước tưới lại, zero xả | ✅ 6 dòng · 📅 sensor |
| **Chủ đầu tư / HQ** | so trại, cổng chặn, đỏ, tiền, việc quá hạn, giấy chưa số hóa | ✅ /hq |
| **Khách nhận nuôi (portal)** | con của tôi, ảnh, cân, sự kiện, live giờ | 📅 M21 |
| **R&D** | khảo nghiệm đang chạy, kết quả, pilot module | 📅 M19 |
| **XNK** | lô hàng, chứng từ thiếu, hạn cắt máng | 📅 M20 |

## B. KIỂM KÊ DỮ LIỆU ĐẦU VÀO — có bao nhiêu loại, cái gì tự tính

### B1. Đầu vào NGƯỜI GHI (app 3 chạm / giấy) — 13 bảng sự kiện, ~45 loại bản ghi
| Bảng | Loại bản ghi (event_type / lý do) | Số loại |
|---|---|---|
| animal_events | NHAP, CACH_LY_VAO/RA, DONG_DUC, PHOI, KHAM_THAI, DE, CAI_SUA, PHAN_LOAI, CAN, BENH, DIEU_TRI, VACCINE, CHUYEN, CHET, LOAI, XUAT, SO_LUONG (trứng đếm/đầu con/sinh khối), GHI_CHU | 19 |
| feed_logs | mẻ TMR / viên / RAS theo cữ | 1 (× cữ) |
| crop_logs | LAM_DAT, GIEO, BON, PHUN, TUOI, CAT, THU, GIEO_LAI, NDVI | 9 |
| batch_logs | D5_TMR, D5_VIEN, U_CHUA, TRUN_NAP, TRUN_THU, BSF, BIOGAS, COMPOST, IMO_EM, ANOLYTE, SO_CHE, SAY, DONG_GOI, EP_MO_CAU, THAN | 15 |
| inventory_moves | NHAP_MUA/SX, XUAT_SX/CHO_AN/BAN, CHUYEN, TRA, HUY, DIEU_CHINH | 9 |
| sales / orders | bán theo kênh, thanh toán | 1 |
| checklist_runs, incidents, stocktakes, adjustments, gate_logs, weigh_tickets, paper_scans, shift_notes | mỗi bảng 1 loại | 8 |
| tasks (xong/treo), purchase_orders, expense_requests, cycles | quản lý | 4 |
**Tổng ~66 loại bản ghi người ghi**, tất cả đều có form 3 chạm hoặc màn quản lý.

### B2. Đầu vào CẢM BIẾN / THIẾT BỊ (`sensor_reads.metric` + thiết bị ghi thẳng bảng sự kiện)
| Nhóm | Metric | Thiết bị | Vào bảng | TT |
|---|---|---|---|---|
| Nước RAS/ao | DO, pH, TEMP_WATER, NH3_N, NO2, SALINITY | đầu dò | sensor_reads | ✅ schema (giả lập) |
| Chuồng | TEMP, RH, NH3, CO2, LUX | cảm biến chuồng | sensor_reads | ✅ schema |
| Kho lạnh | TEMP_COLD, DOOR_OPEN | cảm biến | sensor_reads | ✅ (temp) |
| Môi trường | RAIN, WIND, RIVER_LEVEL, SOIL_MOISTURE, SOLAR | trạm thời tiết/LoRa | sensor_reads | 📅 |
| Điện/nước | KWH, M3 theo khu | đồng hồ Modbus/pulse | sensor_reads | 📅 |
| Silo/cám | SILO_KG | loadcell/3D | sensor_reads → feed_logs xác nhận | 📅 |
| Cân | cân cầu, cân cổng, cân lối đi, cân xe trộn | RS-232/BLE | weigh_tickets / animal_events CAN / feed_logs | 📅 driver (nhập tay ✅) |
| RFID | quét tai | BLE reader | chọn đối tượng | 📅 (gõ/QR ✅) |
| Vòng cổ bò | RUMINATION, ACTIVITY, TEMP_BODY, HEAT_SCORE, GEOFENCE | API hãng | sensor_reads → alert | 📅 |
| Camera | COUNT, PLATE, PPE, TROUGH_LEFTOVER | edge AI | animal_events SO_LUONG / gate_logs | 📅 |
| Máy | GPS, ENGINE_HOURS, FUEL | tracker | crop_logs/devices | 📅 |
**~30 metric cảm biến** — schema đã sẵn (metric text tự do + partition tháng), driver là việc Ray B.

### B3. Cái gì HỆ TỰ TÍNH (không ai nhập) — 100+ đại lượng
- **View/KPI**: tồn kho từng lô, giá vốn BQ, ngày-tồn từng mặt hàng, sổ đàn K8 & giá trị, đậu thai %, bê/nái, khoảng cách lứa, số lứa, ADG/cân TB, sai số mẻ, đẻ %, chết %, cân bằng vật chất 6 dòng, FEFO đỏ, tuổi nợ, % kênh, doanh thu, số việc quá hạn, % nhập bù, phân bố giờ ghi… (**~40 chỉ số** trong `queries.ts` + 28 chỉ số explorer).
- **Engine**: RC1–RC12 (12 phép đối soát mỗi đêm), ~15 luật alert, task generator (8 loại việc tự sinh), agg_daily (22 metric × chiều), stock_daily/herd_daily snapshot, audit anchor hash, cycle summary.
- **Suy diễn từ sự kiện**: trạng thái vòng đời con vật, ngưng thuốc, head_count đàn, chu kỳ, lô tự tạo, mã tự sinh.
→ Kết luận: **hệ đã tự tính được**; phần cần thêm là **KH/định mức đầy đủ (season_plan, feed_plan) để có "kế hoạch vs thực"** và **cost allocation** cho giá thành. Bộ gốc có công thức; đưa vào bảng `norms`/`plans` là xong.

## C. MÃ NGUỒN MỞ HỖ TRỢ (đã dùng / có thể ghép)
| Nhu cầu | Mã nguồn mở | Giấy phép | Dùng thế nào |
|---|---|---|---|
| CSDL, thời gian, không gian | PostgreSQL 17 · (TimescaleDB · PostGIS ở Ray B) | PostgreSQL / TSL / GPL | ✅ đang dùng PG; partition tháng thay Timescale |
| Nền app | Next.js · React · Tailwind · Recharts · Zod · pg | MIT | ✅ |
| Supabase (Auth/Storage/RLS/cron) | Supabase (Apache-2), PostgREST | Apache-2 | 📅 khi lên cloud |
| IoT | Mosquitto (MQTT), ChirpStack (LoRaWAN), Node-RED, ThingsBoard CE | EPL/MIT/Apache | 📅 Ray B |
| Truy xuất | OpenEPCIS (Apache-2), GS1 Digital Link Resolver CE, bwip-js, gs1-syntax-engine | Apache/MIT | ✅ EPCIS JSON-LD xuất; resolver 📅 |
| Phối trộn least-cost | HiGHS / OR-Tools (LP) | MIT/Apache | 📅 M5 (sau 60 ngày D5) |
| Dự báo | Nixtla statsforecast/mlforecast, LightGBM | Apache/MIT | 📅 |
| Camera AI | RF-DETR / RT-DETR, MegaDetector, ONNX Runtime | Apache/MIT | 📅 (tránh YOLO AGPL) |
| Chuẩn dữ liệu vật nuôi | ICAR ADE (JSON schema, Apache-2) | Apache-2 | 📅 xuất khi cần |
| ERP tham chiếu (không nhúng) | Odoo CE (LGPL), ERPNext (GPL) — dùng làm mẫu quy trình kho/MRP/HR, không tích hợp trực tiếp | | tham khảo |
| PDF/báo cáo | Typst, Gotenberg, pdfme | Apache/MIT | 📅 |
| Observability | OpenTelemetry, Grafana/Loki | Apache/AGPL(nội bộ) | 📅 |
| Không có OSS tốt | HACCP eQMS, GRC, e-invoice VN, cổng truy xuất quốc gia → tự xây/mua dịch vụ | | |
