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
- **Gate staging → production là kỹ thuật, không chỉ khuyến nghị**: deploy `staging` thành công tự đánh git tag `staging-verified` vào đúng commit; deploy `production` bắt buộc commit đó phải có tag này, nếu không job `staging-gate` chặn ngay trước `db-push`. Lối thoát khẩn cấp: tick `skip_staging_gate` khi chạy workflow — cố ý phải tự tay bật, không có bypass ngầm.

## Cron đêm khi deploy qua Vercel
`instrumentation.ts` (`setInterval`) chỉ đúng khi có 1 process chạy dài (Docker) — Vercel serverless không hỗ trợ. `vercel.json` khai `crons` gọi lại đúng các job (`dispatch` mỗi phút, `cache` mỗi 5', `all`+`backup` 01:15 ICT, `tasks` 06:00 ICT, `maint` Chủ nhật 02:30 ICT — quy đổi UTC sẵn trong file). Cần khai thêm 1 biến môi trường ở Vercel (ngoài bảng secrets ở trên, đây là **biến app**, không phải secret Actions):

| Biến | Bắt buộc nếu deploy Vercel | Ghi chú |
|---|---|---|
| `CRON_SECRET` | ✅ | Chuỗi ngẫu nhiên mạnh tự đặt ở Vercel Project Settings → Environment Variables. Vercel tự gửi `Authorization: Bearer $CRON_SECRET` khi gọi cron — route `/api/jobs/[job]` đã hỗ trợ song song với `x-job-key` (Docker) và session (chạy tay). |

Deploy Docker: bỏ qua mục này, giữ nguyên `SCHEDULER=1` như cũ, không cần `vercel.json`/`CRON_SECRET`.
