-- 0131 — CHỐT CHẶN LÚC GHI: cấm ngày tương lai + cấm ghi lên đàn đã đóng sổ
--
-- Khoá ngoại (0127) chặn "trỏ vật KHÔNG tồn tại", nhưng chưa chặn "trỏ vật SAI TRẠNG THÁI /
-- SAI THỜI GIAN". Đo được trên dữ liệu thật: 30 bản ghi có ts tương lai, và ghi được lên đàn
-- F01-DAN-00008 (status DONG — đã loại). Chặn ngay lúc GHI rẻ hơn nhiều so với dọn về sau.

-- ── Hàm kiểm dùng chung (định nghĩa TRƯỚC mọi trigger) ──
create or replace function chk_no_future_ts(p_ts timestamptz, p_backfill boolean, p_source text)
returns void language plpgsql as $$
begin
  -- Dung sai 2 giờ cho lệch đồng hồ điện thoại; xa hơn là chặn. Giấy/nhập/backfill được ghi lùi.
  if p_ts is not null and not coalesce(p_backfill,false)
     and coalesce(p_source,'APP') not in ('PAPER','IMPORT','BACKFILL')
     and p_ts > now() + interval '2 hours' then
    raise exception 'ERR_FUTURE_TS: không ghi được mốc thời gian ở tương lai (%). Kiểm lại đồng hồ máy.', p_ts;
  end if;
end $$;

create or replace function chk_group_active(p_group text) returns void language plpgsql as $$
declare st text;
begin
  if p_group is null then return; end if;
  select status into st from animal_groups where id = p_group;
  if st in ('DONG','CLOSED','HUY') then
    raise exception 'ERR_GROUP_CLOSED: đàn % đã đóng sổ (%), không ghi thêm được. Chọn đàn đang nuôi.', p_group, st;
  end if;
end $$;

-- ── Guard riêng cho hai bảng có tham chiếu đàn ──
create or replace function trg_feed_guard() returns trigger language plpgsql as $$
begin
  perform chk_no_future_ts(new.ts, new.is_backfill, new.source);
  perform chk_group_active(new.dest_group_id);
  return new;
end $$;

create or replace function trg_animal_evt_guard() returns trigger language plpgsql as $$
begin
  perform chk_no_future_ts(new.ts, new.is_backfill, new.source);
  perform chk_group_active(new.group_id);
  return new;
end $$;

-- ── Guard chỉ-kiểm-ts cho các bảng sự kiện còn lại (đọc field qua jsonb cho gọn) ──
create or replace function trg_ts_guard_row() returns trigger language plpgsql as $$
declare j jsonb := to_jsonb(new);
begin
  perform chk_no_future_ts((j->>'ts')::timestamptz,
                           coalesce((j->>'is_backfill')::boolean, false),
                           coalesce(j->>'source','APP'));
  return new;
end $$;

-- ── Gắn trigger (giờ mọi hàm đã tồn tại) ──
drop trigger if exists feed_guard on feed_logs;
create trigger feed_guard before insert on feed_logs for each row execute function trg_feed_guard();

drop trigger if exists animal_evt_guard on animal_events;
create trigger animal_evt_guard before insert on animal_events for each row execute function trg_animal_evt_guard();

do $$ declare t text; begin
  foreach t in array array['crop_logs','batch_logs','inventory_moves','gate_logs','incidents',
                           'checklist_runs','harvests','food_samples','cold_chain_logs',
                           'calibrations','maintenance_logs','attendance_logs'] loop
    if to_regclass('public.'||t) is not null
       and exists (select 1 from information_schema.columns c where c.table_schema='public'
                    and c.table_name=t and c.column_name='ts') then
      execute format('drop trigger if exists ts_guard on %I', t);
      execute format('create trigger ts_guard before insert on %I for each row execute function trg_ts_guard_row()', t);
    end if;
  end loop;
end $$;
