-- 0052 · KHO RẤT CỤ THỂ: bin/kệ vị trí + tồn theo bin (putaway/pick), kiểm kê chu kỳ ABC, min/max/ROP + gợi ý PO, nhiệt độ kho lạnh (thiết bị + cảnh báo),
--        vận tải: đội xe – chuyến – điểm dừng – chuỗi lạnh, scorecard nhà cung cấp (đúng hạn/đủ số/QC/COA), thẻ kho theo lô
-- 1) Vị trí bin (kệ–tầng–ô) trong kho
create table if not exists bins(
  id text primary key, farm_id text not null references farms, warehouse_id text not null references warehouses, code text not null, zone text, aisle text, rack text, level text, position text,
  kind text default 'KE' check (kind in ('KE','SAN','PALLET','LANH','DONG','SILO','HAO','TREO','KHAC')), capacity_kg numeric, capacity_units numeric, temp_min numeric, temp_max numeric, hazmat_ok bool default false, allowed_kinds text[],
  pick_seq int default 100, active bool default true, attrs jsonb default '{}'::jsonb, unique(warehouse_id, code));
alter table bins enable row level security; drop policy if exists p_all on bins; create policy p_all on bins for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on bins to app_user;
-- inventory_moves thêm bin (nhập vào bin / xuất từ bin) — cột mới nullable, không phá luồng cũ
alter table inventory_moves add column if not exists bin_id text references bins;
alter table inventory_moves add column if not exists to_bin_id text references bins; -- di chuyển nội bộ (direction 0 không cho phép → ghi 2 dòng: -1 bin cũ, +1 bin mới, reason CHUYEN_BIN)
create index if not exists inventory_moves_bin_ix on inventory_moves(farm_id, bin_id) where bin_id is not null;
-- tồn theo bin
create or replace view v_bin_stock as
select m.farm_id, m.warehouse_id, w.code as warehouse_code, m.bin_id, b.code as bin_code, b.zone, b.pick_seq, m.sku, p.name as product_name, m.lot_id, l.expiry_date, sum(m.direction*m.qty) as qty, max(m.ts) as last_move_at
from inventory_moves m join warehouses w on w.id=m.warehouse_id join products p on p.sku=m.sku left join lots l on l.id=m.lot_id left join bins b on b.id=m.bin_id
where m.status='ACTIVE' group by m.farm_id, m.warehouse_id, w.code, m.bin_id, b.code, b.zone, b.pick_seq, m.sku, p.name, m.lot_id, l.expiry_date having sum(m.direction*m.qty) <> 0;
grant select on v_bin_stock to app_user;
-- gợi ý putaway: bin cùng SKU còn chỗ → bin trống cùng zone/loại → bin bất kỳ
create or replace function suggest_putaway(p_farm text, p_wh text, p_sku text, p_qty numeric) returns table(bin_id text, bin_code text, reason text, free_kg numeric) language sql stable as $$
  with occ as (select bin_id, sum(qty) as q, bool_or(sku=p_sku) as same from v_bin_stock where farm_id=p_farm and warehouse_id=p_wh group by bin_id)
  select b.id, b.code,
    case when o.same then 'CÙNG SKU' when o.bin_id is null then 'BIN TRỐNG' else 'CÒN CHỖ' end,
    coalesce(b.capacity_kg,1e9) - coalesce(o.q,0)
  from bins b left join occ o on o.bin_id=b.id
  where b.farm_id=p_farm and b.warehouse_id=p_wh and b.active and (b.allowed_kinds is null or (select kind from products where sku=p_sku) = any(b.allowed_kinds)) and coalesce(b.capacity_kg,1e9) - coalesce(o.q,0) >= p_qty
  order by (o.same) desc nulls last, (o.bin_id is null) desc, b.pick_seq limit 5 $$;
