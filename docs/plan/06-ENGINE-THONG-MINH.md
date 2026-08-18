# 06 · ENGINE THÔNG MINH — "BỘ NÃO" ITRAN OS
*KPI engine · Alert engine · Reconciliation engine (RC1–RC10+) · Report engine · Forecast · Recommendation · Trợ lý AI · Camera AI. Nguồn: FILE-GỐC IX.6–7, Phụ lục B2–B3, Quyển 4 mục 07.5–6, Quyển 3 mục 15.6.*

## 0. Triết lý
Người + máy tạo **bản ghi**. Não làm 6 việc theo thứ tự tin cậy giảm dần: **(1) tính KPI** (xác định) → **(2) đối soát** (bắt lệch) → **(3) cảnh báo** (kích SOP) → **(4) viết báo cáo** (tự sinh) → **(5) dự báo** (xác suất) → **(6) gợi ý & trợ lý** (giải thích được, luôn dẫn nguồn bản ghi). Không có "AI quyết định thay người"; AI đề xuất, người duyệt, mọi đề xuất lưu vết.

Mọi engine đều **cấu hình được, có phiên bản, có vết** (P8): thay ngưỡng = bản ghi mới, ai đổi, lý do, hiệu lực từ ngày.

---

## 1. KPI ENGINE

### 1.1 Kiến trúc
- `KPI_DEF` (mã, công thức DSL/SQL an toàn tham chiếu view chuẩn, đơn vị, kỳ, mục tiêu, ngưỡng, phạm vi: farm/CC/khu/nhóm/cá nhân/con vật) + `KPI_DEF_VERSION`.
- Chạy: incremental theo sự kiện (stream từ NATS) cho KPI thời gian thực; batch đêm cho KPI kỳ; snapshot `KPI_VALUE` bất biến kèm `input_snapshot` (để tái tính, giải trình lương).
- Công thức viết bằng **DSL an toàn** (tập con SQL đọc-only trên view `v_*` đã chuẩn hóa) → được kiểm duyệt (parser whitelist), không cho truy cập bảng thô.

### 1.2 Danh mục KPI khởi tạo (từ bộ gốc; mở rộng theo benchmark)

