# Backlog — ITRAN AGRI

Ý mới phát sinh trong phiên → ghi ở đây, không mở rộng phạm vi giữa phiên (luật 10).

## NỢ KỸ THUẬT — số migration trùng: ĐÃ VÁ (2026-09-03)
- **`0170` từng TRÙNG** (ghi 2026-08-20): `0170_mrp_material_demand.sql` và `0170_animal_feed_cost.sql`, do 2 phiên chạy song song. Đã đổi tên `0170_animal_feed_cost.sql` → `0206_animal_feed_cost.sql` (file chỉ tạo view qua `create or replace` + insert có `where not exists` — chạy lại vô hại trên DB đã migrate cũ, không ai phụ thuộc nó nên đổi ra sau an toàn). Kiểm chứng: rebuild-từ-trắng + `pnpm test` xanh.
- **Phát hiện thêm cùng đợt (2026-09-03, khi merge 6 PR audit)**: `0186` cũng từng TRÙNG tương tự — 1 nhánh dùng `0186_group_guard_skip_backfill.sql`, nhánh khác (PR #44, chưa merge lúc đó) định dùng `0186` cho fix SKU placeholder. Nhánh #44 đã tự đổi số thành `0191_process_io_fix_placeholder_sku.sql` khi merge trước đó — không còn xung đột, chỉ ghi nhận đây là LẦN THỨ 2 việc này xảy ra.
- **Quy ước tránh tái diễn (vẫn cần làm, chưa có gì chặn tự động)**: trước khi commit migration, `git fetch` + lấy `max số +1`. Chưa có CI check tự động phát hiện số trùng — nên cân nhắc thêm 1 bước CI đơn giản (`ls supabase/migrations | grep -oE '^[0-9]+' | sort | uniq -d` phải rỗng) để chặn hẳn, vì đã xảy ra 2 LẦN với nhiều phiên chạy song song.

## Rà soát phiên 2026-08-20 — lỗ hổng DỮ LIỆU/HOÀN THIỆN (không phải bug code; cần seed/flow/business quyết)

Phát hiện khi rà bug + làm enforcement Nhóm 0/1 (feed guard·AMU·mortality·withdrawal·trace·lot-expiry). Đã fix 2 bug code thật (FK `device_id` 0142, FK `sop_code` 0144). Còn lại là **hoàn thiện dữ liệu/luồng**:

- **`sale_animals` RỖNG (0 dòng)** → đơn bán CON SỐNG chưa truy xuất về cá thể. **CHẨN ĐOÁN: luồng ĐÚNG** — `sell_livestock` (0137) đã `insert into sale_animals`; đơn MỚI qua hàm có link. Gap chỉ ở **sales lịch sử seed** (chèn thẳng) và **KHÔNG backfill được** (seed không ghi con nào bán). → cần seed ghi qua `sell_livestock`; không phải bug code.
- **Trứng — ĐÃ GIẢI (0153)**: chủ chốt nhập lô trứng mỗi ngày → `record_intake` (TỔNG QUÁT, SKU biến, không fix cứng) tạo lô có hạn dùng (config `shelf_life`) + truy xuất về ĐÀN gà đẻ. Action `record_intake` cho app khai báo. Trứng/phân trùn-bò-dê-gà/tôm-cá dùng CHUNG hàm.
- **Rau — KHÔNG phải lỗ hổng**: chủ chốt rau **chỉ phục vụ nội khu, KHÔNG bán ra ngoài** → "rau bán không lô" không tính vào truy xuất bán. (Cân nhắc lọc SKU nội-khu khỏi `v_trace_coverage`.)

### Config cần khai (dữ liệu, không phải code — luật 7: đừng fix cứng SP)
- **Danh mục SP BÁN RA**: bò · dê · **hươu** · gà · trứng · tôm/cá · phân (trùn quế, bò, dê, gà). Nhiều SKU (hươu, tôm/cá, các loại phân) có thể **chưa khai** trong `products` → thêm vào danh mục (mark "bán ra") để `record_intake`/bán hàng dùng. Bán/mua chỉ cần **khai báo biến** theo `products`, không hard-code.
- **Lô hết hạn KHÔNG tự đóng**: 1362 lô F01 `KHA_DUNG` quá hạn mà còn tồn (seed để lô mở). 0149 đã CẢNH BÁO; cần job/hàm tự chuyển `status→HET` khi hết hạn & hết tồn (cẩn thận bulk-update trên DB chung).
- **Độ phủ ref `inventory_moves` NHAP_SX 33%** (OS-3 dừng đúng ở trứng — gà đẻ thu trực tiếp, không có sự kiện mẻ để nối; honest).
- **567/767 vật nuôi chưa cân bao giờ** (`last_weight_at` null) — seed thưa; nếu là data thật thì là lỗ hổng theo dõi tăng trưởng/FCR.
- **`animals.status` không có giá trị 'CHET'** dù trigger CHET set status='CHET' — chết cá thể (bò/dê) hầu như không xảy ra trong seed; chết chủ yếu theo ĐÀN (event SO_LUONG trên gà/lươn). Ghi chú mô hình, không phải lỗi.

## Năng suất người vận hành máy — lộ trình (rà soát 2026-08-19)

Bối cảnh đã chốt với chủ đầu tư:
- **Ghi tay là BẮT BUỘC** — giấy = CSDL cứng để soát chéo file mềm (số hóa không phải lúc nào cũng đúng). Không bỏ giấy; giá trị ở đối chiếu giấy↔số.
- Công nhân **vận hành MÁY** (tự động hóa), không phải "tay lấm bùn". Đòn bẩy = dẫn việc vận hành + bắt dữ liệu từ máy + cảnh báo sớm/nghiêm ngặt.
- Ghi chép là điền **bảng mẫu in sẵn theo quy trình** (ngày/tuần/tháng/đợt) — lặp lại, nhàn, nhưng bắt buộc để có dữ liệu đầu vào cho **phân tích → dự báo → kế hoạch**.

### ĐÃ LÀM (phiên 2026-08-19, đã build + verify + commit)
- **P0 · Sổ đọc số máy/công-tơ** (migration 0097): `reading_metrics` (config) + `device_readings` (append-only) + `record_reading()` bắt bất thường (nhảy vọt/số lùi) + view latest/due/anomalies. Ô **SERI GIẤY** để đối chiếu sổ tay↔số. UI ở /thiet-bi. **Là "cái bàn" IoT/MQTT sẽ ghi vào sau** (source APP/PAPER/IOT, schema không đổi).
- **P0 · Cảnh báo NGHIÊM NGẶT khi quên cập nhật** (migration 0098): `recording_obligations` (khai báo khâu + tần suất) + `v_recording_due` (OK/DUE/ESCALATE) + `gen_recording_alerts()` (quá hạn → việc CAO cho người phụ trách; quá mức → **LEO THANG lên GĐ KHẨN**) + `recording_misses` (nhật ký để đo tỷ lệ đúng hạn) + `v_recording_compliance`. Chạy trong job "tasks"/"all". UI ở /giam-sat › "Khâu quên cập nhật".

### CHỜ LÀM (ưu tiên, không cần phần cứng)
- **Đối chiếu giấy↔số RC11 mạnh hơn cho từng công nhân**: đưa "tờ giấy chưa số hóa / seri lệch" vào TodayBar của người phụ trách (mở rộng nguồn PAPER của engine 0098).
- **Cảnh báo sớm vận hành từ dữ liệu ĐÃ CÓ**: bỏ ăn, tụt cân, lệch khẩu phần, sắp hết PHI/ngưng thuốc → đẩy inbox công nhân (dùng alert_rules + tasks, không phần cứng).
- **Trend/dự báo từ device_readings + recording**: tiêu thụ điện/nước/biogas theo ngày → material balance tuần hoàn + dự báo chi phí; tỷ lệ đúng hạn → chấm điểm giám sát/thưởng.
- **Quét QR/mã vạch NGAY TRONG form 3 chạm** (BarcodeDetector đã có ở QrScan) — bỏ bước tách màn.

### RED-LIST (chờ chủ đầu tư quyết + có thiết bị thật — KHÔNG tự làm)
- **Đầu đọc tự động ghi vào `device_readings`**: cân/nhiệt kế **Bluetooth (Web Bluetooth/BLE)**, công-tơ điện/nước có cổng xung — đọc thẳng, bỏ chép tay. (Đã có device "Cân xe trộn BLE" trong danh mục.)
- **Broker MQTT/IoT thật** cho cảm biến (đã trong tồn dài hạn).
- **Camera AI** (PLF): phát hiện động dục/bệnh/khập khiễng, cân ước lượng qua ảnh; **cảm biến đeo** vật nuôi — chỉ khi đàn đủ lớn + có người vận hành, ROI mới dương.
- OTP/2FA, diễn tập backup off-site, monitoring/observability, test e2e.

### Nguyên tắc chốt để không lạc
Một công nghệ chỉ đưa vào khi thỏa CẢ 4: (a) bỏ ≥1 lần gõ/chép tay HOẶC bắt sớm 1 sự cố, (b) chạy offline, (c) ≤3 chạm ≤20s, chữ ≥16pt, (d) ROI đo được — và đo trước–sau bằng chính hệ (thời gian/bản ghi, tỷ lệ đúng hạn, việc quá hạn).

## Bug có sẵn phát hiện khi verify audit mobile/touch-target (phiên 2026-09-01, KHÔNG do đợt sửa này gây ra)

Phát hiện khi agent verify độc lập đăng nhập `owner`/`gd` đi qua 27 trang đã sửa touch-target — xác nhận đợt sửa không gây hồi quy, nhưng lộ 2 lỗi console có sẵn từ trước, ngoài phạm vi frontend-only của phiên này:

- **~~`/to-chuc` — console error~~ ĐÃ SỬA (commit 6325711)**: `<svg> attribute height: Expected length, "-Infinity"`. Gốc: `DeptGraph` (`ProcessFlow.tsx`) tính `height = Math.max(...mảng)` — `Math.max` trên mảng rỗng ra `-Infinity` khi `pos` (Map vị trí phòng ban) rỗng. Sửa bằng cách thêm sàn `Math.max(0, ...)`, cùng cách `width` đã tự vệ sẵn. Verify: DOM height đổi từ `-Infinity` → `352` (hợp lệ).
- **`/du-tru` — 2 vấn đề, CHỜ session backend xử lý** (đã nhắn qua `itran-farm-f5`, họ xác nhận sẽ xem sau khi xong đợt vá checklist hiện tại): (a) React cảnh báo "duplicate key" cho nhiều mã SKU (TH-OXY, NL-DAU, NL-BAP-U...) — dữ liệu dự phóng tồn kho có vẻ bị fetch/render trùng cho cùng SKU; (b) `GET /api/data/staff_list` trả về **404** — endpoint thiếu hoặc sai tên bảng.
