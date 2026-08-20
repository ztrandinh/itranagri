# Deploy — ITRAN AGRI (Supabase + App)

Pipeline: `.github/workflows/deploy.yml`. Kích hoạt **thủ công** (Actions → *Deploy (Supabase + App)* → Run workflow → chọn `staging`/`production`). Không auto-deploy mỗi lần push `main` (repo nhiều phiên merge liên tục — tránh đẩy nửa vời).

## Ba chặng (dừng ngay nếu chặng trước đỏ)
1. **gate** — dựng lại từ Postgres trắng + `db:seed:history` + lint + tsc + test + build. Không xanh thì KHÔNG deploy (luật 9).
2. **db-push** — `supabase db push` đẩy `supabase/migrations/*.sql` lên CSDL Supabase.
3. **app** — `pnpm build`; nếu đã khai `VERCEL_TOKEN` thì deploy Vercel (không thì chỉ build kiểm).

## Secrets cần khai (Settings → Secrets and variables → Actions)
Nên khai theo **Environment** (`staging` và `production` riêng) để mỗi môi trường một CSDL/URL:

| Secret | Bắt buộc | Lấy ở đâu |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | ✅ | Supabase → Account → Access Tokens |
| `SUPABASE_PROJECT_REF` | ✅ | Supabase → Project Settings → General → Reference ID |
| `SUPABASE_DB_PASSWORD` | ✅ | Mật khẩu CSDL project (Settings → Database) |
| `VERCEL_TOKEN` | tuỳ | Vercel → Account → Tokens (bỏ trống nếu chưa host Vercel) |
| `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` | tuỳ | `npx vercel link` sinh ra ở `.vercel/project.json` |

## Chuẩn bị lần đầu (1 lần)
1. Tạo project Supabase (staging + production). Ghi lại project ref + DB password.
2. Khai secrets theo bảng trên cho từng Environment.
3. (Nếu host Vercel) `npx vercel link` để lấy ORG/PROJECT id, khai `VERCEL_TOKEN`.
4. App cần các biến chạy thật: `DATABASE_URL` (app_user), `DATABASE_ADMIN_URL`, `SESSION_SECRET` — khai ở host app (Vercel env), KHÔNG nhét vào repo.

## Rủi ro & lưu ý
- `supabase db push` là **một chiều tiến tới** — migration phải chạy sạch từ trắng (CI `rebuild-from-scratch.yml` đã canh). Không sửa migration đã đẩy; sửa = migration mới.
- Bảng sự kiện append-only + RLS đã bật — không cần thao tác thêm khi deploy.
- Deploy `production` chỉ chạy sau khi `staging` xanh (khuyến nghị quy trình: deploy staging → kiểm → deploy production).
