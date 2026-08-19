# 13 · PHÒNG BAN – QUY TRÌNH A–Z – ĐỐI TƯỢNG – EVENT BUS (đã triển khai thành DỮ LIỆU trong ITRAN AGRI)

> Nguồn sự thật là **cơ sở dữ liệu** (bảng `departments`, `processes`, `process_steps`, `event_topics`, `records_catalog`, `roles_catalog`, `positions_catalog`, `species`, `animal_classes`, `crops`, `product_kinds`) — xem/sửa tại `/to-chuc`, `/doi-tuong`, `/quan-tri`. File này là bản chụp để đọc nhanh (migration 0020–0023).
> Tham khảo cấu trúc thực tế: TH true MILK/Vinamilk (chuỗi trang trại – nhà máy – phân phối), Vinamit/Organik (hữu cơ + xuất khẩu), HAGL Agrico (đa trại, đa quốc gia), khung GlobalG.A.P. IFA, IFOAM/EU 2018/848, ISO 22000/HACCP, SCOR (chuỗi cung ứng), FAO về tổ chức chứng nhận hữu cơ.

## 1. Vì sao phải định nghĩa ĐỐI TƯỢNG trước
Mọi số liệu (sản xuất, tồn kho, tài chính, KPI) đều "treo" vào 4 nhóm đối tượng gốc; định nghĩa xong mới sinh phòng ban, quy trình, biểu mẫu, dashboard đúng.

| Đối tượng | Định nghĩa (bảng) | Thực thể (bảng) | Số liệu treo vào |
|---|---|---|---|
| **Con người** | `roles_catalog` (9 vai: owner, director, tech_head, team_lead, worker, accountant, it_engineer, auditor, customer) · `positions_catalog` (A1–A14) · `departments` (17) | `staff` (dept, position_code, farm_ids) | bản ghi (created_by), việc, KPI→lương, chứng chỉ, ca |
| **Vật nuôi** | `species` (14 loài, mức định danh CA_THE/LO/DAN, chu kỳ, SKU đầu ra) · `animal_classes` (bê/tơ/cái SS/vỗ béo/đực…; gà hậu bị/đẻ/thịt; cá giống/thịt) | `animals` (cá thể), `intake_lots` (lô), `animal_groups` (đàn) | animal_events, feed_logs, herd_daily, sổ đàn K8, giá trị đàn |
| **Cây trồng** | `crops` (31 loại: SINH_KHOI / LUONG_THUC / RAU / CU / QUA / CAY_CONG_NGHIEP / DUOC_LIEU / NAM / CAY_VIEN / HOA; vòng đời NGAN_NGAY / LAU_NAM / LUU_GOC; chu kỳ, lứa/năm, năng suất chuẩn, giống, SKU đầu ra) | `plots` (ô thửa, crop_code), `crop_seasons` (mùa vụ = hồ sơ canh tác) | crop_logs, crop_inputs (PHI), harvests, lab_samples |
| **Sản phẩm / vật tư** | `product_kinds` (13 nhóm theo dòng ĐẦU VÀO → TRUNG GIAN → ĐẦU RA, kho mặc định) | `products` (SKU), `lots` | inventory_moves, stock_daily, sales, giá vốn |
| Trại / hạ tầng | `farms` (hồ sơ chi tiết) · `facilities` (nhà công năng) · `locations` · `warehouses` | — | mọi bảng có farm_id |

Màn hình: `/doi-tuong` (4 tab: con người · vật nuôi · cây trồng · sản phẩm) — số lượng đang có + định nghĩa; `/xem/{type}/{id}` = trang 360 của **bất kỳ đối tượng** (gõ tên vào ô 🔍 ở header → thuộc tính + biểu đồ + bản ghi gốc).

