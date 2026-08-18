# 17 · RÀ SOÁT KIẾN TRÚC THÔNG TIN (tên gọi · vị trí · phòng ban chủ quản · người dùng · trùng lặp · nhiệm vụ) — 19/08/2026

Nguyên tắc chốt: **menu = sơ đồ phòng ban (17 phòng)** — mỗi phòng có "phòng làm việc" riêng, tên nói đúng nhiệm vụ, không dùng viết tắt/nghề (KTT, GĐ, HQ, CO2e…) làm nhãn menu, không trang trùng, mọi trang có chủ quản.

## A. Lỗi phát hiện & cách sửa
| # | Lỗi | Sửa |
|---|---|---|
| 1 | Menu chia theo "khu vực kỹ thuật" (Sản xuất/Kho/Kinh doanh/Tài chính/Giám sát/Công ty), **không khớp 17 phòng ban** — nhân viên không biết "phòng mình ở đâu" | Menu mới 16 nhóm = phòng ban + "Của tôi" + "Điều hành". Nhãn = tên phòng đúng trong `departments` |
| 2 | **Phòng Sinh học tuần hoàn (SH, khu D: trùn – BSF – biogas – compost – IMO/EM – anolyte) KHÔNG có trang** — dữ liệu mẻ nằm lẫn trong "Chế biến › Mẻ sơ chế/sấy/đóng gói" | Trang mới **/sinh-hoc** "Sinh học tuần hoàn (khu D)": KPI phân nạp/phân trùn/BSF/điện biogas/anolyte ppm, mẻ theo dây chuyền, luống trùn, biểu đồ, CO2e chuyển về đây |
| 3 | "Chế biến" gộp **Xưởng thức ăn D5 (TMR/viên cho đàn)** với **chế biến thực phẩm** — 2 nghiệp vụ, 2 chuẩn (TACN vs ATTP) | Đổi tên trang: **"Xưởng thức ăn D5 & Chế biến"**; tab nhóm rõ "D5 · Thức ăn" và "Chế biến · Thực phẩm"; Khẩu phần tối ưu chuyển về đây (đang nằm nhầm ở Kho) |
| 4 | "Sức khỏe" (trong nhóm Sản xuất) thực chất là **sức khỏe hệ thống/chất lượng dữ liệu** — ai cũng tưởng sức khỏe đàn | Đổi tên **"Chất lượng dữ liệu · 7 bộ chất vấn"**, chuyển về Công nghệ – Dữ liệu; sức khỏe đàn nằm trong Thú y |
| 5 | "KTT", "GĐ", "HQ", "Audit", "CO2e", "Đối tượng", "In ấn", "Số liệu" — nhãn nghề/viết tắt, không tự giải thích | Đổi: "Điều hành ca (KTT)", "Bảng điều hành GĐ trại", "Công ty mẹ · đa trại", "Kiểm toán · xuất dữ liệu", "Phát thải & tuần hoàn", "Danh mục đối tượng (định nghĩa)", "In biểu mẫu · nhãn · báo cáo", "Số liệu & biểu đồ mọi trường" |
| 6 | **/sop trùng** Tổ chức › Thư viện SOP; **/so-do (sơ đồ khu/vị trí) và /ban-do (bản đồ ô thửa)** dễ nhầm | /sop chuyển hướng về /to-chuc?tab=sop; đổi nhãn "Sơ đồ khu – chuồng – vị trí" (Tổ chức/CNTB) và "Bản đồ ô thửa ruộng" (Trồng trọt) |
| 7 | **/giam-sat không có trong menu**; Tuân thủ nằm dưới "Giám sát · số liệu" | Nhóm **Chất lượng – Tuân thủ (QA)**: Giám sát & chấm điểm · Tuân thủ & chứng nhận · Truy xuất & thu hồi · Đối soát dữ liệu |
| 8 | Kế hoạch nằm trong "Sản xuất" — nhưng là công cụ **Ban điều hành** (S&OP, ngân sách) | Nhóm **Điều hành & Kế hoạch (BGĐ/GĐ trại)**: Kế hoạch (S&OP) · Bảng GĐ · Điều hành ca · Cảnh báo · Phê duyệt |
| 9 | Thiết bị nằm dưới Kho; Truy xuất/Bản đồ/In ấn nằm dưới Kho — không thuộc chuỗi cung ứng | Thiết bị → CNTB; Truy xuất → QA; Bản đồ → Trồng trọt; In ấn → Của tôi/CNTB |
| 10 | "Tài chính · nhân sự" gộp 2 phòng; "Kinh doanh · du lịch · XNK" gộp 3 phòng | Tách theo phòng: TCKT · HCNS · KDM · DL · XNK |
| 11 | Trang chủ theo khu vực dùng ZONES cũ → sẽ tự cập nhật theo menu mới | Giữ /trang-chu, đọc ZONES mới |
| 12 | Tiêu đề trang cũ chưa khớp nội dung: /ke-hoach ("vụ · cho ăn"), /kho ("K1–K9 sổ cái"), /ban-hang ("5 kênh"), /nhan-su ("chứng chỉ SOP · sức khỏe") | Cập nhật tiêu đề đúng nhiệm vụ |