grant execute on function suggest_putaway(text,text,text,numeric) to app_user;
-- pick list theo bin cho đơn đã giữ chỗ (FEFO đã chọn lô ở stock_reservations → chỉ bổ sung bin theo lô, ưu tiên pick_seq)
create or replace view v_picking_bins as
select v.*, bs.bin_id, bs.bin_code, bs.zone, bs.pick_seq, bs.qty as bin_qty from v_picking v
left join lateral (select * from v_bin_stock s where s.farm_id=v.farm_id and s.sku=v.sku and s.lot_id=v.lot_id and s.qty>0 order by s.pick_seq limit 1) bs on true;
grant select on v_picking_bins to app_user;

-- 2) Min/Max/ROP theo SKU/kho + gợi ý PO
create table if not exists stock_policies(
  id text primary key, farm_id text not null references farms, sku text not null references products, warehouse_id text references warehouses,
  method text default 'ROP' check (method in ('ROP','MIN_MAX','DAYS','KANBAN')), min_qty numeric, max_qty numeric, rop_qty numeric, safety_qty numeric, lead_time_days int default 7, min_days numeric, moq numeric, order_multiple numeric,
  abc_class text check (abc_class in ('A','B','C')), count_cycle_days int, preferred_supplier_id text references partners, active bool default true, note text, attrs jsonb default '{}'::jsonb, unique(farm_id, sku, warehouse_id));
alter table stock_policies enable row level security; drop policy if exists p_all on stock_policies; create policy p_all on stock_policies for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on stock_policies to app_user;
create or replace view v_replenishment as
select sp.farm_id, sp.sku, p.name as product_name, sp.warehouse_id, sp.method, sp.min_qty, sp.max_qty, sp.rop_qty, sp.lead_time_days, sp.min_days, sp.moq, sp.order_multiple, sp.abc_class, sp.preferred_supplier_id, pt.name as supplier_name,
  coalesce(st.available,0) as available, ds.use_per_day, ds.days,
  case sp.method
    when 'MIN_MAX' then case when coalesce(st.available,0) <= coalesce(sp.min_qty,0) then greatest(coalesce(sp.max_qty,0) - coalesce(st.available,0), 0) else 0 end
    when 'DAYS' then case when coalesce(ds.days, 999) <= coalesce(sp.min_days, 0) then greatest(coalesce(ds.use_per_day,0) * (coalesce(sp.min_days,0) + sp.lead_time_days) - coalesce(st.available,0), 0) else 0 end
    else case when coalesce(st.available,0) <= coalesce(sp.rop_qty, coalesce(ds.use_per_day,0)*sp.lead_time_days + coalesce(sp.safety_qty,0)) then greatest(coalesce(sp.max_qty, coalesce(ds.use_per_day,0)*(sp.lead_time_days*2)) - coalesce(st.available,0), coalesce(sp.moq,0)) else 0 end
  end as suggest_qty
from stock_policies sp join products p on p.sku=sp.sku left join partners pt on pt.id=sp.preferred_supplier_id
left join lateral (select sum(available) as available from v_stock_available a where a.farm_id=sp.farm_id and a.sku=sp.sku and (sp.warehouse_id is null or a.warehouse_id=sp.warehouse_id)) st on true
left join v_days_of_stock ds on ds.farm_id=sp.farm_id and ds.sku=sp.sku
where sp.active;
grant select on v_replenishment to app_user;
-- ABC tự phân theo giá trị xuất 90 ngày (view tham khảo để điền abc_class)
create or replace view v_abc_suggest as
with v as (select m.farm_id, m.sku, sum(m.qty*coalesce(m.unit_cost, l.avg_cost, 0)) as val from inventory_moves m left join lots l on l.id=m.lot_id where m.status='ACTIVE' and m.direction=-1 and m.ts>now()-interval '90 days' group by m.farm_id, m.sku),
r as (select *, sum(val) over (partition by farm_id order by val desc rows unbounded preceding) / nullif(sum(val) over (partition by farm_id),0) as cum from v)
select farm_id, sku, val, round(cum*100,1) as cum_pct, case when cum<=0.8 then 'A' when cum<=0.95 then 'B' else 'C' end as abc from r;
grant select on v_abc_suggest to app_user;

