# 18 · BẬC – GHẾ – NGẠCH GIÁM SÁT & KẾ THỪA – CHỐNG THÔNG ĐỒNG — thiết kế đã xây (19/08/2026, migration 0087–0089)

## A. Nguyên tắc chốt
1. **Bậc ≠ chức.** Bậc là của cá nhân, không giới hạn số lượng, gắn hệ số lương lớp 1 (`grade_scales.salary_coef`). Chức là **ghế** theo định biên (`key_positions`), chỉ mở khi có ghế.
2. **Mọi tiêu chí là dữ liệu có phiên bản** (`grade_scales.criteria` jsonb) — không hằng số trong code; **mọi bằng chứng tự tính** từ dữ liệu vận hành (`grade_evidence`), không ai nhập.
3. **Xét quý tự động → hội đồng 3 chữ ký** (quản lý trực tiếp · giám sát · HCNS; `ERR_SELF_APPROVE`); lên bậc = thử bậc 3 tháng; xuống bậc mềm (2 quý liền cảnh báo); kháng nghị 1 lần.
4. **Giám sát là đơn vị của công ty mẹ** (tuyến 2), biệt phái xuống trại; menu đặt ở nhóm *Điều hành & Kế hoạch*. Trưởng phòng = tuyến 1 (một sếp duy nhất); Tuân thủ/audit = tuyến 3.
5. **Ngạch GS là lò kế thừa GĐ trại**: vào từ B3 mọi phòng, luân chuyển 8 khối theo quý (lệch pha ≤1/3 tổ), đi ca thật ≥1 ngày/tuần, làm quyền trưởng phòng khi họ nghỉ (cơ chế người thay), GS3 = 6/8 khối, PGĐ = 8/8 → GĐ trại / GĐ trại mới khi nhân rộng.
6. **Không tin ai mặc định**: máy chọn mẫu, kiểm chéo mù, 8 tín hiệu tự tính, cờ đỏ → tuyến 3 kiểm đột xuất, phản ánh ẩn danh, hậu quả vào bậc/thưởng.

## B. Thang bậc (dữ liệu, sửa ở Quản trị DL › grade_scales)
| Ngạch | Bậc | Hệ số | Điều kiện đo được |
|---|---|---|---|
| CM | B1 Tập sự | 1.00 | — |
| CM | B2 Thạo việc | 1.15 | ≥3 th · 100% SOP vị trí ≥ THỰC HÀNH · điểm GS ≥80 (3 th) · đúng giờ ≥90% |
| CM | B3 Chính | 1.35 | ≥12 th · 80% SOP ≥ THUẦN THỤC · KPI ≥9/12 (tỷ lệ nếu chưa đủ 12 kỳ) · 0 lỗi nặng 6 th · GS ≥85 |
| CM | B4 Thợ cả/Chuyên gia | 1.60 | ≥24 th · 50% SOP DẠY ĐƯỢC · dạy ≥6 buổi, học viên đậu ≥80% · ≥1 sáng kiến duyệt · KPI 9/12 · 0 lỗi nặng 12 th |
| GS | GS1 tập sự | 1.35 | vào từ B3 |
| GS | GS2 | 1.55 | ≥6 th GS · đủ lượt tuần ≥90% · khớp kiểm chéo ≥85% · 2/8 khối · chấm ngược ≥3.5 · đi ca ≥8 ngày/6 th · 0 cờ đỏ |
| GS | GS3 Giám sát trưởng | 1.85 | ≥18 th · 6/8 khối · ≥2 kỳ làm quyền ≥14 ngày · phòng kiểm tăng ≥10 điểm/2 quý · chấm ngược ≥4 · 0 cờ đỏ |
| GS | PGĐ dự bị | 2.20 | ≥30 th · 8/8 khối · ≥3 kỳ làm quyền · chủ trì 1 KH năm/audit · 0 cờ đỏ |
Khối đạt = kiểm ≥3 tháng · đậu SOP cốt lõi khối · đi ca thật ≥4 ngày (settings `gs.block_months`, `gs.block_field_days`).

## C. Nhịp tuần trưởng phòng ↔ giám sát
T2–T5 GS kiểm theo phân công + máy bốc N mẫu ngẫu nhiên (bắt buộc ảnh) + 1 ngày đi ca thật → **T6** `gen_capa_tasks`: lỗi chưa có biện pháp → việc CAPA của trưởng phòng (hạn T2 12h) → trưởng phòng ghi biện pháp/người/hạn (nội dung dạy tuần tới) → GS chấm lại lỗi cũ (`capa_verify`) → lỗi lặp ≥3 tuần (`v_repeat_faults`) trừ trưởng phòng. Trưởng phòng chấm ngược GS hằng tháng (`supervisor_ratings`). Bất đồng → GĐ quyết 48h. GS không giao việc/ra lệnh công nhân; bị chặn chấm phòng gốc (`trg_sup_check_guard`).

