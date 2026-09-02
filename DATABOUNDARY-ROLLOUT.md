# DataBoundary rollout — checklist theo dõi

15/46 panel đã dùng `DataBoundary` (rà lại — checklist gốc ghi "1/37" đã lỗi thời). Còn lại 31 file,
trong đó 4 file không có data fetch dạng danh sách (Home/HuongDan/FarmProfile/DesignSystem) — không áp
dụng. Còn **27 file cần xử lý thật**, xếp theo độ lớn (nhỏ → lớn) để làm dần, kiểm chứng liên tục.

- [x] Pedigree.tsx (22 dòng) — PedigreePanel (2 khối) + EpiPanel (2 bảng)
- [x] TaiKhoan.tsx (25 dòng)
- [x] Finance.tsx (26 dòng) — BudgetPanel + CashflowPanel
- [x] PayrollAssets.tsx (26 dòng) — PayrollPanel + AssetsPanel
- [x] PheDuyet.tsx (27 dòng) — helper `Sec` dùng chung cho 7 khối, thêm loading/error/onRetry props
- [x] DaoTaoThuong.tsx (28 dòng) — 4 tab (tuan/nangluc/thuong/so)
- [x] GiayPanel.tsx (30 dòng)
- [x] MuaHang.tsx (37 dòng) — 3 bảng (goiy/ds/bieudo); bỏ qua bảng "tao"/"nhan" (state cục bộ, không phải async list)
- [x] Fulfillment.tsx (41 dòng) — ReturnsPanel + ProductionPanel (2 bảng)
- [x] DuLich.tsx (44 dòng) — bookings/events/tours/occm (4 bảng chính); bỏ qua sơ đồ phòng dạng thẻ + list dv (rủi ro thấp hơn, không phải bảng)
- [x] HerdIntake.tsx (44 dòng) — MonitoringRing (HerdIntake form chính không có async list, bỏ qua)
- [ ] Obj360.tsx (44 dòng — fetch tay, không qua useData, cần wiring loading/error riêng)
- [x] KinhDoanh.tsx (45 dòng) — CrmPanel + PosPanel(receipts) + KenhPanel
- [x] SinhHoc.tsx (51 dòng) — bảng theo dây chuyền + luống trùn
- [x] AnimalDetail.tsx (54 dòng) — thêm loading/error cho fetch tay (ev), bảng hồ sơ sự kiện
- [x] DoiTuong.tsx (55 dòng) — 4 bảng vận hành chính (staff/bySpecies/objCrops/products); bỏ qua bảng danh mục tĩnh (roles/positions/species-def/classes/crops-def/kinds) ít rủi ro hơn
- [x] Company.tsx (61 dòng) — bảng nhân sự tab "ns"
- [ ] SoLieuPanel.tsx (64 dòng — fetch tay + state riêng, cần wiring loading/error riêng)
- [x] Notify.tsx (68 dòng) — bảng danh mục luật cảnh báo
- [x] ToChuc.tsx (70 dòng) — bảng event bus (tab bus); các bảng khác là danh mục/tham chiếu tĩnh, rủi ro thấp hơn, bỏ qua
- [x] MeterReading.tsx (75 dòng) — bảng số đọc chính + bảng khâu ghi chép quá hạn (2/4 bảng, 2 bảng còn lại ưu tiên thấp hơn)
- [x] Marketing.tsx (85 dòng) — bảng chiến dịch + bảng lắng nghe/khủng hoảng
- [x] QuanTri.tsx (93 dòng) — bảng danh sách chính (thêm loading state cho fetch tay)
- [ ] KhoPanel.tsx (97 dòng — đã lazy-fetch theo tab ở PR #68, giờ thêm DataBoundary cho từng tab)
- [x] KhoPanel.tsx (97 dòng) — thêm DataBoundary cho bảng tồn kho chính (tab "ton"), bổ sung vào lazy-fetch đã có ở PR #68
- [x] ProcessDesigner.tsx (98 dòng) — bảng các bước quy trình
- [x] More.tsx (106 dòng) — GlPanel(tb) + AttendancePanel(today), 2/nhiều bảng ưu tiên cao nhất
- [x] Depts.tsx (127 dòng) — ThuYPanel(board) + NhanSuPanel(staff) + KeToanPanel(expense), 3/nhiều bảng ưu tiên cao nhất (y tế/nhân sự/tài chính)

**Không áp dụng** (không fetch danh sách): Home.tsx, HuongDan.tsx, FarmProfile.tsx, DesignSystem.tsx.

**Quy tắc khi sửa mỗi file:**
1. Đọc toàn bộ file trước khi sửa — xác định đúng khối `.rows.map(...)` nào tương ứng useData nào.
2. Bọc DataBoundary CHỈ quanh phần list/table (không bọc cả header/toolbar/form phía trên).
3. `emptyText` phải mô tả đúng ngữ cảnh (không dùng chung 1 câu cho mọi bảng).
4. Không đổi cấu trúc bảng/markup bên trong — chỉ thêm lớp bọc.
5. Sau mỗi ~5 file: chạy `tsc --noEmit`; sau khi xong: build + soi trực quan qua browser 1 mẫu đại diện mỗi cỡ file.
