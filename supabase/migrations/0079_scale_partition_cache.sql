-- 0079 · PHÂN LUỒNG DỮ LIỆU LỚN & VIEW NẶNG
-- (1) stock_daily: chỉ lưu dòng THAY ĐỔI so hôm trước (delta) + snapshot cuối tháng đầy đủ; phân vùng theo tháng; index theo sku
-- (2) event_bus, audit_log: phân vùng theo tháng; retention (event_bus đã xử lý >6 tháng → xóa; audit_log >24 tháng → bảng lạnh audit_log_cold)
-- (3) View "sống" nặng (v_stock_dashboard, dự báo đàn/thức ăn, giám sát tuần) → bảng cache theo trại, làm mới theo job/khi có sự kiện, API đọc cache (TTL) + nút làm mới
-- (4) hàm bảo trì: ensure_partitions() + retention() + analyze — chạy job tuần
-- ---------- helper: tạo phân vùng tháng cho bảng partition by range(ts/day) ----------
create or replace function ensure_month_partitions(p_table text, p_col text, p_back int default 36, p_ahead int default 3) returns int language plpgsql as $$
declare d date; nm text; n int := 0; begin
  for i in -p_back..p_ahead loop
    d := (date_trunc('month', current_date) + (i||' months')::interval)::date; nm := p_table||'_'||to_char(d,'YYYYMM');
    if to_regclass(nm) is null then execute format('create table %I partition of %I for values from (%L) to (%L)', nm, p_table, d, (d + interval '1 month')::date); n := n+1; end if;
  end loop; return n; end $$;
-- ---------- (2a) event_bus → partitioned ----------
do $$ begin
  if not exists (select 1 from pg_partitioned_table where partrelid='event_bus'::regclass) then
    create table event_bus_p (like event_bus including defaults including constraints) partition by range (ts);
    alter table event_bus_p add primary key (id, ts);
    perform ensure_month_partitions('event_bus_p','ts',36,3);
    execute 'create table event_bus_p_default partition of event_bus_p default';
    insert into event_bus_p select * from event_bus;
    alter table event_bus rename to event_bus_old; alter table event_bus_p rename to event_bus;
    -- đổi tên phân vùng cho gọn
    perform 1;
    create index if not exists event_bus_unprocessed on event_bus (ts) where processed_at is null;
    create index if not exists event_bus_topic_ix on event_bus (farm_id, topic, ts desc);
    alter table event_bus enable row level security;
    create policy p_sel on event_bus for select using (can_see_farm(farm_id) or farm_id is null); create policy p_w on event_bus for all using (true) with check (true);
    grant select, insert, update, delete on event_bus to app_user;
    -- sequence: chuyển ownership
    execute 'alter sequence if exists event_bus_id_seq owned by event_bus.id';
    drop table event_bus_old;
  end if;
end $$;
-- ---------- (2b) audit_log → partitioned + bảng lạnh ----------
do $$ begin
  if not exists (select 1 from pg_partitioned_table where partrelid='audit_log'::regclass) then
    create table audit_log_p (like audit_log including defaults including constraints) partition by range (ts);
    alter table audit_log_p add primary key (id, ts);
    perform ensure_month_partitions('audit_log_p','ts',36,3);
    execute 'create table audit_log_p_default partition of audit_log_p default';
    insert into audit_log_p select * from audit_log;
    alter table audit_log rename to audit_log_old; alter table audit_log_p rename to audit_log;
    create index if not exists audit_log_tbl on audit_log (table_name, pk, ts desc); create index if not exists audit_log_ts on audit_log (ts desc); create index if not exists audit_log_farm on audit_log (farm_id, ts desc);
    alter table audit_log enable row level security;
    create policy p_ins on audit_log for insert with check (true); create policy p_sel on audit_log for select using (app_role() in ('owner','director','it_engineer','auditor','accountant','tech_head'));
    grant select, insert on audit_log to app_user;
    execute 'alter sequence if exists audit_log_id_seq owned by audit_log.id';
    drop table audit_log_old;
  end if;
