# 15 · BIÊN BẢN THỬ NGHIỆM ĐÓNG VAI TỪNG BỘ PHẬN — 18/08/2026 (trên dữ liệu "trại 30 tháng", 65 nhân sự)

Cách làm: đăng nhập từng tài khoản (PIN 1234), đi hết 42 trang, thực hiện nghiệp vụ thật của vai qua form/API, so với quy trình L2/L3 của bộ phận đó. ✅ = chạy đúng · 🔧 = lỗi phát hiện & đã sửa trong đợt này · ⏳ = tồn.

| Vai (login) | Việc thử | Kết quả |
|---|---|---|
| CN đồng cỏ (cn-co1, A5, TT) | Ca của tôi: form Nhật ký lô CẮT cỏ 2.800 kg → **tự nhập kho K3 NL-CO-TUOI**; ghi tưới; ghi IPM; xem việc/thông báo bộ phận | ✅ (0070 auto stock-in) |
| CN chuồng bò (cn-bo2, A1) | Cho ăn TMR (planned/actual), cân, sự kiện đàn | ✅ |
| CN gà (cn-ga2, A3) | Đếm trứng ngày → tỷ lệ đẻ; nhập vỉ K5 | ✅ |
| Bác sĩ thú y (bsty) | Điều trị + ngưng thuốc đến 15/9 → XUAT bị chặn ERR_WITHDRAWAL_ACTIVE | ✅ |
| NVKD (nvkd1, A9) | Bán bò hơi con đang ngưng thuốc qua phiếu bán (detail.animal_id) | 🔧 **trước đây lọt** — thêm trigger `sales_withdrawal` (0073) + zod nhận `detail`; nay chặn |
| NVKD | Báo giá → tạo đơn (quote_to_order) → giữ chỗ FEFO → giao | ✅ |
| Nhân viên mua hàng (muahang, CCU) | /mua-hang: gợi ý ROP/MRP → tạo PO khoáng+rỉ mật 80tr → tự duyệt bị chặn (ERR_FORBIDDEN_ROLE) | ✅ |
| TGĐ (tgd) | Duyệt PO; duyệt chi >hạn mức KTT; duyệt bảng lương (kế toán tính không được tự duyệt) | ✅ |
| Thủ kho (thukho) | Nhận hàng PO → nhập kho từng dòng, sinh lô NCC/HSD, PO=ĐÃ NHẬN; kiểm kê K2; bin/putaway | ✅ (0070/0071) |
| Kế toán trưởng (ktt-tc) | Trả NCC (GL 331/112); tạo chi → tự duyệt bị chặn (ERR_SELF_APPROVE); tính lương 65 người 486tr | 🔧 tính lại lương lỗi "permission denied payslips" → grant delete (0074) |
| KTT trồng trọt (ktt-tt) | Ban hành kế hoạch cung–cầu đàn thật (7 việc → TT/CCU/D5); chạy quy trình SOP-TT-01 → bước 1 sinh việc | ✅ |
| Trưởng QA (tp-qa) | Gói audit VN-TT66 ZIP 4 MB; chạy bằng chứng sống C-MEDBOOK; ghi compliance_check | ✅ |
| Lễ tân (letan, DL) | Tạo booking phòng B1 | 🔧 thiếu `code` (API generic không tự sinh cột code) → sửa API admin: code = mã tự sinh |
| Chủ tịch (chutich) | /hq đa trại, KPI chủ, /so-do, /tuan-thu | ✅ |
| Công nhân vào /ke-toan, gọi API GL/lương | 🔧 **trước đây xem được** → thêm `src/lib/roles.ts` (VIEW_ROLES cho ~45 view tài chính/lương/nhân sự + PAGE_ROLES 12 trang) — data API trả 403, trang hiện "Không có quyền" |

Đường vào cho từng loại người dùng (trả lời câu "ở đâu?"):
- Công nhân: **Ca của tôi** → Ghi 3 chạm: mọi vị trí đều có NHẬP/XUẤT kho + form riêng (A1 cho ăn, A2 sinh sản, A3 gà/trứng, A5 nhật ký lô/tưới/sâu bệnh/thu hoạch — tự nhập kho, A6 khu D, A7 D5, A8 kho, A9 bán, A11 cổng).
- Người mua hàng/giống/thiết bị/công cụ: **/mua-hang** (gợi ý → PO mọi loại → duyệt theo ma trận → nhận = nhập kho, lô, COA, scorecard NCC, công nợ) + biểu đồ mua theo tháng/nhóm.
- Dự trữ: **/du-tru** 3 khối, nhóm dự trữ, chọn mặt hàng theo dõi, dự kiến tồn 30/60/90, cần bổ sung, biểu đồ; 📈 mỗi dòng.
- Kế hoạch: **/ke-hoach** cung–cầu (đàn → thức ăn → nguyên liệu → ha → thiếu → ban hành).

Tồn ⏳: (1) trang chưa có tài liệu hướng dẫn theo vai (chỉ /huong-dan chung); (2) approval_matrix mới áp cho CHI, PO/LUONG vẫn dùng vai cứng trong actions (đọc ma trận ở bước sau); (3) hoa hồng NVKD chưa tự vào bảng lương; (4) một số view/trang phụ (xnk/rd) vẫn qua /quan-tri.
