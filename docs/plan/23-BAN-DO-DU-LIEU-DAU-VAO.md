# Bản đồ dữ liệu đầu vào & luồng chảy — ITRAN AGRI

Truy toàn hệ ngày 20-08-2026. Mọi số liệu đo trực tiếp trên CSDL sau bản dựng lại từ trắng.

## 1. Có bao nhiêu loại dữ liệu đầu vào?

### A. 25 loại qua FORM GHI 3 CHẠM (lõi — công nhân nhập)
Tất cả: validate bằng zod (`src/lib/events.ts`), bảng **append-only** (không sửa/xoá, sửa = bản mới),
idempotent theo `client_ref`, đi qua `/api/events/{table}`.

| # | Loại | Bảng | Dòng (bản gieo) | Phát event_bus |
|---|---|---|---:|:---:|
| 1 | Sự kiện con vật | animal_events | 7.636 | ✔ |
| 2 | Mẻ TMR / cho ăn | feed_logs | 1.422 | — |
| 3 | Nhật ký lô cây | crop_logs | 271 | — |
| 4 | Mẻ D5 / khu D | batch_logs | 2.322 | — |
| 5 | Nhập/xuất kho | inventory_moves | 9.970 | — |
| 6 | Phiếu cân | weigh_tickets | 0 | — |
| 7 | Nhật ký cổng | gate_logs | 2.124 | — |
| 8 | Bán hàng | sales | 6.800 | — |
| 9 | Checklist ca SOP | checklist_runs | 2.844 | — |
| 10 | Đọc số máy/công-tơ | device_readings | 56 | ✔ |
| 11 | Sự cố / near-miss | incidents | 20 | ✔ |
| 12 | Kiểm kê (đếm mù) | stocktakes | 120 | — |
| 13 | Điều chỉnh (có duyệt) | adjustments | 0 | — |
| 14 | Nộp phiếu giấy | paper_scans | 0 | — |
| 15 | Vật tư canh tác (PHI) | crop_inputs | 32 | — |
| 16 | Tưới nước | irrigation_logs | 124 | ✔ |
| 17 | Điều tra sâu bệnh | pest_scouting | 62 | ✔ |
| 18 | Thu hoạch | harvests | 50 | ✔ |
| 19 | Hoá đơn POS | pos_receipts | 2.060 | — |
| 20 | Lưu mẫu thức ăn (ATTP) | food_samples | 0 | — |
| 21 | Nhiệt độ chuỗi lạnh | cold_chain_logs | 0 | — |
| 22 | Hiệu chuẩn thiết bị | calibrations | 143 | — |
| 23 | Chấm công | attendance_logs | 0 | — |
| 24 | Bảo trì / sửa chữa | maintenance_logs | 0 | — |
| 25 | Sổ khách (phòng/tour/ăn) | hosp_folio | 1.548 | — |

**18/25 có dữ liệu sống; 7 loại rỗng trên bản gieo** — trong đó 4 loại mới (lưu mẫu, chuỗi lạnh,
chấm công, bảo trì) đã kiểm chứng ghi thật thành công bằng tay; 3 loại (phiếu cân, điều chỉnh,
nộp phiếu giấy) chưa gieo dữ liệu mẫu nhưng form chạy đúng.

### B. ~60 HÀNH ĐỘNG qua Actions API (`/api/actions`)
Không phải ghi sự kiện, mà thao tác nghiệp vụ: duyệt/ký, treo việc, ghi sổ giao ca, giữ lô QC,
trả nhà cung cấp, chốt lương, xác nhận bậc, phân công, bàn giao người thay…

### C. Kênh nhập khác
- **POS** (bán tại quầy/du lịch) → pos_receipts → sales
- **Nhập CSV** (`/api/import/csv`) → bất kỳ bảng danh mục nào
- **IoT / cảm biến** → device_readings, số công-tơ (record_reading)
- **Ảnh / file** (`/api/upload`) → documents (đính vào đối tượng)
- **Quản trị** (`/quan-tri`) → CRUD 124 bảng có kiểm soát

## 2. Luồng chảy của mỗi loại — mô hình 4 chặng

```
[1] GHI (form 3 chạm / POS / CSV / IoT)
      → validate zod → bảng append-only (idempotent client_ref)
[2] CẬP NHẬT TRẠNG THÁI DẪN XUẤT (trigger)
      → animals.status/withdrawal, tồn kho, khoá kỳ, cache_dirty…
[3] PHÁT SỰ KIỆN (chỉ 6/25 loại nghiệp vụ đáng kể — publish_event)
      → event_bus → dispatch → notifications (app/zalo/sms) + tự chạy quy trình
[4] TỔNG HỢP (job đêm)
      → agg_daily, stock_daily, snapshot → dashboard/KPI/GL (drill về bản ghi gốc)
```

**6 loại phát event_bus** (sinh thông báo/tự chạy quy trình): animal_events, incidents,
irrigation_logs, pest_scouting, harvests, device_readings.
**19 loại còn lại** ghi + cập nhật trạng thái + chảy vào tổng hợp, KHÔNG đẻ thông báo — đúng
thiết kế giảm nhiễu (không phải mọi bản ghi thô đều cần phiền người).

## 3. Hai chỗ luồng TỪNG DỪNG (đã sửa)

| Chặng | Lỗi | Sửa |
|---|---|---|
| [3] event_bus → thông báo | 1 sự kiện có người nhận mã cũ (NS-110) làm VĂNG cả lượt → kẹt vĩnh viễn 11.748 sự kiện | Lọc người nhận còn tồn tại + cô lập lỗi từng sự kiện (0132, notify.ts) |
| [4] tổng hợp tồn kho | `null` không kiểu → text, chèn vào avg_cost numeric hỏng; chỉ nổ cuối tháng | `null::numeric` (0133) |

Sau sửa: `/api/jobs/all` chạy trọn; event_bus vét sạch về 0; GL cân đối (Nợ=Có, lệch 0).

## 4. Chốt chặn toàn vẹn đã có
- **97 khoá ngoại** — không ghi được tham chiếu ma (0127)
- **Chốt lúc ghi** — cấm đàn đã đóng sổ + ngày tương lai (0131)
- **Append-only** — mọi bảng sự kiện cấm sửa/xoá (trigger)
- **Idempotent** — trùng client_ref bị bỏ, không nhân đôi

## 5. Còn nên làm (không phải lỗi luồng)
- Cân nhắc cho vài loại phát event_bus để bắt tay chéo phòng: **cold_chain_logs** (nhiệt vượt
  ngưỡng → cảnh báo ngay), **maintenance_logs kết quả NGUNG_DUNG** (máy hỏng → báo vận hành).
- Siết nhiễu cảnh báo **AL-FEFO** (nổ hàng trăm/lần chạy) — mảng cảnh báo.
- Gieo dữ liệu mẫu cho 3 loại rỗng (phiếu cân, điều chỉnh, nộp phiếu giấy) để test đủ.