-- 3) Kiểm kê chu kỳ (cycle count) — sinh việc theo abc_class/count_cycle_days; ghi kết quả vào stocktakes (append-only) như trước
create or replace function gen_cycle_counts(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; begin
  for r in select sp.sku, p.name, sp.warehouse_id, coalesce(sp.count_cycle_days, case sp.abc_class when 'A' then 30 when 'B' then 90 else 180 end) as cyc
           from stock_policies sp join products p on p.sku=sp.sku where sp.farm_id=p_farm and sp.active loop
    if not exists (select 1 from stocktakes s where s.farm_id=p_farm and s.status='ACTIVE' and s.ts > current_date - r.cyc and (r.warehouse_id is null or s.warehouse_id=r.warehouse_id) and s.lines::text like '%'||r.sku||'%')
       and not exists (select 1 from tasks t where t.farm_id=p_farm and t.kind='KIEM_KE_CHU_KY' and t.status='MO' and t.target_id=r.sku) then
      insert into tasks(id, farm_id, kind, title, due_at, role_hint, target_type, target_id, status, source)
      values (next_code_free(p_farm,'TSK'), p_farm, 'KIEM_KE_CHU_KY', 'Kiểm kê chu kỳ '||r.name||' ('||r.sku||') — chu kỳ '||r.cyc||' ngày', now()+interval '3 days', 'team_lead', 'sku', r.sku, 'MO', 'AUTO');
      n := n+1;
    end if;
  end loop; return n; end $$;
grant execute on function gen_cycle_counts(text) to app_user;

-- 4) Kho lạnh: nhiệt độ từ sensor_reads (device.location=kho) → view + cảnh báo lệch dải
alter table warehouses add column if not exists temp_min numeric; alter table warehouses add column if not exists temp_max numeric; alter table warehouses add column if not exists temp_device_id text;
update warehouses set temp_min=0, temp_max=4, temp_monitored=true where code='K6' and temp_min is null;
create or replace view v_cold_chain as
select w.farm_id, w.id as warehouse_id, w.code, w.name, w.temp_min, w.temp_max, w.temp_device_id,
  (select value from sensor_reads s where s.farm_id=w.farm_id and s.device_id=w.temp_device_id and s.metric in ('temp','temp_c','temperature') order by ts desc limit 1) as last_temp,
  (select ts from sensor_reads s where s.farm_id=w.farm_id and s.device_id=w.temp_device_id and s.metric in ('temp','temp_c','temperature') order by ts desc limit 1) as last_ts,
  (select count(*) from sensor_reads s where s.farm_id=w.farm_id and s.device_id=w.temp_device_id and s.metric in ('temp','temp_c','temperature') and s.ts>now()-interval '24 hours' and (s.value<w.temp_min or s.value>w.temp_max)) as excursions_24h
from warehouses w where w.temp_monitored;
grant select on v_cold_chain to app_user;

-- 5) Vận tải: xe – chuyến – điểm dừng – chuỗi lạnh trên xe
create table if not exists vehicles(
  id text primary key, farm_id text not null references farms, plate text not null, kind text default 'TAI' check (kind in ('TAI','LANH','BAN_TAI','MAY_KEO','XE_MAY','THUE_NGOAI','KHAC')), capacity_kg numeric, capacity_m3 numeric, refrigerated bool default false, temp_min numeric, temp_max numeric,
  driver_id text references staff, owner text default 'TRAI', insurance_due date, inspection_due date, gps_device_id text, fuel_l_per_100km numeric, odometer_km numeric, active bool default true, attrs jsonb default '{}'::jsonb, unique(farm_id, plate));