| Nhóm | KPI | Công thức | Mục tiêu / Đỏ | Dùng cho |
|---|---|---|---|---|
| Bò sinh sản | Bê cai sữa/nái/năm | COUNT(ĐẺ→CAI_SỮA 12 th) / AVG(nái nền) | ≥0,85 / <0,75 | Lương lớp 2 A2, Cổng 4 |
| | Đậu thai/phối | COUNT(KHÁM_THAI +) / COUNT(PHỐI) | ≥55% / <45% | A2, Cổng 3 |
| | Khoảng cách 2 lứa | AVG(ĐẺ_n − ĐẺ_{n−1}) | ≤400 / >430 ngày | KTT |
| | Chờ phối sau cai sữa | AVG(PHỐI − CAI_SỮA) | ≤90 ngày | KTT |
| | Chết bê 0–6 th | CHẾT(bê≤6th)/bê sinh | ≤4% / >7% | A2 |
| | Chết nhập đàn | CHẾT trong 30 ngày sau NHẬP / NHẬP | ≤2% | Cổng 3 |
| Vỗ béo | ADG (tăng trọng ngày) | ΔCÂN / ngày, theo pha | ≥900 g / <750 | A2, khoán |
| | FCR vỗ | ΣFEED_LOG khu vỗ / ΔCÂN | theo pha (RC2) | KTT |
| | Chi phí TA/kg tăng | Σchi phí TA (giá vốn) / ΔCÂN | ≤55k / >65k | KTT, P&L |
| Cho ăn | Sai số cân mẻ | |kg thực − kh|/kh | ≤2% | A1 |
| | Thừa máng | thừa % ghi | 3–5% (0 thiếu, >8 dư) | A1 |
| | Đúng giờ | |giờ FEED_LOG − 06:00/15:00| | ±15' | A1, SLA1 |
| Gà đẻ | Tỷ lệ đẻ | trứng/ngày / mái | ≥78% | A3 |
| | Chết tháng | chết/đàn | ≤0,8% | A3 |
| | Trứng loại A | A / tổng | ≥92% | A3 |
| Gà thịt | Sống | (vào−chết)/vào | ≥93% | A3 |
| | FCR | ΣFEED/Σkg xuất | ≤2,8 | A3 |
| RAS | Sống | | ≥85% | A4 |
| | FCR | ΣFEED bể / Δsinh khối | ≤1,5 | A4 |
| | Sự cố DO | COUNT(ALERT DO đỏ) | 0 | A4, KS CN |
| Trồng trọt | Năng suất/lô | ΣTHU kg / ha | bắp ≥45 t/ha/vụ, cỏ ≥200 t/ha/năm | A5 |
| | Giá thành ủ chua | Σchi phí / kg | ≤900 đ / >1.100 | KTT |
| | Giờ máy hỏng | giờ chờ sửa / giờ vận hành | ≤5% / >10% | A5 |
| | Nhiên liệu/ha | Σlít / ha theo hoạt động | trong định mức | A5, RC7 |
| | BVTV hóa học | Σchi phí | 0 | GAP |
| | Ngày-tồn ủ chua | tồn K3 / tiêu thụ ngày | ≥60 / 45 vàng / 30 đỏ | Dashboard, R1, R7 |
| Khu D | Tấn xử lý/tháng | ΣBATCH nạp | kế hoạch | A6 |
| | Sản lượng phân trùn, BSF | ΣBATCH_OUTPUT | | A6 |
| | NH₃ đầu gió | AVG sensor | dưới ngưỡng | trưởng khu D (mùi) |
| D5 | Sai số trộn | | ≤2% | A7 |
| | Giá viên / cám công nghiệp | giá thành / giá tham chiếu | ≤65% | KTT |
| | Tự chủ TA % | giá trị nội trại / tổng khẩu phần | ≥80–85% | GĐ, Cổng |
| | Đa nguồn | max(nguồn/tổng) | ≤35% | R7 |
| Chế biến | CCP vi phạm | COUNT | 0 | A7 |
| | Giá thành/kg SKU | | | P&L |
| Kho | Chênh kiểm kê | |đếm − sổ|/sổ | ≤1% (đỏ >2% 2 kỳ) | A8, R11 |
| | Đơn đúng-đủ-đúng giờ | | ≥98% | A8 |
| | FEFO đỏ | tồn còn <20% hạn | | A8 |
| Kinh doanh | % sản lượng hợp đồng trước | | ≥70% | Trục 5 |
| | % kênh / SKU | | ≤40% | Trục 5 |
| | % khách / tổng DT | | ≤30% | |
| | Công nợ ngày | | ≤15 | A9 |
| | Khách quay lại | | ≥25% | A9 |
| | % DT bậc ≥3 | | ≥45% | GĐ |
| | Thịt bò / DT | | <35% | R6 |
| Resort | NPS | | ≥70 | A10 |
| | Công suất phòng, chi tiêu/khách, sự cố an toàn | | | A10 |
| An ninh | Xe không log | | 0 | A11 |
| Công nghệ | Uptime, phản hồi cảnh báo phút, backup lỗi | | ≥98% / <15' / 0 | A13 |
| Tài chính | EBITDA CC, dòng tiền, quỹ lưu động ngày chi, nợ/vốn chủ | | ≥60 ngày; ≤0,8 | A14, chủ |
| Cộng đồng | Hộ liên kết, khiếu nại kéo dài | | ≥30 (năm 2) / 0 | A14 |
| Chuẩn | SOP quá hạn rà, chứng chỉ hết hạn, test nước/dư lượng đến hạn, mock recall kỳ | | 0 quá hạn | A13 |

### 1.3 KPI → lương
`KPI_RESULT` kỳ tháng chấm điểm theo thang (đạt/không, tuyến tính giữa đỏ–mục tiêu) → % thưởng lớp 2 (10–25% cứng) → PAYROLL_RUN. Khoán quý lớp 3: P&L CC vượt kế hoạch × 15–20% → BONUS_POOL chia theo hệ số. Mọi bước có snapshot; người lao động xem được "vì sao điểm này" (drill-down đến bản ghi).

---

## 2. ALERT ENGINE

