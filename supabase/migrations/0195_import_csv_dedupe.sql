-- 0195 · import/csv không dedupe theo nội dung file (batchId là UUID mới mỗi lần POST) — double-click/
-- double-submit đúng file CSV lần 2 tạo dữ liệu trùng, khác hẳn /api/events (idempotent theo client_ref).
alter table import_batches add column if not exists content_hash text;
create unique index if not exists import_batches_dedupe_ux on import_batches(farm_id, table_name, content_hash)
  where content_hash is not null and reverted_at is null;