create table if not exists trips(
  id text primary key, farm_id text not null references farms, vehicle_id text references vehicles, driver_id text references staff, kind text default 'GIAO_HANG' check (kind in ('GIAO_HANG','THU_MUA','NOI_BO','KHAC')),
  planned_at timestamptz, depart_at timestamptz, return_at timestamptz, odometer_start numeric, odometer_end numeric, fuel_l numeric, cost numeric, cold_chain bool default false, temp_log jsonb default '[]'::jsonb,
  status text default 'KE_HOACH' check (status in ('KE_HOACH','DANG_DI','XONG','HUY')), route_note text, created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
create table if not exists trip_stops(
  id text primary key, trip_id text not null references trips on delete cascade, seq int not null default 1, partner_id text references partners, order_id text, address text, planned_at timestamptz, arrived_at timestamptz, left_at timestamptz,
  qty_kg numeric, cases int, pod_url text, pod_by text, temp_at_delivery numeric, status text default 'CHO' check (status in ('CHO','DA_GIAO','TU_CHOI','MOT_PHAN')), note text);
do $$ declare t text; begin
  foreach t in array array['vehicles','trips'] loop
    execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t);
    execute format('create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true)', t); execute format('grant select, insert, update on %I to app_user', t);
  end loop; end $$;
alter table trip_stops enable row level security; drop policy if exists p_all on trip_stops; create policy p_all on trip_stops for all using (exists (select 1 from trips t where t.id=trip_stops.trip_id and can_see_farm(t.farm_id))) with check (true); grant select, insert, update, delete on trip_stops to app_user;
create or replace view v_trips as
select t.*, v.plate, v.refrigerated, s.full_name as driver_name, (select count(*) from trip_stops x where x.trip_id=t.id) as stops, (select count(*) from trip_stops x where x.trip_id=t.id and x.status in ('DA_GIAO','MOT_PHAN')) as delivered,
  case when t.odometer_end is not null and t.odometer_start is not null then t.odometer_end - t.odometer_start end as km,
  case when t.odometer_end is not null and t.odometer_start is not null and t.odometer_end>t.odometer_start and t.fuel_l is not null then round(t.fuel_l*100/(t.odometer_end - t.odometer_start),1) end as l_per_100km
from trips t left join vehicles v on v.id=t.vehicle_id left join staff s on s.id=t.driver_id;
grant select on v_trips to app_user;

-- 6) Scorecard nhà cung cấp: đúng hạn (PO ts+lead vs nhập kho), đủ số, có COA, tỷ lệ QC đạt (từ lots status/attrs), giá ổn định
alter table purchase_orders add column if not exists expected_at date; alter table purchase_orders add column if not exists received_at timestamptz;
create or replace view v_supplier_scorecard as
with po as (select p.farm_id, p.supplier_id, count(*) as n_po, sum(p.total) as spend,
   avg(case when p.received_at is not null and p.expected_at is not null then (p.received_at::date <= p.expected_at)::int end) as on_time_rate,
   avg(case when p.po_status in ('NHAN','DONG','HOAN_TAT') then 1 else 0 end) as fulfilled_rate
   from purchase_orders p where p.ts > now()-interval '365 days' group by p.farm_id, p.supplier_id),
lots as (select l.farm_id, l.supplier_id, count(*) as n_lots, avg((l.coa_url is not null)::int) as coa_rate, avg((l.status not in ('HUY','TU_CHOI','CACH_LY'))::int) as qc_pass_rate from lots l where l.created_at > now()-interval '365 days' group by l.farm_id, l.supplier_id)
select pt.id as supplier_id, pt.name, pt.approved, pt.review_due, coalesce(po.farm_id, lots.farm_id) as farm_id, po.n_po, po.spend, round(po.on_time_rate*100,0) as on_time_pct, round(po.fulfilled_rate*100,0) as fulfilled_pct, lots.n_lots, round(lots.coa_rate*100,0) as coa_pct, round(lots.qc_pass_rate*100,0) as qc_pass_pct,
  round((coalesce(po.on_time_rate,0.5)*30 + coalesce(po.fulfilled_rate,0.5)*20 + coalesce(lots.coa_rate,0.5)*25 + coalesce(lots.qc_pass_rate,0.5)*25),0) as score
from partners pt left join po on po.supplier_id=pt.id left join lots on lots.supplier_id=pt.id and (po.farm_id is null or lots.farm_id=po.farm_id)
where pt.kind = 'NCC' or po.supplier_id is not null or lots.supplier_id is not null;
grant select on v_supplier_scorecard to app_user;