### 2.1 Kiến trúc
- Nguồn: `SENSOR_READ` stream (edge tính trước để không phụ thuộc internet: rule ĐỎ chạy tại edge, còi/đèn tại chỗ), sự kiện nghiệp vụ, KPI, lịch (cron), vắng dữ liệu (heartbeat: "không có FEED_LOG sau giờ ăn +60'").
- Biểu thức: **CEL** (Common Expression Language) — an toàn, sandbox; có mẫu: ngưỡng, ngưỡng có cửa sổ (DO<4 trong 5'), độ lệch %, vắng sự kiện, đến hạn, geofence (PostGIS ST_Within), so sánh 3 nguồn.
- Định tuyến: gửi **đồng thời** người phụ trách + cấp trên (luật giám sát 3 lớp); kênh: push app, còi/đèn (edge), SMS, Zalo ZNS, email, TV dashboard; escalation nếu không ack sau X phút → cấp trên nữa; cooldown/dedup; giờ im lặng cho VÀNG (không cho ĐỎ).
- Mỗi cảnh báo có: giá trị, ngưỡng, đồ thị 24h, **SOP kích hoạt** (nút mở checklist), nút "tạo INCIDENT", ack, thời gian phản hồi (KPI A13 <15').

### 2.2 Luật mặc định (seed)

| Mã | Điều kiện | Mức | Gửi | Kích |
|---|---|---|---|---|
| AL-RAS-DO | DO < 4 mg/l liên tục 5' | ĐỎ + còi | A4, KTT, GĐ | SOP RAS khẩn (sục ắc quy) |
| AL-RAS-PWR | Mất điện > 30 s không có máy phát | ĐỎ | A4, KS CN | |
| AL-FLOOD-1/2/3 | Mực nước trạm thượng nguồn ≥ ngưỡng cấp | VÀNG/CAM/ĐỎ | Ban chỉ huy | SOP R1 cấp tương ứng |
| AL-COLD | Nhiệt kho lạnh > ngưỡng 30' | ĐỎ | A8, GĐ, KS CN | SOP kho lạnh |
| AL-FEED-MISS | Không FEED_LOG khu X sau giờ ăn + 60' | VÀNG | A1, KTT | |
| AL-RUMI | Nhai lại giảm > 30%/con (vòng cổ) | VÀNG | Thú y nội bộ | Khám |
| AL-HEAT | Động dục phát hiện (vòng cổ) | XANH (việc) | A2 | Danh sách phối |
| AL-CALV | Sắp đẻ (vòng cổ/ngày dự kiến 280±) | XANH | A2 | Kit đỡ đẻ |
| AL-SIL-45/30 | Ngày-tồn ủ chua < 45 / < 30 | VÀNG/ĐỎ | KTT, GĐ | R7 |
| AL-INV-2 | Chênh kiểm kê > 2% (1 kỳ) / 2 kỳ liên tiếp | ĐỎ | GĐ, chủ | R11 điều tra |
| AL-GEO | Bò ra khỏi geofence | ĐỎ | A11, A2 | R17 |
| AL-NH3 | NH₃ đầu gió > ngưỡng 1h | VÀNG | Trưởng khu D | |
| AL-TEMP-BARN | Nhiệt chuồng > 35°C | VÀNG | A1 | Phun sương (R2) |
| AL-DUE-* | Đến hạn: vaccine, bảo dưỡng theo giờ máy, rà SOP 12 th, hiệu chuẩn, test nước, dư lượng, mock recall, khám SK, chứng chỉ | XANH/VÀNG | người phụ trách | Việc |
| AL-WD | Chuẩn bị XUẤT con chưa hết ngưng thuốc | ĐỎ chặn | A2, KTT | Chặn nghiệp vụ |
| AL-CCP | CCP vượt giới hạn tới hạn | ĐỎ | A7, KTT | Dừng dây chuyền, cô lập mẻ |
| AL-GATE | Xe qua cổng lõi không cân/không hố anolyte | ĐỎ | A11, GĐ | |
| AL-DEATH-POUL | Gà chết ≥ 5 con/ngày/khối | ĐỎ | A3, KTT, thú y | Khóa chuồng, R4 |
| AL-CASH | Quỹ lưu động < 60 ngày chi | VÀNG | GĐ, chủ | Dừng chi đầu tư |
| AL-PAY | Chi > 20 tr chờ chữ ký 2 / giao dịch > 50 tr | Thông báo | KT, chủ (SMS) | |
| AL-DEBT | Công nợ > 30 ngày | VÀNG | A9 | Ngừng giao |
| AL-SLA | Vi phạm 12 SLA giao nhận | VÀNG | bên GIAO + KTT | Trừ KPI |
| AL-SENSOR-OFF | Thiết bị mất tín hiệu > 15' | VÀNG | KS CN | |
| AL-DEV | Máy đến giờ bảo dưỡng | XANH | A5, xưởng | |
| AL-EPI | Bản tin thú y tỉnh có ổ dịch ≤ 20 km (nhập tay/RSS) | CAM | GĐ, KTT | Ngưng vào lứa gà |
| AL-PRICE | Giá bò < MA90 − x% | VÀNG | GĐ, KD | R6 bậc thang |
| AL-PAPER-24H | Phiếu giấy đã chụp > 24h chưa số hóa (RC11) | VÀNG | Trưởng nhóm | Nhập từ phiếu |
| AL-PAPER-SERIAL | Số seri phiếu nhảy quãng (RC11b) | ĐỎ | KTT, GĐ | Truy tờ mất |
| AL-BACKUP-FAIL | Backup đêm/xuất CSV tuần lỗi | ĐỎ | KS CN, GĐ (chưa có A13 → Zalo chủ) | Runbook backup |
| AL-DRILL-DUE | Đến hạn diễn tập restore backup (quý) / mất mạng giả lập / mock recall | XANH | KS CN, GĐ | Lịch diễn tập |

**Luật cấu hình (P8, theo Góp ý v1.5 mục 3.3):** mọi giá trị giờ/ngưỡng trong bảng trên (06:00/15:00, 35°C, ngưỡng lũ 3 cấp, 15:00 chốt đơn, 24h, 20%…) là **giá trị mặc định seed trong SETTING/NORM theo trại**, không hard-code; trại đổi qua UI có vết.

---

## 3. RECONCILIATION ENGINE (RC — trái tim theo dõi vào/ra)

- Job đêm 01:00 (theo trại) + chạy tay theo yêu cầu; mọi kết quả `RECON_RESULT` bất biến; lệch vượt ngưỡng → alert VÀNG/ĐỎ cho KTT + GĐ **kèm bảng chi tiết drill-down** (dòng nào lệch).
- Mỗi rule = 2 vế (A, B) là truy vấn có tham số + ngưỡng + kỳ; thêm rule qua UI (KS công nghệ), có phiên bản.

| Mã | Vế A | Vế B | Ngưỡng | Ghi chú |
|---|---|---|---|---|
| RC1 | Σ xuất K3+K4 (ngày) | Σ FEED_LOG kg thực (ngày) | >3% | theo khu |
| RC2 | FCR thực khu vỗ (kỳ) | FCR chuẩn pha (NORM) | >15% | |
| RC3 | Σ CROP_LOG THU (lô, ngày) | Σ nhập K3 qua cân cầu (WEIGH_TICKET) | >5% | |
| RC4 | Đàn quy đổi × định mức phân/con/ngày | Σ BATCH nạp trùn + biogas + compost | >15% | rò rỉ/đổ trộm |
| RC5 | Nhập K5/K6 từ BATCH_OUTPUT | Σ SALE + Δ tồn | >2% | theo SKU |
| RC6 | Trứng đếm băng chuyền (sensor) | Nhập K5 trứng | Xuất bán | >2% (3 điểm) |
| RC7 | Xuất K7 nhiên liệu | Σ giờ máy × định mức lít/giờ (DEVICE) | >10% | theo máy |
| RC8 | Xuất K1 thuốc | Σ EVENT ĐIỀU_TRỊ liều kê | mọi lệch | |
| RC9 | Sổ đàn K8 | Đếm tay tuần (STOCKTAKE) | Camera AI đếm | mọi lệch → điều tra 24h |
| RC10 | Σ SALE thanh toán | Sao kê ngân hàng + két POS | >0,5% | import sao kê |
| **RC11** | **GIẤY–SỐ:** PAPER_SCANS `digitized=false` > 24h | — | VÀNG → trưởng nhóm | theo SPEC-02 starter (bảng chuẩn duy nhất theo Góp ý v1.5) |
| **RC11b** | Số seri phiếu giấy nhảy quãng (mất tờ) trong cuốn | dãy seri liên tục | ĐỎ → KTT + GĐ | "0 tờ phiếu mất dấu" |
| RC12* | Σ tem in (K9) | Σ tem dán (BATCH_OUTPUT tem từ–đến) | mọi lệch | chống tem ngoài luồng |
| RC13* | Nước cấp đồng hồ khu | định mức nước/con | >20% | rò rỉ |
| RC14* | Điện đồng hồ khu | định mức | >20% | |
| RC15* | Số con XUẤT có giấy kiểm dịch | XUẤT | mọi lệch | tuân thủ |
| RC16* | Rác bếp cân giao BSF | Suất ăn × định mức | >30% | resort |

(*) mở rộng, bật khi có thiết bị. **Bảng số hiệu RC1–RC16 này là bảng chuẩn duy nhất** (đồng bộ Góp ý ràng buộc v1.5 mục 1); mọi tài liệu khác tham chiếu theo đây.

---

## 4. REPORT ENGINE (máy viết báo cáo)
- **Checklist ca** → thiếu hiện đỏ ngay trên app.
- **Báo cáo ngày** 21:00: 6 chỉ số chuẩn cho từng phân hệ (sản lượng · đầu vào · hao hụt · chi phí CC · cảnh báo · bằng chứng) + đỏ trong ngày.
- **1 trang thứ 6** 06:00: 6 dòng cân bằng vật chất (MATERIAL_BALANCE) + 4 chỉ số tồn kho sống + đỏ tuần + chênh kiểm kê + tồn tiền + việc-người-hạn từ CAPA; PDF + màn TV + Zalo GĐ/chủ.
- **P&L phân hệ ngày 5**: theo CC, doanh thu ngoài + nội bộ (70%), chi phí, phân bổ, EBITDA; khóa kỳ; so kế hoạch; xuất kế toán.
- **Quý**: khoán, rủi ro (19 + near-miss), module mới, cổng chặn.
- **Năm**: rà tài liệu, KPI năm, chia lợi nhuận, diễn tập.
- **Hồ sơ audit ≤ 24h**: 1 lệnh → ZIP (CSV + PDF có mục lục) theo khoảng thời gian/SKU/chuẩn: sự kiện, mẻ, kiểm phẩm, thuốc–vaccine–ngưng thuốc, lab, chứng chỉ nhân sự, nhật ký cổng, SOP phiên bản, hiệu chuẩn.
- Công nghệ: template (HTML/Typst) → PDF; snapshot dữ liệu JSON kèm; ký hash.

---

## 4b. ĐIỀU KIỆN BẬT "NÃO TẦNG CAO" (Forecast · Recommendation · Trợ lý AI · Camera AI)
Chỉ bật cho **dòng dữ liệu có ≥ 90 ngày dữ liệu sạch** (đo: % bản ghi hợp lệ ≥ 95%, không thiếu ngày, RC không đỏ kéo dài) — gắn theo dữ liệu, không theo lịch. Trước đó dashboard chỉ hiện số thật + KPI xác định. ASR giọng nói tiếng Việt offline = hạng mục **thử nghiệm**, không nằm trong cam kết nghiệm thu. LLM: **trần chi phí API/tháng cấu hình được** + fallback khi hết quota (báo cáo dạng bảng thuần); log Q&A giữ 12 tháng để đánh giá chất lượng.

## 5. FORECAST (dự báo) — v1 thống kê, v2 ML

| Dự báo | Đầu vào | Mô hình v1 | Đầu ra / dùng |
|---|---|---|---|
| Ngày-tồn ủ chua & nguyên liệu | tồn, tiêu thụ 30 ngày, đàn dự kiến, lịch thu | trung bình trượt + kịch bản đàn | cảnh báo sớm 30/60 ngày, kế hoạch mua |
| Lịch đẻ / cai sữa / xuất vỗ | PHỐI+280, KHÁM_THAI, ADG | xác định | lịch làm việc, dòng tiền |
| Sản lượng trứng, phân trùn, BSF | lịch sử theo tuổi đàn/mẻ | đường cong chuẩn + hồi quy | kế hoạch bán, hợp đồng |
| Sản lượng thu hoạch lô | NDVI, lịch sử lô, giống, thời tiết | hồi quy/LightGBM | kế hoạch ủ chua, K |
| Dòng tiền 90 ngày | đơn hàng, công nợ, chi kế hoạch, lương | mô phỏng | AL-CASH, cổng chặn |
| Giá bò/heo/trứng thị trường | nhập tay/thu thập giá chợ đầu mối | MA90 + cảnh báo | R6 |
| Công suất 5 trục khi cắm module | định mức × quy mô | xác định | Hồ sơ module bước 2 |
| Nguy cơ dịch/stress nhiệt | thời tiết, bản tin, vòng cổ | rule + score | R2/R3/R4 |
| Nhu cầu nhân công tuần | lịch vụ, đàn, booking | tổng hợp | phân ca |
Mọi dự báo lưu `FORECAST` với độ tin cậy; hiển thị "dự báo" khác màu với số thật; sai số theo dõi hằng tháng (MAPE) để cải tiến.

## 6. RECOMMENDATION (gợi ý, nhận định)
Rule-based + giải thích:
- "Nái F01-BO-00123: 95 ngày sau cai sữa chưa phối, 2 lần động dục bỏ lỡ → ưu tiên khám sinh sản (SOP-BO-03.x)".
- "Ủ chua còn 41 ngày cho 380 con; thu G2 dự kiến +120 t trong 12 ngày → vẫn dưới 60; đề xuất mua rơm 40 t từ NCC-0012 (còn hạn mức, giá HĐ)".
- "Nguồn bã bia đang 37% khẩu phần > 35% → đổi RECIPE v… (đề xuất công thức thay thế cùng đạm, giá +2%)".
- "SKU trứng: kênh B2B 43% > 40% → cảnh báo tập trung kênh".
- "Máy TB-021 còn 18 giờ tới bảo dưỡng, mùa thu hoạch bắt đầu 5 ngày nữa → bảo dưỡng trước".
- Cổng chặn: "C3 còn thiếu: đậu thai 48% (<50%) — cần thêm 6 khám thai dương / 12 khám còn lại".
Mỗi gợi ý: căn cứ (link bản ghi), hành động 1 chạm (tạo việc/đơn/công thức nháp), người nhận, phản hồi (chấp nhận/bỏ qua + lý do) để học.

## 7. TRỢ LÝ AI (LLM) — "hỏi trại bằng tiếng Việt"
- Kiến trúc: LLM (Claude API) + **tool-use trên API nội bộ có phân quyền** (không truy cập DB trực tiếp); text-to-SQL chỉ trên view semantic đã whitelist, read-only, giới hạn hàng; mọi câu trả lời dẫn nguồn bản ghi/kpi; log câu hỏi–trả lời.
- Việc: hỏi số liệu ("tuần này FCR khu vỗ bao nhiêu, so tuần trước?"), giải thích cảnh báo, soạn nháp SOP theo chuẩn 10+1 từ video/ghi âm hiện trường, tóm tắt 5-Why, soạn báo cáo lời cho 1 trang thứ 6, dịch 3 ngôn ngữ trạm QR, hỗ trợ khách "nhận nuôi", trả lời khách QR truy xuất.
- Chống rủi ro: không thực hiện hành động ghi/duyệt; không thấy dữ liệu ngoài quyền người hỏi; nội dung nhạy cảm (lương, giá vốn) theo vai; đánh giá chất lượng bằng bộ câu hỏi chuẩn hàng tháng.
- Trên thiết bị: nhập liệu bằng giọng nói tiếng Việt (offline ASR nhẹ trên điện thoại cho lệnh ngắn: "bò 00123 bỏ ăn").

## 8. CAMERA AI (đối chiếu, không phải sổ cái)
- Đếm đàn (bò/gà) tại chuồng theo lịch → RC9; phát hiện con tách đàn/nằm lâu (R3); nhận biển số cổng (OCR → GATE_LOG); phát hiện người vào khu cấm/không PPE (ATLĐ, cảnh báo); đo thức ăn thừa máng (ảnh A1).
- Chạy tại edge (Jetson/NPU) → chỉ đẩy kết quả + ảnh mốc; mô hình có phiên bản; độ chính xác theo dõi; **số chính thức luôn là kiểm đếm người + cân**.

## 9. ENGINE THẾ SỐ (PARAM) — Lớp B → Lớp C
- Đầu vào: S hữu dụng, dải, K (theo phụ phẩm vùng), tỷ lệ 8 nhóm đất, định mức/con, module bật/tắt theo dải và thị trường, 20 tham số địa phương hóa.
- Đầu ra: bảng 17 khu (ha), đàn (nái/tổng), hạ tầng (m² chuồng, m³ hào, m² trùn, m³ biogas, kWp, l nước/ngày), biên chế gợi ý, vốn khung theo module (min/đầy đủ), kiểm tra công suất 5 trục, checklist "không sót khu".
- Kiểm chứng bằng 3 ví dụ VD1/VD2/VD3 (bộ gốc) làm test case tự động; kết quả lưu `PARAM_OUTPUT` phiên bản, in "Phụ lục thế số F0x" PDF.

## 10. Chất lượng của não
- Test: mỗi KPI/RC/alert có bộ dữ liệu mẫu + kết quả kỳ vọng (golden tests); mọi thay đổi phiên bản chạy lại lịch sử để so sánh (backtest).
- Giải trình: mọi số trên dashboard drill-down 2 chạm đến bản ghi gốc.
- Hiệu năng: KPI thời gian thực < 5 s sau sự kiện; RC đêm < 30'; alert ĐỎ từ cảm biến < 10 s (edge), < 60 s (cloud).