## B. Kiến trúc mới (menu = phòng ban)
1. 📝 **Của tôi** — Ca của tôi · Phê duyệt · Phiếu giấy ↔ số · In biểu mẫu · Hướng dẫn · Tài khoản
2. 🎯 **Điều hành & Kế hoạch** (HĐQT/BGĐ/GĐ trại) — Trang chủ khu vực · Kế hoạch (Năm→S&OP) · Bảng điều hành GĐ · Điều hành ca (KTT) · Cảnh báo · Công ty mẹ đa trại
3. 🐄 **Chăn nuôi – Thú y** (KTCN) — Đàn · Thú y & sức khỏe đàn
4. 🌾 **Trồng trọt – Sinh khối** (TT) — Canh tác · Bản đồ ô thửa
5. ♻ **Sinh học tuần hoàn khu D** (SH) — Sinh học tuần hoàn · Phát thải & tuần hoàn (CO2e)
6. 🏭 **Xưởng thức ăn D5 & Chế biến** (D5) — D5 & Chế biến · Khẩu phần tối ưu
7. 🏬 **Chuỗi cung ứng – Kho – Mua hàng** (CCU) — Dự trữ · Kho & vận tải · Mua hàng
8. 💰 **Kinh doanh – Marketing – CSKH** (KDM) — Kinh doanh (bán hàng, khách, hợp đồng, công nợ)
9. 🏨 **Du lịch – Lưu trú – Ẩm thực** (DL) — Du lịch
10. 🌏 **Xuất nhập khẩu** (XNK) — Xuất nhập khẩu
11. 📒 **Tài chính – Kế toán** (TCKT) — Kế toán · Kiểm toán & xuất dữ liệu
12. 👥 **Hành chính – Nhân sự – Đào tạo** (HCNS) — Nhân sự & đào tạo & thưởng
13. ✅ **Chất lượng – Tuân thủ** (QA) — Giám sát & chấm điểm · Tuân thủ & chứng nhận · Truy xuất & thu hồi · Đối soát dữ liệu
14. 🔧 **Công nghệ – Thiết bị – Dữ liệu** (CNTB) — Thiết bị & IoT · Số liệu & biểu đồ · Chất lượng dữ liệu · Sơ đồ khu/vị trí · Quản trị dữ liệu
15. 🧪 **R&D · Nhân rộng – Nhượng quyền** (RD/MR) — R&D · Nhân rộng
16. 🏢 **Tổ chức – Quy trình – Danh mục** — Tổ chức & quy trình & SOP · Danh mục đối tượng
Quyền xem theo vai giữ như cũ (roles từng mục), thêm mã phòng ban để lọc "phòng của tôi" nổi lên đầu.