## D. Chống thông đồng (0089) — 6 lớp
| Lớp | Cơ chế | Hiện thực |
|---|---|---|
| 1 | Máy chọn mẫu | `gen_random_spot_checks` (T2): mỗi GS N mục ngẫu nhiên/tuần, việc `KIEM_NGAU_NHIEN` |
| 2 | Đối chiếu dữ liệu tự động | S1: chấm ĐẠT khi `supervision_scores` AUTO báo ≥2 mục không đạt |
| 3 | Kiểm chéo mù | `gen_cross_checks` (T5–T6): bốc 20% mẫu ĐẠT → GS khác/audit chấm lại độc lập; `submit_cross_check` chèn check thật → `agree_pct`; lệch → báo GĐ (S5) |
| 4 | 8 tín hiệu tự tính | `v_collusion_signals` S1 trái dữ liệu · S2 chấm quá nhanh · S3 ≥4 tuần không lỗi dù dữ liệu xấu · S4 xác nhận CAPA <24h · S5 kiểm chéo lệch · S6 kiểm phòng gốc · S7 không ảnh · S8 chấm ngược đổi chác → `v_collusion_pairs` (đỏ/vàng/xanh) |
| 5 | Cờ đỏ → tuyến 3 | `gen_collusion_audits` (T2): việc `KIEM_DOT_XUAT` KHẨN cho audit/GĐ + báo Chủ tịch/TGĐ; `collusion_flags` chặn lên bậc GS (`flags_max:0`) |
| 6 | Phản ánh ẩn danh | `whistle_submit` (security definer, không lưu người gửi, băm chống spam 5/tuần) → chỉ owner/director đọc; xử lý ở /giam-sat?tab=chong |
Cộng thêm: luân chuyển GS theo quý phá quan hệ lâu ngày; GS bị chặn chấm phòng gốc/chính mình ngay lúc ghi.

## E. Bản đồ kế thừa & định biên
`key_positions` (ghế then chốt, người giữ, bậc tối thiểu, ngạch) + `succession_plans` (người kế thừa, sẵn sàng NGAY/1 năm/2 năm, kế hoạch phát triển) → `v_succession`; ghế không có kế thừa hiện đỏ cho Chủ tịch/HCNS. Người kế thừa GĐ trại phải thuộc ngạch GS (PGĐ).

## F. Điểm cống hiến (công khai)
`v_contribution` = KPI tháng đạt ×10 · điểm GS/10 ×2 · buổi dạy ×5 · sáng kiến duyệt ×20 · lần thay người ×8 (settings `contrib.*`) — dùng làm điểm cộng khi tranh ghế, không thay tiêu chí.

## G. Việc còn lại (chưa làm, cần anh chốt)
- Gắn `salary_coef` vào bảng lương thật (payroll_runs) — hiện chỉ hiển thị hệ số; cần thang bảng lương đăng ký Sở LĐ + phụ lục HĐLĐ.
- Định biên theo kế hoạch năm (số ghế/bậc dự kiến trong quỹ lương S&OP).
- Chấm thi SOP cho GS theo khối: hiện dựa `training_tests` bất kỳ SOP của phòng trong khối; nên định nghĩa "SOP cốt lõi khối" riêng.

## H. Bổ sung 19/08 (0090–0091) — GS hằng ngày theo quy trình phòng · lỗi GS · cơ chế lương–thưởng 4 lớp · định biên · SOP cốt lõi khối
- **Quy trình phòng → bộ tiêu chí kiểm**: `sync_process_criteria()` sinh `SC-P-<mã quy trình>` (136 tiêu chí MANUAL từ `processes`/`process_steps.control`, tần suất NGAY/TUAN/THANG) + 5 tiêu chí riêng cho **trưởng phòng** (`role_scope='TRUONG_PHONG'`: tự kiểm/giao việc, dạy đủ giờ, CAPA đúng hạn, việc phòng không quá hạn, lỗi lặp).
- **GS1 kiểm HẰNG NGÀY, không chờ việc**: tab *Hôm nay của GS* (`gs_today`) — mỗi phòng được phân công: quy trình đến hạn kiểm (Đạt/Lỗi 1 chạm), con người (thợ + trưởng phòng, kiểm lần cuối, lỗi auto), lỗi hệ thống phát hiện chưa được GS ghi (24h), lỗi GS tháng này / ngưỡng.
- **Lỗi của GS** (`gs_omissions`, máy ghi, GS không sửa được; job đêm `gen_gs_omissions`): KHONG_KIEM (ngày làm việc <N lượt/phòng), BO_SOT_LOI (auto không đạt mà GS không ghi/xác nhận trong 24h), KHONG_KIEM_TRUONG_PHONG (tuần không kiểm trưởng phòng), KHONG_XU_LY_LOI (lỗi có biện pháp >7 ngày không chấm lại). Vượt `gs.omissions_max_month` (3) → **mất thưởng tháng** (bonus_eval), điểm lỗi GS trừ thưởng; trưởng phòng bị trừ theo lỗi lặp/CAPA quá hạn của phòng (`bonus.head_*`).
- **Cơ chế lương–thưởng 4 lớp**: L1 = `salary_scales` (vị trí A1–A14/vai) × hệ số bậc (`pay_base`) × ngày công — **đã gắn vào `compute_payroll` thật**, ghi nguồn trong payslip.detail; L2 = KPI tháng + thưởng điều kiện (bonus_eval, có lỗi GS/trưởng phòng); L3 = phụ cấp ghế then chốt (`key_positions.allowance`), biệt phái GS (`pay.gs_secondment_allowance`), hồ sơ; L4 = thưởng cống hiến quý (`close_contribution_bonus` → bonus_ledger THUONG_QUY → trả tháng đầu quý sau). Mọi người xem "Lương của tôi tính thế nào" ở Tài khoản; HCNS xem tab *Cơ chế lương–thưởng · định biên*.
- **Định biên theo năm**: `headcount_plans` (+ `suggest_headcount` từ thực tế) → `v_headcount` (định biên vs thực tế vs quỹ L1).
- **SOP cốt lõi theo khối GS**: `gs_block_sops` — khối đạt khi đậu ĐỦ SOP cốt lõi (thay cho "bất kỳ SOP của phòng").
