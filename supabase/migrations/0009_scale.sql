-- 0009 · QUY MÔ: chỉ mục · phân vùng sensor theo tháng · agg_daily · snapshot ngày · chu kỳ · khóa kỳ · tìm không dấu · sanity
create extension if not exists pg_trgm;
create extension if not exists unaccent;
create or replace function noaccent(t text) returns text language sql immutable as $$ select lower(regexp_replace(public.unaccent(coalesce(t,'')), '[đĐ]', 'd', 'g')) $$;

-- ===== CHỈ MỤC QUY MÔ =====
create index if not exists animal_events_animal_ix on animal_events(farm_id, animal_id, ts desc);
create index if not exists animal_events_group_ix on animal_events(farm_id, group_id, ts desc);
create index if not exists animal_events_type_ix on animal_events(farm_id, event_type, ts desc);
create index if not exists animal_events_by_ix on animal_events(farm_id, created_by, ts desc);
create index if not exists feed_logs_group_ix on feed_logs(farm_id, dest_group_id, ts desc);
create index if not exists feed_logs_by_ix on feed_logs(farm_id, created_by, ts desc);
create index if not exists inventory_moves_sku_ix on inventory_moves(farm_id, sku, ts desc);
create index if not exists inventory_moves_wh_ix on inventory_moves(farm_id, warehouse_id, sku, lot_id);
create index if not exists inventory_moves_lot_ix on inventory_moves(lot_id);
create index if not exists inventory_moves_by_ix on inventory_moves(farm_id, created_by, ts desc);
create index if not exists crop_logs_plot_ix on crop_logs(farm_id, plot_id, ts desc);
create index if not exists batch_logs_line_ix on batch_logs(farm_id, line, ts desc);
create index if not exists sales_partner_ix on sales(farm_id, partner_id, ts desc);
create index if not exists sales_sku_ix on sales(farm_id, sku, ts desc);
create index if not exists tasks_role_ix on tasks(farm_id, status, role_hint, due_at);
create index if not exists alerts_open_ix on alerts(farm_id, ts desc) where acked_at is null;
create index if not exists animals_farm_status_ix on animals(farm_id, status, group_id, location_id);
create index if not exists animals_search_ix on animals using gin (noaccent(coalesce(visual_tag,'')||' '||id||' '||coalesce(rfid,'')||' '||coalesce(breed,'')) gin_trgm_ops);
create index if not exists products_search_ix on products using gin (noaccent(name||' '||sku) gin_trgm_ops);
create index if not exists partners_search_ix on partners using gin (noaccent(name||' '||id||' '||coalesce(phone,'')) gin_trgm_ops);
create index if not exists animal_events_detail_gin on animal_events using gin (detail jsonb_path_ops);

-- ===== PHÂN VÙNG sensor_reads THEO THÁNG (tự tạo 14 tháng: -2 → +12) =====
create or replace function ensure_sensor_partitions() returns int language plpgsql as $$
declare d date := date_trunc('month', now())::date - interval '2 months'; n int := 0; nm text; begin
  for i in 0..14 loop
    nm := 'sensor_reads_' || to_char(d, 'YYYYMM');
    if not exists (select 1 from pg_class where relname=nm) then
      execute format('create table %I partition of sensor_reads for values from (%L) to (%L)', nm, d, (d + interval '1 month')::date); n := n + 1;
    end if;
    d := (d + interval '1 month')::date;
  end loop; return n; end $$;
-- chuyển dữ liệu default → partition đúng
do $$ begin
  create temp table _sr as select * from sensor_reads_default; delete from sensor_reads_default;
  perform ensure_sensor_partitions();
  insert into sensor_reads select * from _sr; drop table _sr;
end $$;

-- ===== CHU KỲ (vụ · lứa · pha · đợt · năm tài chính) =====
create table if not exists cycles(
  id text primary key, farm_id text not null references farms, kind text not null check (kind in ('VU','LUA','PHA','DOT','NAM_TC','KHAC')),
  name text, plot_id text references plots, group_id text references animal_groups, start_date date not null, end_date date, status text default 'MO' check (status in ('MO','DONG')),
  plan jsonb default '{}'::jsonb, summary jsonb, closed_by text, closed_at timestamptz);
