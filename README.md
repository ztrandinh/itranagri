# ITRAN AGRI — Hệ điều hành số trang trại tuần hoàn ITRAN FARM

Ray A (thực chiến): Next.js 16 · TypeScript · Postgres 17 (Supabase-ready, SQL migrations thuần) · offline-first PWA · RLS đa trại.

- Kế hoạch tổng thể & kiến trúc: [`docs/plan/README.md`](docs/plan/README.md)
- Nghiệp vụ gốc (5 trục · 5 phòng · 14 vai · 9 kho · RC1–RC10): [`docs/bo-goc/`](docs/bo-goc/)
- Luật làm việc với Claude Code: [`CLAUDE.md`](CLAUDE.md)

## Chạy nhanh
```bash
docker run -d --name itranos_db -e POSTGRES_PASSWORD=itranos -e POSTGRES_DB=itranos -p 54499:5432 public.ecr.aws/supabase/postgres:17.6.1.155
docker exec itranos_db psql -U supabase_admin -d itranos -c "alter role postgres superuser;"
pnpm i && cp .env.example .env && pnpm db:migrate && pnpm db:seed:sim 30 && pnpm dev --port 3111
```
Đăng nhập: `owner` / `gd` / `ktt-cn` / `a1…a11` / `audit` — PIN `1234`.

## Có gì
Đợt hoàn thiện: kế hoạch vụ/cho ăn (KH vs thực) · đơn hàng ≤15h → lệnh SX · hợp đồng bao tiêu · nhận nuôi/chăm sóc hộ · thú y (theo dõi, ngưng thuốc, lịch vaccine, phác đồ) · nhân sự (chứng chỉ SOP, sức khỏe, hoạt động) · thiết bị (giờ máy, bảo dưỡng, cảm biến, job log) · kế toán (bảng kê, khóa kỳ, chi 2 chữ ký, quỹ, tồn tại ngày, tuổi nợ) · quy mô: phân trang server, tầng khu→đàn→cá thể, agg_daily, snapshot ngày, chu kỳ, phân vùng cảm biến.

Việc hôm nay theo vai · ghi 3 chạm offline · định danh vật nuôi 3 cấp · kho K1–K9 sổ cái tự động · phiếu giấy↔số (RC11) · đối soát RC1–RC12 · cảnh báo · KPI/1 trang thứ 6 · số liệu vẽ mọi chỉ số + drill 2 chạm · truy xuất 1-lùi-1-tiến + QR công khai + EPCIS 2.0 · SOP 10+1 · bán hàng/công nợ/giá sàn · PO/đề nghị chi 2 chữ ký · công ty mẹ đa trại · trung tâm xuất dữ liệu (audit pack, TT 66/2025, bảng kê thuế) · sức khỏe hệ thống (7 bộ chất vấn).
