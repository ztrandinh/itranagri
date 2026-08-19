# Biên bản 21 — Test từng tài khoản công nhân, đi hết mọi tính năng

Ngày 19-08-2026. Người test: đóng vai công nhân, thao tác thật trên trình duyệt
(`localhost:3222`, worktree `itran-os-uxfix`, nhánh `ux-fixes`).

## 0. Phạm vi — làm gì, KHÔNG làm gì

**Đã làm**
- 26 tài khoản công nhân/trưởng nhóm, đủ 9 bộ phận (D5, KTCN, SH, TT, CCU, KDM, DL, HCNS, CNTB).
- **166 lượt đi form**, mỗi lượt đi hết Bước 1 → Bước 2 → Bước 3: chọn đối tượng, điền
  **mọi** ô của bước 2, kiểm nút "Tiếp →" có mở không, có tới được màn XÁC NHẬN không.
- **4 lần bấm XÁC NHẬN thật**, đối chiếu số dòng trong PostgreSQL trước/sau.
- Quét 4 tab của màn Ca (Việc hôm nay · Ghi 3 chạm · Giao ca · Tôi vừa ghi).

**Chưa làm (nói thẳng để khỏi hiểu nhầm là đã xong)**
- Tài khoản quản lý (owner/gd/ktt/tp-*): đợt này chỉ tập trung công nhân.
- Luồng chụp/tải ảnh thật, hàng đợi offline (IndexedDB), quét QR bằng camera.
- Các trang ngoài `/ca` của từng vai.

**Kết quả tổng:** 166 lượt đi form → **140 lượt đi trọn 3 bước**. 26 lượt còn lại đều là
form "📷 Nộp phiếu giấy" bắt buộc ảnh — máy không nộp ảnh được, **không phải lỗi**.

## 1. Lỗi CHẶN đã tìm ra và đã sửa

### 1.1 Form tự xoá trắng dữ liệu công nhân đang nhập — `a65fa2b`
Công nhân mở app rồi ghi ngay (lúc danh mục nền còn đang tải) thì các ô vừa nhập bị xoá
sạch, nút vẫn báo "Thiếu:" đúng những ô vừa điền.

Đo được (a1 / "Mẻ TMR / cho ăn", gắn đếm tạm vào component):

| Chỉ số | Giá trị |
|---|---|
| số lần mount ThreeTap | 2 (chỉ là StrictMode nhân đôi — **không** remount) |
| số lần chạy effect reset | **11** |
| công nhân chạm lúc | 431 ms |
| các lần reset sau cú chạm | 547, 571, 584, 606, 624, 706, 714, 729, 736 ms |

Mốc DOM: 41 ms nút còn "Thiếu: Cữ, Khối lượng" → 74 ms quay lại "Thiếu: Công thức, Cữ,
Khối lượng" **dù không ai chạm gì**.

Nguyên nhân: `useEffect(..., [spec.fields])` trong khi cha dựng `spec` bằng object literal
mỗi lần render → `spec.fields` đổi danh tính liên tục → `setVals(mặc định)` đè lên giá trị
đang nhập. Sửa: khoá effect theo **chữ ký nội dung** form, và `useMemo` giữ nguyên một
`spec` ở CaPanel.

Kiểm chứng: trước sửa hỏng ngay lần 1/3 → sau sửa **4/4** đi trọn 3 bước.

### 1.2 Mất dữ liệu khi bấm nhanh liên tiếp — `dfffdc6`
7 chỗ dùng `setVals({ ...vals, ... })` bắt cứng `vals` từ closure cũ. Chạm nhiều ô nhanh
hơn một nhịp render thì ô trước bị ghi đè ngược. Đổi cả 7 sang functional update.

### 1.3 Bảo vệ không ghi nổi "Nhật ký cổng" — `9b75ff4`
Đối tượng của form này là **biển số xe** nên không thể có sẵn danh sách (`targets: []`).
Bước 1 hiện lưới rỗng, lối đi duy nhất là **phím Enter** — trên bàn phím điện thoại phím
đó ghi "Xong"/"Go". Bảo vệ gõ xong biển số, không thấy nút nào, tắc hẳn. Đây là việc
**chính** của vị trí A11.

Sửa: hiện nút "Dùng «mã vừa gõ» → Tiếp" cho **mọi** form cho phép gõ tay, và viết lại câu
trạng thái rỗng theo đúng ngữ cảnh. Kiểm chứng: a11 ghi được, bản ghi xuống bảng `gate_logs`.

### 1.4 "Gần đây" không có bản ghi của chính công nhân — `7a2e490`
Tab dùng `events_recent` = 100 dòng mới nhất **của cả trại**. Đo sau khi ghi thật 3 bản:
**60/60 dòng là nhập liệu cũ của người khác, 0 dòng là bản vừa tạo.** Công nhân không có
cách nào xác nhận mình đã lưu được.

Sửa: thêm truy vấn `events_mine` (lọc `created_by = app_staff()`, chặn `ts <= now()`), đổi
tên tab thành **"Tôi vừa ghi"**, thêm trạng thái rỗng có nghĩa. Giữ nguyên `events_recent`
cho bảng điều hành. Kiểm chứng: hai dòng đầu đúng là hai bản vừa ghi lúc 09:09 19-08.

### 1.5 Mọi công nhân thấy y hệt "300 việc · 296 quá hạn" — `899baa0`
5 vai khác bộ phận nhìn thấy **giống hệt nhau**, việc đứng đầu của cả 5 đều là "Cân định
kỳ 30 ngày — F01-BO-xxx" dù A3 nuôi gà, A4 nuôi cá, A5 lái máy.

Gốc nằm ở **dữ liệu sinh việc** (thuộc phiên khác):