alter table cycles enable row level security;
drop policy if exists p_sel on cycles; create policy p_sel on cycles for select using (can_see_farm(farm_id));
drop policy if exists p_w on cycles; create policy p_w on cycles for all using (farm_id=app_farm() and app_role() in ('team_lead','tech_head','director','owner','it_engineer')) with check (farm_id=app_farm());
grant select, insert, update on cycles to app_user;
alter table animal_groups add column if not exists cycle_id text references cycles;
alter table plots add column if not exists cycle_id text references cycles;
alter table feed_logs add column if not exists cycle_id text; alter table crop_logs add column if not exists cycle_id text; alter table batch_logs add column if not exists cycle_id text; alter table animal_events add column if not exists cycle_id text;
alter table animals add column if not exists origin_farm_id text;
alter table locations add column if not exists valid_from date default current_date, add column if not exists valid_to date;
alter table products add column if not exists replaces_sku text;
-- chu kỳ mặc định cho nhóm hiện có
insert into cycles(id,farm_id,kind,name,group_id,start_date) select g.id||'-C1', g.farm_id, case when g.kind in ('GA_THIT') then 'LUA' when g.kind='RAS' then 'DOT' else 'KHAC' end, g.name||' — đợt 1', g.id, coalesce(g.started_at, current_date) from animal_groups g where g.cycle_id is null on conflict do nothing;
update animal_groups g set cycle_id=g.id||'-C1' where cycle_id is null;
insert into cycles(id,farm_id,kind,name,plot_id,start_date) select p.id||'-V'||to_char(now(),'YYYY'), p.farm_id, 'VU', p.name||' — vụ '||to_char(now(),'YYYY'), p.id, date_trunc('year',now())::date from plots p where p.cycle_id is null on conflict do nothing;
update plots p set cycle_id=p.id||'-V'||to_char(now(),'YYYY') where cycle_id is null;

-- ===== KHÓA KỲ =====
create table if not exists period_locks(farm_id text references farms, period_end date, locked_by text, locked_at timestamptz default now(), note text, primary key(farm_id, period_end));
alter table period_locks enable row level security;
drop policy if exists p_sel on period_locks; create policy p_sel on period_locks for select using (can_see_farm(farm_id));
drop policy if exists p_w on period_locks; create policy p_w on period_locks for all using (farm_id=app_farm() and app_role() in ('director','owner','accountant')) with check (farm_id=app_farm());
grant select, insert on period_locks to app_user;
create or replace function itran_period_lock_check() returns trigger language plpgsql as $$
declare l date; begin
  select max(period_end) into l from period_locks where farm_id=new.farm_id;
  if l is not null and new.ts::date <= l and tg_table_name <> 'adjustments' and coalesce(current_setting('app.role',true),'') not in ('owner') then
    raise exception 'ERR_PERIOD_LOCKED: kỳ đến % đã khóa — dùng phiếu điều chỉnh có duyệt', l;
  end if; return new; end $$;
do $$ declare t text; begin
  for t in select unnest(array['animal_events','feed_logs','crop_logs','batch_logs','inventory_moves','sales','weigh_tickets','gate_logs','checklist_runs']) loop
    execute format('drop trigger if exists %s_lock on %I', t, t);
    execute format('create trigger %s_lock before insert on %I for each row execute function itran_period_lock_check()', t, t);
  end loop; end $$;

-- ===== SANITY: không ghi sự kiện cho con đã CHẾT/XUẤT (trừ GHI_CHU) =====
create or replace function itran_dead_check() returns trigger language plpgsql as $$
declare st text; begin
  if new.animal_id is null or new.event_type in ('GHI_CHU') then return new; end if;
  select status into st from animals where id=new.animal_id;
  if st in ('CHET','XUAT') and new.event_type not in ('CHET','XUAT') and coalesce(new.detail->>'force','')='' then raise exception 'ERR_ANIMAL_CLOSED: % đã %', new.animal_id, st; end if;
  return new; end $$;
drop trigger if exists animal_events_dead on animal_events;
create trigger animal_events_dead before insert on animal_events for each row execute function itran_dead_check();

