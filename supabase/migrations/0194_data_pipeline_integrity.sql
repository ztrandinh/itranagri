-- 0194 · Vá 2 lỗ hổng data pipeline phát hiện ở audit 5 vai trò 2026-09-01:
-- (a) webhook dispatch dùng cursor TOÀN CỤC (max(event_id) chung mọi hook) → thêm hook mới mất backfill vĩnh viễn
-- (b) ingest/sensor + webhook đơn hàng chỉ dedupe app-level (SELECT-trước-INSERT), không có constraint DB backstop

-- (a) cursor riêng theo từng webhook, advance kể cả khi event không khớp topic (tránh treo cursor ở event cũ)
alter table webhooks add column if not exists last_event_id bigint not null default 0;

-- (b) sensor_reads: dedupe theo khóa tự nhiên (farm_id, device_id, metric, ts) — gateway retry gửi lại đúng ts
-- lấy mẫu sẽ bị chặn ở DB thay vì chỉ dựa vào app không insert trùng. ts là partition key nên hợp lệ làm unique index.
create unique index if not exists sensor_reads_dedupe_ux on sensor_reads(farm_id, device_id, metric, ts);

-- (b) orders từ webhook: constraint cứng thay cho SELECT-trước-INSERT (vốn có race giữa 2 lần sàn TMĐT gọi lại)
create unique index if not exists orders_webhook_dedupe_ux on orders(farm_id, (attrs->>'source'), (attrs->>'external_id'))
  where attrs->>'external_id' is not null;
