-- 0186 · Guard đàn-đóng + species BỎ QUA seed/backfill (sửa rebuild==live).
--
-- rebuild-from-scratch bắt lỗi THẬT: seed 30 tháng (source='IMPORT') ghi sự kiện lịch sử vào đàn gà lứa
-- ĐÃ ĐÓNG SỔ (DONG) → chk_group_active raise ERR_GROUP_CLOSED → seed vỡ → dựng lại từ trắng thất bại.
-- (Ẩn lâu nay vì CI cấu hình sai, chưa từng chạy.) Nguyên tắc nhất quán: guard chặn GHI LIVE nhưng
-- BỎ QUA backfill/IMPORT/PAPER (giống chk_no_future_ts trong 0131). Live APP ghi lên đàn đóng vẫn bị chặn.
-- Giữ chk_feed_species (0143) cho live; cũng skip cho seed (seed data đã đúng, tránh vỡ dựng lại).

create or replace function trg_feed_guard() returns trigger language plpgsql as $$
begin
  perform chk_no_future_ts(new.ts, new.is_backfill, new.source);
  if not coalesce(new.is_backfill, false) and coalesce(new.source, 'APP') not in ('IMPORT','BACKFILL','PAPER') then
    perform chk_group_active(new.dest_group_id);
    perform chk_feed_species(new.dest_group_id, new.recipe_id);
  end if;
  return new;
end $$;

create or replace function trg_animal_evt_guard() returns trigger language plpgsql as $$
begin
  perform chk_no_future_ts(new.ts, new.is_backfill, new.source);
  if not coalesce(new.is_backfill, false) and coalesce(new.source, 'APP') not in ('IMPORT','BACKFILL','PAPER') then
    perform chk_group_active(new.group_id);
  end if;
  return new;
end $$;