end $$;
create table if not exists audit_log_cold (like audit_log including all);
-- ---------- (1) stock_daily → delta + partition ----------
do $$ begin
  if not exists (select 1 from pg_partitioned_table where partrelid='stock_daily'::regclass) then
    create table stock_daily_p (like stock_daily including defaults) partition by range (day);
    alter table stock_daily_p add primary key (farm_id, day, warehouse_id, sku, lot_id);
    perform ensure_month_partitions('stock_daily_p','day',36,3);
    execute 'create table stock_daily_p_default partition of stock_daily_p default';
    -- chỉ giữ dòng thay đổi so hôm trước + cuối tháng đầy đủ + 90 ngày gần nhất đầy đủ
    insert into stock_daily_p
    select s.* from stock_daily s left join stock_daily p on p.farm_id=s.farm_id and p.day=s.day-1 and p.warehouse_id=s.warehouse_id and p.sku=s.sku and p.lot_id=s.lot_id
    where s.day >= current_date-90 or s.day = (date_trunc('month', s.day) + interval '1 month - 1 day')::date or p.qty is distinct from s.qty;
    alter table stock_daily rename to stock_daily_old; alter table stock_daily_p rename to stock_daily;
    create index if not exists stock_daily_sku_ix on stock_daily (farm_id, sku, day desc); create index if not exists stock_daily_wh_ix on stock_daily (farm_id, warehouse_id, day desc);
    alter table stock_daily enable row level security;
    create policy p_sel on stock_daily for select using (can_see_farm(farm_id)); create policy p_w on stock_daily for all using (farm_id=app_farm() and app_role() in ('it_engineer','director','owner')) with check (farm_id=app_farm());
    grant select, insert, update, delete on stock_daily to app_user;
    drop table stock_daily_old;
  end if;
end $$;
-- Tồn tại 1 ngày bất kỳ = dòng delta gần nhất ≤ ngày đó (thay cho snapshot đầy đủ)
create or replace function stock_at(p_farm text, p_day date) returns table(warehouse_id text, sku text, lot_id text, qty numeric) language sql stable as $$
  select distinct on (warehouse_id, sku, lot_id) warehouse_id, sku, lot_id, qty from stock_daily where farm_id=p_farm and day<=p_day order by warehouse_id, sku, lot_id, day desc $$;
grant execute on function stock_at(text,date) to app_user;
-- refresh_agg_daily: ghi delta thay vì toàn bộ (tính snapshot đầy đủ ngày p_day trong CTE, chỉ insert dòng khác hôm trước hoặc cuối tháng)
create or replace function itran_stock_daily_delta(p_farm text, p_day date) returns int language plpgsql as $$
declare n int; is_eom bool := p_day = (date_trunc('month', p_day) + interval '1 month - 1 day')::date; begin
  delete from stock_daily where farm_id=p_farm and day=p_day;
  with cur as (select warehouse_id, sku, coalesce(lot_id,'') as lot_id, sum(direction*qty) as qty from inventory_moves where farm_id=p_farm and status='ACTIVE' and ts::date<=p_day group by 1,2,3),
  prev as (select * from stock_at(p_farm, p_day-1))
  insert into stock_daily(farm_id, day, warehouse_id, sku, lot_id, qty, avg_cost)
  select p_farm, p_day, c.warehouse_id, c.sku, c.lot_id, c.qty, null from cur c left join prev p on p.warehouse_id=c.warehouse_id and p.sku=c.sku and p.lot_id=c.lot_id
  where is_eom or p_day >= current_date-90 or p.qty is distinct from c.qty
  union all
  select p_farm, p_day, p.warehouse_id, p.sku, p.lot_id, 0, null from prev p left join cur c on p.warehouse_id=c.warehouse_id and p.sku=c.sku and p.lot_id=c.lot_id where c.sku is null and p.qty<>0; -- lô về 0 → ghi 0 để stock_at đúng
  get diagnostics n = row_count; return n; end $$;
