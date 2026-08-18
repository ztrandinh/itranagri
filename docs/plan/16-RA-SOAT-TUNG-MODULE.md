# 16 · RÀ SOÁT TỪNG MÔ-ĐUN THEO KHUNG "CÓ GÌ · ĐÚNG CHƯA · THỰC TẾ PHẢI THẾ NÀO / CHO AI / ĐỂ LÀM GÌ · SỬA" — 19/08/2026

Cùng khung đã dùng cho **Kế hoạch** (đã làm xong ở commit ef6c549: giả định tự tính → S&OP 12 tháng → đàn theo lứa/lịch vụ → ban hành việc → KH–TT). Ký hiệu: ✅ đã đạt · 🔧 sửa trong đợt này (0086 + patch38) · ⏳ tồn, có kế hoạch · ❓ cần anh chốt nghiệp vụ.

| # | Mô-đun (trang) | Đang có | Đánh giá | Thực tế phải thế nào — cho ai — để làm gì | Đợt này |
|---|---|---|---|---|---|
| 1 | **Đàn** `/dan` | cá thể/thẻ RFID, vòng theo dõi, nhập lô, nhóm, chu kỳ, phả hệ, 360 | Ghi & tra tốt; **thiếu "hôm nay phải làm gì với con nào"** | KTT/CN A2 cần *lịch sinh sản tự suy* (phối→khám thai 60 ngày→chuẩn bị đẻ→tái phối), cai sữa, cân đến hạn, vỗ béo đủ ngày xuất, loại thải đề xuất, đang ngưng thuốc — thành việc trong Ca | 🔧 `v_herd_actions` + `gen_herd_actions` (job đêm) + tab **📋 Việc đàn** (F01: 8 chuẩn bị đẻ, 4 khám thai, 61 tái phối, 30 xuất vỗ béo…) |
| 2 | **Canh tác** `/canh-tac` | mùa vụ, vật tư PHI, thu hoạch (tự nhập kho), thời tiết/ET0/tưới, đất/IPM, luân canh, liên kết hộ | Đủ ghi chép; **thiếu tiền**: không biết ô nào lãi/lỗ, đ/kg cỏ | KTT TT & chủ: *giá thành theo ô/vụ* (vật tư+máy+tưới+công ÷ sản lượng) để chọn giống/ô/cách làm; lịch chăm sóc theo giai đoạn cây | 🔧 `v_plot_cost` + tab **💰 Giá thành ô** (đơn giá ở settings) · ⏳ lịch chăm sóc theo BBCH |
| 3 | **Chế biến/D5** `/che-bien` | KHSX tuần, MRP, BOM đa cấp, mẻ+CCP, bao bì, nhãn, tem QR | Đủ; thiếu **hiệu suất mẻ vs BOM** và **giữ lô QC không đạt** | Tổ trưởng D5/QA: mỗi mẻ so BOM chuẩn (hao hụt %), lô không đạt → HOLD không được xuất; giá thành mẻ đã có (v_batch_cost) | ⏳ yield variance + HOLD lô (1 phiên nhỏ) |
| 4 | **Kho – Mua** `/kho /du-tru /mua-hang` | bin, ROP/ABC, kiểm kê chu kỳ, kho lạnh, vận tải, scorecard NCC, thẻ kho, dự trữ 3 khối, PO→nhận | Mạnh; thiếu **giá trị tồn** cho kế toán và **trả hàng NCC** | Kế toán/GĐ: giá trị tồn theo kho/nhóm (số dư TK 152/155 đối chiếu GL); thủ kho: phiếu trả NCC | 🔧 `v_stock_value` + tab **💰 Giá trị tồn** · ⏳ trả NCC |
| 5 | **Bán hàng** `/ban-hang` | 12 tab: bán/đơn/trả/báo giá/giá/HĐ/lịch giao/nhận nuôi/CRM/điểm/công nợ/POS/kênh/chỉ tiêu | Đủ; thiếu **lãi gộp theo đơn** (giá vốn) | KD & kế toán: mỗi đơn biết giá vốn (từ giá thành mẻ/lô) → lãi gộp; kế hoạch bán tháng đã có ở S&OP | ⏳ COGS theo lô → lãi gộp đơn |
| 6 | **Du lịch** `/du-lich` | booking, sơ đồ phòng, tiệc/MICE, tour, dịch vụ, KPI, folio→bán | Đủ nghiệp vụ; thiếu **công suất phòng** theo tháng | Lễ tân/GĐ: occupancy %, doanh thu phòng theo tháng để định giá mùa | 🔧 `v_occupancy_month` + bảng trong tab KPI · ⏳ lịch phòng dạng calendar/housekeeping |
| 7 | **Thú y / Sức khỏe** `/thu-y /suc-khoe` | phác đồ, vaccine, điều trị, ngưng thuốc (chặn ở XUAT & sales), dịch tễ vùng, sổ thuốc TT66 | Đúng luật; danh sách ngưng thuốc giờ hiện trong Việc đàn | Bác sĩ: lịch vaccine theo tuổi/lứa tự sinh (đã có schedule) | ✅ (+🔧 NGUNG_THUOC trong Việc đàn) |
| 8 | **Nhân sự** `/nhan-su /giam-sat` | hồ sơ, chứng chỉ SOP, chấm công, nghỉ phép, đào tạo tuần, giám sát, thưởng gắn lương | Đạt sau đợt hôm qua | HCNS: hợp đồng lao động hết hạn, tuyển dụng, đánh giá năm | ⏳ HĐLĐ/tuyển dụng |
| 9 | **Kế toán** `/ke-toan` | GL kép, chi 2 chữ ký, lương, TSCĐ, AP/AR, vay, BH, GTGT, dòng tiền 13 tuần, hợp nhất | Đạt cho quản trị; **không thay HĐĐT/thuế** (đã chốt: qua MISA) | Kế toán: đối chiếu số dư kho–GL (giờ có v_stock_value), sao kê ngân hàng (RC10) | ⏳ import sao kê + đối chiếu tự động |
| 10 | **Tuân thủ** `/tuan-thu /chuan` | 23 chuẩn, 127 điều khoản → 34 control, evidence sống, audit ZIP, audit nội bộ quý, ICFS | Đạt | QA: theo dõi CAPA đến hạn (đã trong compliance_checks) | ✅ |
| 11 | **Tổ chức / Quy trình** `/to-chuc /sop` | 18 phòng ban, 146 quy trình (81 SOP-*), 422 L3, event bus, khai báo/chạy quy trình | Đạt; **thiếu ký ban hành SOP + video** | KTT/HCNS: SOP có bản ký (documents đã hỗ trợ), video ≤5' | ⏳ UI ký/đọc-hiểu SOP |
| 12 | **Thiết bị / IoT** `/thiet-bi` | thiết bị, giờ máy, bảo dưỡng theo giờ (task tự sinh), hiệu chuẩn quý, cảm biến, ingest API key | Đạt cơ bản; chưa có broker MQTT thật | KT thiết bị: lịch bảo dưỡng phòng ngừa theo giờ máy (có), phụ tùng | ⏳ MQTT thật khi có thiết bị |
| 13 | **Kế hoạch** `/ke-hoach` | (đã làm hôm nay) | Đạt khung; cần **dùng thật 1 tháng để hiệu chỉnh giả định** | Chủ/TGĐ/KTT | ✅ |
| 14 | **Trang chủ / HQ** `/trang-chu /hq` | khu vực theo vai, đa trại, KPI chủ tuần | Đạt | Chủ: thêm ô "S&OP tháng này: 3 vấn đề đỏ" | ⏳ ô tóm tắt kế hoạch trên trang chủ |
| 15 | **Ca của tôi** `/ca` | việc, ghi 3 chạm mọi vị trí (kèm nhập/xuất kho), giao ca, gần đây | Đạt; việc đàn/kế hoạch/giám sát/đào tạo giờ đổ về đây | Công nhân | ✅ |

## Kết luận đợt rà soát
- Sửa ngay 4 lỗ hổng "làm được nhưng chưa ra tiền/ra việc": việc đàn theo lịch sinh sản, giá thành ô, giá trị tồn kho, công suất phòng.
- Tồn còn lại đều là **nâng cấp** (không phải thiếu chức năng lõi): HOLD lô QC, trả NCC, COGS/lãi gộp đơn, HĐLĐ, sao kê, ký SOP, MQTT, ô tóm tắt kế hoạch.
- Nguyên tắc giữ xuyên suốt: mọi con số phải **tự tính từ dữ liệu thật**, mọi phân tích phải **ra việc** cho đúng người, mọi hằng số là **settings**.