-- 7) Thẻ kho theo lô (stock card)
create or replace view v_stock_card as
select m.farm_id, m.warehouse_id, w.code as warehouse_code, m.sku, m.lot_id, m.ts, m.direction, m.qty, m.unit_cost, m.reason, m.from_to, m.ref_type, m.ref_id, m.bin_id, m.created_by,
  sum(m.direction*m.qty) over (partition by m.farm_id, m.warehouse_id, m.sku, m.lot_id order by m.ts, m.created_at rows unbounded preceding) as balance
from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE';
grant select on v_stock_card to app_user;
-- audit
do $$ declare t text; begin
  foreach t in array array['bins','stock_policies','vehicles','trips','trip_stops'] loop
    execute format('drop trigger if exists %s_audit on %I', t, t);
    execute format('create trigger %s_audit after insert or update or delete on %I for each row execute function itran_audit()', t, t);
  end loop; end $$;
-- cảnh báo: kho lạnh lệch dải, ROP chạm, xe hết đăng kiểm/bảo hiểm
insert into alert_rules(code, version, farm_id, name, source, expr, level, recipients, channels, cooldown_min, active)
select v.code, 1, 'GLOBAL', v.name, 'custom', v.expr::jsonb, v.level, v.rec::text[], '{app}'::text[], v.cd, true from (values
 ('AL-COLD','Kho lạnh lệch dải nhiệt','{"type":"sql_rows","sql":"select code as ref, last_temp as value, temp_min, temp_max, excursions_24h from v_cold_chain where farm_id=$1 and last_temp is not null and (last_temp<temp_min or last_temp>temp_max)","message":"Kho lạnh {ref}: {value}°C ngoài dải {temp_min}–{temp_max}°C ({excursions_24h} lần/24h) — kiểm máy, chuyển hàng, ghi INCIDENT"}','DO','{tech_head,team_lead,director}',60),
 ('AL-ROP','Chạm điểm đặt hàng lại (ROP/min)','{"type":"sql_rows","sql":"select sku as ref, product_name, available as value, suggest_qty, supplier_name from v_replenishment where farm_id=$1 and suggest_qty>0","message":"{product_name} ({ref}) tồn {value} chạm ROP — gợi ý đặt {suggest_qty} từ {supplier_name}"}','VANG','{tech_head,accountant}',1440),
 ('AL-VEHICLE-DUE','Xe hết hạn đăng kiểm/bảo hiểm ≤15 ngày','{"type":"sql_rows","sql":"select plate as ref, least(coalesce(inspection_due,''2999-01-01''),coalesce(insurance_due,''2999-01-01''))::text as value from vehicles where farm_id=$1 and active and least(coalesce(inspection_due,''2999-01-01''),coalesce(insurance_due,''2999-01-01'')) <= current_date+15","message":"Xe {ref}: đăng kiểm/bảo hiểm đến hạn {value}"}','VANG','{director,accountant}',1440)
) as v(code, name, expr, level, rec, cd) where not exists (select 1 from alert_rules a where a.code=v.code);
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values
 ('trip.departed','Chuyến xe xuất phát','CCU','{KDM,TCKT}','trips',true),('trip.delivered','Giao hàng xong (POD)','CCU','{KDM,TCKT}','trip_stops',true)
on conflict (topic) do nothing;
create or replace function itran_pub_trip() returns trigger language plpgsql as $$
begin if new.status='DANG_DI' and (tg_op='INSERT' or old.status is distinct from new.status) then perform publish_event(new.farm_id, 'trip.departed', jsonb_build_object('id', new.id, 'vehicle_id', new.vehicle_id, 'driver_id', new.driver_id)); end if;
  if new.status='XONG' and (tg_op='INSERT' or old.status is distinct from new.status) then perform publish_event(new.farm_id, 'trip.delivered', jsonb_build_object('id', new.id)); end if; return new; end $$;
drop trigger if exists pub_trip on trips; create trigger pub_trip after insert or update on trips for each row execute function itran_pub_trip();