-- ===== TỔNG HỢP NGÀY (agg_daily) & SNAPSHOT =====
create table if not exists agg_daily(farm_id text not null, day date not null, metric text not null, dim text not null default '', value numeric, n int, computed_at timestamptz default now(), primary key(farm_id, day, metric, dim));
create index if not exists agg_daily_metric_ix on agg_daily(farm_id, metric, day);
create table if not exists stock_daily(farm_id text not null, day date not null, warehouse_id text, sku text, lot_id text, qty numeric, avg_cost numeric, primary key(farm_id, day, warehouse_id, sku, lot_id));
create table if not exists herd_daily(farm_id text not null, day date not null, species text, status text, head int, est_kg numeric, value numeric, primary key(farm_id, day, species, status));
alter table agg_daily enable row level security; alter table stock_daily enable row level security; alter table herd_daily enable row level security;
do $$ declare t text; begin for t in select unnest(array['agg_daily','stock_daily','herd_daily']) loop
  execute format('drop policy if exists p_sel on %I', t); execute format('create policy p_sel on %I for select using (can_see_farm(farm_id))', t);
  execute format('drop policy if exists p_w on %I', t); execute format('create policy p_w on %I for all using (farm_id=app_farm() and app_role() in (''it_engineer'',''director'',''owner'')) with check (farm_id=app_farm())', t);
  execute format('grant select, insert, update, delete on %I to app_user', t); end loop; end $$;

create or replace function refresh_agg_daily(p_farm text, p_day date) returns int language plpgsql as $$
declare n int := 0; begin
  delete from agg_daily where farm_id=p_farm and day=p_day;
  insert into agg_daily(farm_id,day,metric,dim,value,n)
  select p_farm, p_day, m.metric, m.dim, m.v, m.n from (
    select 'feed_kg' metric, coalesce(dest_group_id,'') dim, sum(qty_kg) v, count(*) n from feed_logs where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'feed_err', coalesce(dest_group_id,''), avg(abs(qty_kg-planned_kg)/nullif(planned_kg,0))*100, count(*) from feed_logs where farm_id=p_farm and status='ACTIVE' and planned_kg>0 and ts::date=p_day group by 2
    union all select 'weight_avg', coalesce(group_id,''), avg(value), count(*) from animal_events e where farm_id=p_farm and status='ACTIVE' and event_type='CAN' and ts::date=p_day group by 2
    union all select 'deaths', coalesce(group_id,animal_id,''), sum(coalesce(value,1)), count(*) from animal_events where farm_id=p_farm and status='ACTIVE' and event_type='CHET' and ts::date=p_day group by 2
    union all select 'repro_events', event_type, count(*), count(*) from animal_events where farm_id=p_farm and status='ACTIVE' and event_type in ('DONG_DUC','PHOI','KHAM_THAI','DE','CAI_SUA') and ts::date=p_day group by 2
    union all select 'treatments', event_type, count(*), count(*) from animal_events where farm_id=p_farm and status='ACTIVE' and event_type in ('DIEU_TRI','VACCINE','BENH') and ts::date=p_day group by 2
    union all select 'eggs', coalesce(m.lot_id,''), sum(m.qty*coalesce(p.unit2_factor,1)), count(*) from inventory_moves m join products p on p.sku=m.sku where m.farm_id=p_farm and m.status='ACTIVE' and m.direction=1 and p.sku like 'SKU-TRUNG%' and m.ts::date=p_day group by 2
    union all select 'harvest_kg', coalesce(plot_id,''), sum(qty_kg), count(*) from crop_logs where farm_id=p_farm and status='ACTIVE' and activity in ('THU','CAT') and ts::date=p_day group by 2
    union all select 'machine_hours', coalesce(machine_id,''), sum(machine_hours), count(*) from crop_logs where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'fuel_l', coalesce(from_to,''), sum(qty), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=-1 and sku='NL-DAU' and ts::date=p_day group by 2
    union all select 'batch_in_kg', line, sum((i->>'kg')::numeric), count(*) from batch_logs b, jsonb_array_elements(b.inputs) i where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'batch_out_kg', line, sum((o->>'kg')::numeric), count(*) from batch_logs b, jsonb_array_elements(b.outputs) o where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'stock_in', sku, sum(qty), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=1 and ts::date=p_day group by 2
    union all select 'stock_out', sku, sum(qty), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=-1 and ts::date=p_day group by 2
    union all select 'stock_value_in', sku, sum(qty*coalesce(unit_cost,0)), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=1 and reason='NHAP_MUA' and ts::date=p_day group by 2
    union all select 'sales_amount', channel::text, sum(amount), count(*) from sales where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'sales_qty', sku, sum(qty), count(*) from sales where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'records', coalesce(u.created_by,''), count(*), count(*) from (select created_by from animal_events where farm_id=p_farm and ts::date=p_day union all select created_by from feed_logs where farm_id=p_farm and ts::date=p_day union all select created_by from crop_logs where farm_id=p_farm and ts::date=p_day union all select created_by from batch_logs where farm_id=p_farm and ts::date=p_day union all select created_by from inventory_moves where farm_id=p_farm and ts::date=p_day union all select created_by from checklist_runs where farm_id=p_farm and ts::date=p_day union all select created_by from sales where farm_id=p_farm and ts::date=p_day) u group by 2
    union all select 'alerts', level, count(*), count(*) from alerts where farm_id=p_farm and ts::date=p_day group by 2
    union all select 'gate', direction, count(*), count(*) from gate_logs where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'sensor', metric, avg(value), count(*) from sensor_reads where farm_id=p_farm and ts::date=p_day group by 2
  ) m; get diagnostics n = row_count;
  -- snapshot tồn kho & đàn cuối ngày
  delete from stock_daily where farm_id=p_farm and day=p_day;
  insert into stock_daily select p_farm, p_day, warehouse_id, sku, coalesce(lot_id,''), sum(direction*qty), null from inventory_moves where farm_id=p_farm and status='ACTIVE' and ts::date<=p_day group by warehouse_id, sku, lot_id having sum(direction*qty)<>0;
  delete from herd_daily where farm_id=p_farm and day=p_day;
  insert into herd_daily select p_farm, p_day, species, status, count(*), sum(coalesce(last_weight_kg,0)), sum(coalesce(unit_value,0)) from animals where farm_id=p_farm and status not in ('CHET','XUAT') group by species, status;
  return n; end $$;
