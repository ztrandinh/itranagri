-- 0197 · event_bus trước đây: bất kỳ lỗi xử lý nào cũng set processed_at=now() ngay lập tức — coi như
-- xong, mất luôn, không nơi nào đọc lại cột error. Đối lập với channels.ts (retry/backoff thật).
-- Thêm attempts + dead_letter_at: lỗi tạm thời được thử lại thật (unclaim), chỉ đánh dead-letter sau
-- khi vượt số lần thử — có chỗ để vận hành nhìn thấy sự kiện thật sự bị bỏ, thay vì "đã xử lý" giả.
alter table event_bus add column if not exists attempts int not null default 0;
alter table event_bus add column if not exists dead_letter_at timestamptz;
create index if not exists event_bus_dead_letter_ix on event_bus(dead_letter_at) where dead_letter_at is not null;