## 2. 17 phòng ban (khối · nhiệm vụ cốt lõi · KPI · hồ sơ)
| Khối | Mã | Phòng ban | Nhiệm vụ 1 dòng | KPI chính |
|---|---|---|---|---|
| Điều hành | HDQT | HĐQT/Chủ đầu tư | chiến lược, vốn, duyệt >50tr, giám sát 3 lớp | ROI, EBITDA, cảnh báo ĐỎ mở |
| | BGD | Ban GĐ điều hành (cty mẹ) | điều phối liên trại, KH năm/quý, chi 20–50tr | P&L phân hệ, đúng KH mùa vụ |
| | GDT | GĐ trại (mỗi trại) | vận hành, chi <20tr, giao ca, duyệt điều chỉnh | sản lượng vs KH, chi phí/ngày |
| Sản xuất | KTCN | KT chăn nuôi & thú y | sổ đàn, sinh sản, thú y, khẩu phần, ATSH | đậu thai, ADG, chết %, ngưng thuốc=0 |
| | TT | Trồng trọt – sinh khối – vườn | KH mùa vụ theo K, nhật ký canh tác, PHI, thu hoạch, chứng nhận | ngày-tồn ủ chua, kg/ha, PHI=0 |
| | SH | Sinh học tuần hoàn – môi trường | trùn/BSF/biogas/compost, quan trắc, giấy phép MT | tái sử dụng %, sự cố=0 |
| | D5 | Xưởng TA – chế biến | TMR đúng công thức, HACCP, kho lạnh, truy xuất | sai số mẻ, CCP=0, giá thành |
| Chuỗi cung ứng | CCU | Kho – mua hàng – vận tải – cổng | MRP, PO, NCC ≤35%, 9 kho FEFO, kiểm kê, cân | ngày-tồn, hết hàng=0, chênh ≤1% |
| Kinh doanh | KDM | Kinh doanh – marketing – CSKH | CRM, đơn/HĐ, POS, online, nhận nuôi, KM | doanh thu/kênh, biên, nợ >30 ngày |
| | XNK | Xuất nhập khẩu | thị trường, HĐ ngoại/LC, chứng từ, hải quan, thanh toán QT, giấy phép nhập | giá trị XK, chứng từ lỗi=0 |
| | DL | Du lịch – lưu trú – ẩm thực – sự kiện | booking, tour, F&B, tiệc/MICE, folio | công suất, ADR/RevPAR, biên F&B |
| Hỗ trợ | TCKT | Tài chính – kế toán | chi 2 chữ ký, P&L CC, ngân hàng, thuế, quỹ | đối chiếu 100%, đúng hạn |
| | HCNS | Hành chính – nhân sự – đào tạo | tuyển, ca, KPI→lương, SOP, khám SK/ATTP | KPI TB, nghỉ việc, chứng chỉ đủ |
| | CNTB | Công nghệ – thiết bị – IoT – dữ liệu | bảo trì, hiệu chuẩn, IoT, ITRAN AGRI, tích hợp, sao lưu | uptime, cảm biến off, job OK |
| | QA | Chất lượng – tuân thủ – chứng nhận | SOP, audit nội bộ, RC1–RC16, chứng nhận, truy xuất/thu hồi | điểm audit, NC mở, lệch % |
| Chiến lược | RD | R&D – đổi mới – tri thức | thử nghiệm có đối chứng, mẫu lab, SOP mới, chuyển giao | đề tài xong, cải thiện % |
| | MR | Phát triển dự án – nhân rộng – franchise | khảo sát, thế số Lớp B, thiết kế, create_farm, chuyển giao | trại mới/năm, đúng tiến độ |

Nhân sự gán vào phòng qua `staff.dept` (đã map A1–A11 → phòng); trưởng phòng = `head_role`.

## 3. Kiểm kê QUY TRÌNH nghiệp vụ theo đối tượng × vòng đời (65 quy trình, `processes`)
| Đối tượng | Số QT | Đã có (bảng+UI+form) | Một phần | Ví dụ mã |
|---|---|---|---|---|
| Vật nuôi | 14 | 13 | 1 (sữa) | P-KT-01…04, P-VN-01…10 |
| Cây trồng | 10 | 8 | 2 (đất–nước lab, nấm/nhà màng) | P-TT-01…03, P-CT-01…07 |
| Sản xuất/chế biến | 8 | 6 | 2 (chế biến sâu, MT quý) | P-D5-01/02, P-SH-01/02, P-SX-01…04 |
| Vật tư/kho | 6 | 6 | — | P-CCU-01…03, P-KHO-01…03 |
| Khách hàng (bán/DL/XNK) | 9 | 7 | 2 (XNK) | P-KD-01…04, P-DL-01…03, P-XNK-01/02 |
| Con người | 5 | 5 | — | P-HC-01, P-NS-01…04 |
| Tài chính | 4 | 4 | — | P-TC-01…04 |
| Thiết bị/dữ liệu | 3 | 3 | — | P-CN-01/02, P-TB-01 |
| Chất lượng | 2 | 1 | 1 (chứng nhận) | P-QA-01/02 |
| R&D · Trại · Quản trị | 4 | 3 | 1 | P-RD-01, P-MR-01, P-QT-01/02 |

