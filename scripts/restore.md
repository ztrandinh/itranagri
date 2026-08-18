# Diễn tập phục hồi (Restore drill) — làm mỗi quý, ghi vào compliance_checks (ICFS 6.4)

## Sao lưu đang có
- `backups/itranos-YYYY-MM-DD.dump` (pg_dump -Fc toàn DB) và `backups/{FARM}/{FARM}-YYYY-MM-DD.zip` (CSV mọi bảng + MANIFEST sha256) — cả ở `BACKUP_DIR` (ổ khác/NAS).
- Job: 01:15 hằng đêm (`instrumentation.ts`) hoặc `POST /api/jobs/backup?farm=F01` (x-job-key).

## Phục hồi thử vào DB tạm (không đụng DB thật)
```bash
docker exec itranos_db psql -U postgres -c "drop database if exists itranos_restore; create database itranos_restore"
cat backups/itranos-2026-08-18.dump | docker exec -i itranos_db sh -c "cat > /var/lib/postgresql/r.dump"
docker exec itranos_db pg_restore -U postgres -d itranos_restore --no-owner /var/lib/postgresql/r.dump
docker exec itranos_db psql -U postgres -d itranos_restore -c "select count(*) animals from animals; select max(ts) last_event from animal_events;"
```
Kiểm: số con, sự kiện cuối, sổ cái cân (`select sum(debit)-sum(credit) from v_gl_ledger`) trùng DB thật tại thời điểm dump → ĐẠT. Ghi kết quả vào /tuan-thu (ITRAN-STD 6.4).

## Phục hồi thật (sự cố)
1. Dừng app; 2. `pg_restore -c -d itranos` bản dump gần nhất; 3. chạy `pnpm db:migrate` (bù migration mới); 4. bật app, kiểm `/api/health`; 5. bù dữ liệu từ hàng đợi offline điện thoại (tự đồng bộ) và phiếu giấy.