grant execute on function itran_stock_daily_delta(text,date) to app_user;
-- ---------- (3) CACHE view nặng theo trại ----------
create table if not exists cache_stock_dashboard (like v_stock_dashboard including all);
alter table cache_stock_dashboard add column if not exists refreshed_at timestamptz default now();
create table if not exists cache_kv(farm_id text not null, key text not null, payload jsonb not null, refreshed_at timestamptz default now(), primary key(farm_id, key));
alter table cache_stock_dashboard enable row level security; drop policy if exists p_sel on cache_stock_dashboard; create policy p_sel on cache_stock_dashboard for select using (can_see_farm(farm_id)); grant select on cache_stock_dashboard to app_user;
alter table cache_kv enable row level security; drop policy if exists p_sel on cache_kv; create policy p_sel on cache_kv for select using (can_see_farm(farm_id)); grant select on cache_kv to app_user;
create or replace function refresh_farm_cache(p_farm text) returns jsonb language plpgsql security definer as $$
declare n1 int; t0 timestamptz := clock_timestamp(); begin
  delete from cache_stock_dashboard where farm_id=p_farm;
  insert into cache_stock_dashboard select v.*, now() from v_stock_dashboard v where v.farm_id=p_farm; get diagnostics n1 = row_count;
  insert into cache_kv(farm_id, key, payload, refreshed_at) values
   (p_farm, 'herd_forecast_series', coalesce((select jsonb_agg(row_to_json(x)) from (select h.horizon, f.* from (values (0),(30),(60),(90)) h(horizon), lateral herd_forecast(p_farm, h.horizon) f order by f.class_code, h.horizon) x), '[]'::jsonb), now()),
   (p_farm, 'feed_forecast_series', coalesce((select jsonb_agg(row_to_json(x)) from (select h.horizon, sum(f.kg_day_forecast) as kg_day, sum(f.head_forecast) as head from (values (0),(30),(60),(90)) h(horizon), lateral feed_forecast(p_farm, h.horizon) f group by h.horizon order by h.horizon) x), '[]'::jsonb), now()),
   (p_farm, 'plan_supply_live', coalesce((select jsonb_agg(row_to_json(x)) from plan_supply(p_farm, null) x), '[]'::jsonb), now()),
   (p_farm, 'warehouse_fill', coalesce((select jsonb_agg(row_to_json(x)) from v_warehouse_fill x where x.farm_id=p_farm), '[]'::jsonb), now())
  on conflict (farm_id, key) do update set payload=excluded.payload, refreshed_at=now();
  return jsonb_build_object('rows', n1, 'ms', round(extract(epoch from clock_timestamp()-t0)*1000)); end $$;
grant execute on function refresh_farm_cache(text) to app_user;
-- làm mới "nợ" khi có sự kiện kho/đàn: đánh dấu dirty, job/API refresh nếu dirty hoặc quá TTL
create table if not exists cache_dirty(farm_id text primary key, dirty_at timestamptz default now());
grant select, insert, update, delete on cache_dirty to app_user;
create or replace function trg_cache_dirty() returns trigger language plpgsql security definer as $$
begin insert into cache_dirty(farm_id, dirty_at) values (coalesce(new.farm_id, old.farm_id), now()) on conflict (farm_id) do update set dirty_at=now(); return null; end $$;
do $$ declare t text; begin
  foreach t in array array['inventory_moves','animals','animal_events','purchase_orders','crop_seasons','production_plans','orders','stock_policies'] loop
    execute format('drop trigger if exists %s_cache_dirty on %I', t, t); execute format('create trigger %s_cache_dirty after insert or update on %I for each statement execute function trg_cache_dirty()', t, t);
  end loop; end $$;
-- ---------- (4) bảo trì ----------
create or replace function itran_maintenance() returns jsonb language plpgsql security definer as $$
declare r jsonb := '{}'::jsonb; n int; begin
  n := ensure_month_partitions('event_bus','ts',1,3) + ensure_month_partitions('audit_log','ts',1,3) + ensure_month_partitions('stock_daily','day',1,3); r := r || jsonb_build_object('partitions_created', n);
  if to_regprocedure('ensure_sensor_partitions()') is not null then perform ensure_sensor_partitions(); end if;
  delete from event_bus where processed_at is not null and ts < now() - interval '6 months'; get diagnostics n = row_count; r := r || jsonb_build_object('event_bus_purged', n);
  insert into audit_log_cold select * from audit_log where ts < now() - interval '24 months'; delete from audit_log where ts < now() - interval '24 months'; get diagnostics n = row_count; r := r || jsonb_build_object('audit_cold', n);
  delete from stock_daily s where s.day < current_date-90 and s.day <> (date_trunc('month', s.day) + interval '1 month - 1 day')::date and exists (select 1 from stock_daily p where p.farm_id=s.farm_id and p.warehouse_id=s.warehouse_id and p.sku=s.sku and p.lot_id=s.lot_id and p.day = (select max(day) from stock_daily q where q.farm_id=s.farm_id and q.warehouse_id=s.warehouse_id and q.sku=s.sku and q.lot_id=s.lot_id and q.day < s.day) and p.qty = s.qty); get diagnostics n = row_count; r := r || jsonb_build_object('stock_daily_dedup', n);
  delete from notifications where created_at < now() - interval '12 months' and read_at is not null; get diagnostics n = row_count; r := r || jsonb_build_object('notifications_purged', n);
  delete from sessions where expires_at < now() - interval '30 days';
  return r; exception when others then return r || jsonb_build_object('error', sqlerrm); end $$;
grant execute on function itran_maintenance() to app_user;
