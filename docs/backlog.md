# Backlog — ITRAN AGRI

Ý mới phát sinh trong phiên → ghi ở đây, không mở rộng phạm vi giữa phiên (luật 10).

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