| role_hint | việc đang mở | có người nhận | quá hạn |
|---|---:|---:|---:|
| tech_head | 7.758 | 0 | 7.742 |
| worker | 2.310 | 0 | 2.302 |
| team_lead | 1.289 | 0 | 0 |
| worker:A2 | 879 | 0 | 0 |
| worker:A5 | 414 | 0 | 0 |
| (NULL) | 34 | **34** | 0 |

**12.751 việc đang mở, chỉ 34 việc (0,27%) có người nhận, 10.083 quá hạn.**

Sửa phía màn hình (**không xoá việc nào**): "Việc hôm nay" chỉ đếm/liệt kê việc **đích
danh**; việc chung chưa giao ai gom vào khối gấp lại có số lượng + số quá hạn + lời giải
thích. Kiểm chứng: a1 → "Việc hôm nay (2 · 2 quá hạn)" đúng nghề ("Trộn & rải TMR pha vỗ
béo"), việc chung 298 gấp lại.

## 2. Ghi thật xuống CSDL — có kiểm chứng

Bấm XÁC NHẬN như công nhân, đếm dòng trong PostgreSQL trước/sau:

| Bảng | Trước | Sau |
|---|---:|---:|
| feed_logs | 1.568 | 1.569 |
| animal_events | 8.242 | 8.243 |
| incidents | 22 | 23 |
| gate_logs | 2.217 | 2.218 |

Dòng `gate_logs` mới nhất: `51C-12345 | VAO | TEST | 2026-08-19 02:09:32` — chính là bản ghi
mà **trước khi sửa thì không tài nào tạo được**.

## 3. THIẾU — cần bổ sung (chưa sửa, cần chốt nghiệp vụ trước)

### 3.1 Vị trí có nghề nhưng không có form cho nghề đó

| Tài khoản | Chức danh | Form đang được cấp | Thiếu |
|---|---|---|---|
| `cn-d5-2` | CN ép viên – **trộn TMR** ca 2 | Mẻ D5, NHẬP kho, Checklist, Sự cố, Phiếu giấy | **Không có form "Mẻ TMR"** dù chức danh ghi rõ trộn TMR |
| `cn-bap` | CN bắp sinh khối – **ủ chua** | Nhật ký lô, Tưới, Sâu bệnh, Đổ dầu, kho… | **Không có form ủ chua** (nạp hố, mật độ nén, pH, ngày mở hố) |
| `taixe` | **Tài xế** xe tải/lạnh | y hệt bộ của thủ kho | Không có nhật ký chuyến, đổ dầu, kiểm xe đầu ca, **nhật ký nhiệt độ xe lạnh** |
| `ktv-tb` | KT viên thiết bị – **hiệu chuẩn – IoT** | y hệt bộ của thủ kho | Không có phiếu hiệu chuẩn, nhật ký bảo trì/sửa chữa, kiểm cảm biến — dù đã có bảng `devices` |
| `letan` | Lễ tân – **đặt phòng – tour** | Bán hàng, kho, Sự cố, Phiếu giấy | Không có form đặt phòng / nhận khách / chốt tour |
| `bep` | **Bếp trưởng** farm-to-table | Bán hàng, kho, Sự cố, Phiếu giấy | Không có form suất ăn, nhập nguyên liệu bếp, lưu mẫu thức ăn (bắt buộc ATTP) |
| `hanhchinh` | Hành chính – **chấm công** – y tế trại | Nhật ký cổng, kho, Sự cố, Phiếu giấy | Không có form chấm công, không có form y tế trại |

### 3.2 "Checklist ca theo SOP" không có checklist
Form chỉ có **một công tắc "Tất cả bước ĐẠT"** + ô lý do. Không liệt kê từng bước SOP để
tích. Tên gọi hứa một đằng, form làm một nẻo — và về tuân thủ thì một cú bấm "tất cả đạt"
không phải bằng chứng.

### 3.3 Danh sách đối tượng bẩn (form TMR, tài khoản a1)
- Có **"Gà đẻ lứa 00 (đã loại) — 0 con"**: đàn đã loại, 0 con, vẫn mời chọn.
- Công nhân TMR bò vẫn thấy đàn gà / lươn.
- Nhãn dính chữ: **"Đàn nái dãy 1153 con"** = "dãy 1" + "153 con" — đọc ra 1.153 con.

### 3.4 Tài khoản `a10` không tồn tại
Tài liệu ghi dải `a1…a11`, CSDL không có `a10`.

### 3.5 Còn tồn, chưa sửa đợt này
- **Hai con số đá nhau trên cùng một màn**: "Hôm nay của tôi (13)" vs "Việc hôm nay (2)".
- **Chuông 99+, "Tin chưa đọc: 688"** — công nhân không còn coi thông báo là tín hiệu.
- **Menu bên trái của công nhân** vẫn bày nhiều mô-đun không liên quan (Canh tác, Bản đồ
  ô thửa, Thú y, Cảnh báo & luật…) với một công nhân trộn TMR.
- **Việc giao sai nghề**: A1 TMR bị giao "Cân định kỳ 30 ngày" từng con bò.

## 4. Việc cần chuyển cho phiên xử lý dữ liệu
1. Sinh việc **phải gán người** — hiện 0,27% có người nhận.
2. 10.083 việc quá hạn: chốt là dọn hay đổi hạn; để nguyên thì mọi cảnh báo mất giá trị.
3. Dữ liệu có `ts` **tương lai** (08-09) trong khi hôm nay 19-08.
4. Đàn "đã loại — 0 con" cần loại khỏi danh mục chọn.
5. Bổ sung tài khoản `a10` hoặc sửa tài liệu.