Mỗi quy trình có: kích hoạt · **đầu vào** (từ phòng nào, qua bảng/view/topic nào) · **đầu ra** (đến phòng nào) · SLA · KPI · bảng dữ liệu · màn hình · form 3 chạm. Bước chi tiết A→Z (`process_steps`: bộ phận, vai, làm gì, ở đâu, kiểm soát, **công cụ**, **vật tư**, đầu vào/ra, biểu mẫu, SLA) đã mô tả cho các quy trình lõi (P-TT-02 hồ sơ canh tác 7 bước, P-KD-02 đơn hàng 5 bước, P-DL-01 lưu trú 4 bước, P-XNK-01 xuất khẩu 6 bước); các quy trình còn lại **khai báo bước ngay trong app** (`/to-chuc` › Khai báo quy trình) không cần lập trình.

## 4. Công cụ KHAI BÁO & CHẠY quy trình (workflow engine, migration 0023)
- Khai báo quy trình (mã, phòng chủ trì, đối tượng, kích hoạt, tự chạy theo sự kiện, SLA, KPI) → **thêm/xóa/sắp xếp bước**; mỗi bước: bộ phận, vai nhận việc, công cụ/thiết bị, vật tư (SKU–SL–ĐV), đầu vào, đầu ra, biểu mẫu phải ghi, SLA, nhóm song song, bắt buộc/không.
- **Xuất bản** → `publish_process()` → sự kiện `process.published` → thông báo mọi nhân sự thuộc các phòng/vai trong bước ("bạn được đưa vào quy trình này") + phiên bản v+1 khi phát hành lại.
- **Chạy** → `start_process_run()` → sinh việc (`tasks` kind QUY_TRINH) cho bước 1, mang theo công cụ/vật tư/đầu vào/đầu ra; người thuộc bộ phận + vai nhận thông báo; **✓ xong** → `complete_run_step()` → bước kế tự kích hoạt (song song chờ đủ) → `process.finished`. Có thể tự chạy khi có sự kiện (auto_start.topic, ví dụ `harvest.done`).

## 5. Ma trận đầu vào ↔ đầu ra & Event bus
- `v_dept_io` sinh từ inputs/outputs của 65 quy trình → ma trận 17×17 (`/to-chuc` › Đầu vào ↔ đầu ra). Mỗi ô là 1 bảng/view/export cụ thể → phòng nhận **thấy ngay** số liệu, không phải đi hỏi.
- `event_topics` (16 chủ đề, đã nối trigger): alert.raised, task.created (kèm dept), incident.created, expense.approved.big, farm.created, customer.message, master.changed, import.done, animal.intake, harvest.done, po.created, order.created, booking.created, shipment.status, period.locked, process.published/finished. Luồng: bảng → trigger `publish_event()` → `event_bus` → dispatch → `notifications` theo luật & sở thích (app/Zalo/SMS) → webhook.
- Mọi bảng đều **xuất/nhập CSV** (`/quan-tri`, `/api/admin/*`, `/api/import/csv`) và có **lịch sử thêm/sửa/gỡ gửi admin** (`audit_log` + `master.changed`).

## 6. Danh mục HỒ SƠ (records_catalog, 20 hồ sơ)
Canh tác (Nhật ký sản xuất VietGAP/hữu cơ/GlobalG.A.P.), thu hoạch, đất–nước, sổ đàn, thú y, thức ăn, ATTP/HACCP, kho, truy xuất, môi trường, thiết bị, nhân sự, bán hàng, kế toán, XNK, pháp lý, R&D, du lịch, nhận nuôi, gói audit — mỗi hồ sơ = bảng nguồn + `export_kind` + căn cứ pháp lý + thời gian lưu + phòng phụ trách.

## 7. Phần mềm BÁN HÀNG & DU LỊCH (đã có, migration 0018)
- Bán hàng: đơn/HĐ/công nợ (cũ) + **CRM pipeline** (crm_leads → đối tác), **POS cửa hàng** (ca, hóa đơn → sales tự sinh), **khuyến mãi**, **9 kênh bán** (`sales_channels`), nhận nuôi/portal.
- Du lịch: hạng phòng/phòng (sơ đồ trạng thái), **booking** (giữ chỗ → xác nhận → nhận → folio → trả → việc dọn phòng tự sinh), **tiệc/MICE** (báo giá → cọc → chuẩn bị menu×pax → quyết toán), **tour** (lịch, bán vé), dịch vụ & thực đơn farm-to-table gắn SKU, KPI công suất/ADR/RevPAR; mọi thanh toán → `sales` kênh RESORT.