grant execute on function refresh_agg_daily(text,date), ensure_sensor_partitions() to app_user;

-- ===== VIEW hỗ trợ tầng: đàn theo khu, con cần chú ý, tuổi nợ =====
create or replace view v_location_summary as
select l.farm_id, l.id as location_id, l.name, l.kind, l.parent_id,
  (select count(*) from animals a where a.farm_id=l.farm_id and a.location_id=l.id and a.status not in ('CHET','XUAT')) as head_individual,
  (select coalesce(sum(head_count),0) from animal_groups g where g.farm_id=l.farm_id and g.location_id=l.id and g.kind<>'BO_NHOM' and g.status='ACTIVE') as head_group,
  (select count(*) from animals a where a.farm_id=l.farm_id and a.location_id=l.id and (a.status in ('BENH','CACH_LY') or (a.withdrawal_until>current_date))) as attention,
  (select count(*) from tasks t where t.farm_id=l.farm_id and t.status='MO' and t.target_type='animal' and t.target_id in (select id from animals a where a.location_id=l.id)) as open_tasks
from locations l where l.kind in ('KHU','CHUONG','NHA','O');
create or replace view v_animals_attention as
select a.*, case when a.status in ('BENH','CACH_LY') then a.status when a.withdrawal_until>current_date then 'NGUNG_THUOC' when a.tag_pending then 'CHO_TAI'
  when exists (select 1 from tasks t where t.farm_id=a.farm_id and t.status='MO' and t.target_type='animal' and t.target_id=a.id) then 'CO_VIEC' end as attention
from animals a where a.status not in ('CHET','XUAT');
create or replace view v_receivable_aging as
select s.farm_id, s.partner_id, p.name,
  sum(s.amount) filter (where current_date - s.ts::date <= 15) as d0_15,
  sum(s.amount) filter (where current_date - s.ts::date between 16 and 30) as d16_30,
  sum(s.amount) filter (where current_date - s.ts::date > 30) as d30p, sum(s.amount) as total
from sales s join partners p on p.id=s.partner_id where s.status='ACTIVE' and not s.paid group by 1,2,3;
create or replace view v_animal_parity as
select animal_id, count(*) filter (where event_type='DE') as parity, max(ts) filter (where event_type='DE') as last_calving,
  round(avg(extract(epoch from gap))/86400) as calving_interval_days
from (select animal_id, event_type, ts, ts - lag(ts) over (partition by animal_id, event_type order by ts) as gap from animal_events where status='ACTIVE' and event_type='DE') x group by animal_id;
grant select on all tables in schema public to app_user;
