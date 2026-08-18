-- 0086 · Sửa theo rà soát từng mô-đun (docs/plan/16): (1) Đàn: lịch sinh sản & hành động hôm nay tự sinh; (2) Canh tác: giá thành theo ô/vụ; (3) Kho: giá trị tồn kho theo kho/nhóm; (4) Du lịch: công suất phòng theo tháng; (5) Thú y: danh sách đang ngưng thuốc
-- (1) ĐÀN — hành động cần làm theo từng con: khám thai (phối +60 ngày), dự kiến đẻ (phối +283 −14 chuẩn bị), tái phối (đẻ +60), cai sữa (bê 180 ngày), cân đến hạn (>14 ngày), vaccine (schedule), loại thải đề xuất (không đậu ≥3 lần / nái >8 tuổi), vỗ béo đủ ngày xuất
create or replace view v_herd_actions as
with a as (select * from animals where status not in ('CHET','XUAT','LOAI')),
lastev as (select animal_id, event_type, max(ts) as ts from animal_events where status='ACTIVE' group by 1,2),
phoi as (select animal_id, ts from lastev where event_type='PHOI'), de as (select animal_id, ts from lastev where event_type='DE'), kt as (select animal_id, ts from lastev where event_type='KHAM_THAI'), can as (select animal_id, ts from lastev where event_type='CAN'),
fails as (select animal_id, count(*) n from animal_events where event_type='KHAM_THAI' and detail->>'result'='-' and ts>now()-interval '18 months' group by 1)
select a.farm_id, a.id as animal_id, a.visual_tag, a.species, derive_class(a.species,a.sex,a.birth_date,a.class_code) as class_code, x.action, x.due, x.note, x.priority
from a
cross join lateral (
  select 'KHAM_THAI' as action, (p.ts::date + 60) as due, 'Phối '||p.ts::date||' → khám thai sau 60 ngày' as note, 'CAO' as priority from phoi p where p.animal_id=a.id and a.sex='F' and (select ts from kt where kt.animal_id=a.id) is distinct from null and coalesce((select ts from kt where kt.animal_id=a.id) < p.ts, true) and (select ts from de where de.animal_id=a.id) is distinct from null and coalesce((select ts from de where de.animal_id=a.id) < p.ts, true)
  union all select 'KHAM_THAI', (p.ts::date + 60), 'Phối '||p.ts::date||' → khám thai', 'CAO' from phoi p where p.animal_id=a.id and a.sex='F' and not exists (select 1 from kt where kt.animal_id=a.id and kt.ts > p.ts) and not exists (select 1 from de where de.animal_id=a.id and de.ts > p.ts)
  union all select 'CHUAN_BI_DE', (p.ts::date + 283 - 14), 'Dự kiến đẻ '||(p.ts::date+283)||' — chuyển chuồng đẻ, ổ úm', 'CAO' from phoi p join kt on kt.animal_id=p.animal_id and kt.ts>p.ts where p.animal_id=a.id and a.sex='F' and not exists (select 1 from de where de.animal_id=a.id and de.ts>p.ts) and exists (select 1 from animal_events e where e.animal_id=a.id and e.event_type='KHAM_THAI' and e.ts=kt.ts and coalesce(e.detail->>'result','+') in ('+','CO','DUONG'))
  union all select 'TAI_PHOI', (d.ts::date + 60), 'Đẻ '||d.ts::date||' → theo dõi động dục & phối lại', 'TRUNG' from de d where d.animal_id=a.id and a.sex='F' and not exists (select 1 from phoi p where p.animal_id=a.id and p.ts>d.ts)
  union all select 'CAI_SUA', (a.birth_date + 180), 'Bê đủ 6 tháng — cai sữa, chuyển hạng tơ', 'TRUNG' where a.species='BO' and a.birth_date is not null and current_date - a.birth_date between 170 and 200 and a.status='THEO_ME'
  union all select 'CAN', coalesce((select ts::date from can where can.animal_id=a.id),a.created_at::date) + 14, 'Cân định kỳ 14 ngày', 'THAP' where a.species='BO' and coalesce((select ts::date from can where can.animal_id=a.id), a.created_at::date) + 14 <= current_date + 3
  union all select 'LOAI_THAI', current_date, 'Không đậu thai '||f.n||' lần/18 tháng — đề xuất loại thải', 'TRUNG' from fails f where f.animal_id=a.id and f.n>=3
  union all select 'LOAI_THAI', current_date, 'Nái > 8 tuổi — xét loại thải', 'THAP' where a.species='BO' and a.sex='F' and a.birth_date < current_date - interval '8 years'
  union all select 'XUAT_VO_BEO', a.created_at::date + 180, 'Vỗ béo đủ 180 ngày — chốt bán (kiểm ngưng thuốc)', 'CAO' where derive_class(a.species,a.sex,a.birth_date,a.class_code)='BO-VO-BEO' and a.created_at::date + 180 <= current_date + 30
  union all select 'NGUNG_THUOC', a.withdrawal_until, 'Đang ngưng thuốc đến '||a.withdrawal_until||' — không xuất', 'CAO' where a.withdrawal_until is not null and a.withdrawal_until >= current_date
) x
where x.due <= current_date + 30;
grant select on v_herd_actions to app_user;
create or replace function gen_herd_actions(p_farm text) returns int language plpgsql as $$
declare r record; n int := 0; begin
  for r in select * from v_herd_actions where farm_id=p_farm and due <= current_date + 3 and action not in ('NGUNG_THUOC','CAN') loop
    if not exists (select 1 from tasks t where t.farm_id=p_farm and t.kind='DAN_'||r.action and t.target_id=r.animal_id and t.status='MO') then
      insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority)
      values (gen_random_uuid(), p_farm, 'DAN_'||r.action, r.action||' '||coalesce(r.visual_tag, r.animal_id)||' — '||r.note, jsonb_build_object('animal_id', r.animal_id, 'action', r.action, 'text', r.note), r.due::timestamptz + interval '8 hours', case r.action when 'XUAT_VO_BEO' then 'director' when 'LOAI_THAI' then 'tech_head' else 'worker' end, 'animal', r.animal_id, 'MO', 'HERD', case r.priority when 'CAO' then 'CAO' when 'TRUNG' then 'BINH_THUONG' else 'THAP' end);
      n := n+1;
    end if;
  end loop; return n; end $$;
grant execute on function gen_herd_actions(text) to app_user;
-- (2) CANH TÁC — giá thành theo ô/vụ: vật tư (crop_inputs × giá mua), máy (giờ × dầu × giá), tưới (điện), công (giờ máy×đơn giá công settings) / sản lượng
create or replace view v_plot_cost as
select cs.farm_id, cs.id as season_id, cs.code, cs.plot_id, p.name as plot_name, cs.crop, cs.crop_code, cs.area_ha, cs.sow_date, cs.status, coalesce(cs.actual_yield_kg,0) as yield_kg,
  coalesce((select sum(ci.qty * coalesce((select avg(m.unit_cost) from inventory_moves m where m.sku=ci.sku and m.reason='NHAP_MUA' and m.unit_cost>0), (select ref_price from products where sku=ci.sku), 3000)) from crop_inputs ci where ci.season_id=cs.id and ci.status='ACTIVE'),0) as input_cost,
  coalesce((select sum(cl.fuel_l)*setting_num('price.diesel', cs.farm_id, 21000) + sum(cl.machine_hours)*setting_num('cost.machine_hour', cs.farm_id, 150000) from crop_logs cl where cl.plot_id=cs.plot_id and cl.ts::date between cs.sow_date and coalesce(cs.harvest_end, current_date) and cl.status='ACTIVE'),0) as machine_cost,
  coalesce((select sum(ir.energy_kwh)*setting_num('price.kwh', cs.farm_id, 2500) + count(*)*setting_num('cost.irrigation_turn', cs.farm_id, 50000) from irrigation_logs ir where ir.plot_id=cs.plot_id and ir.ts::date between cs.sow_date and coalesce(cs.harvest_end, current_date) and ir.status='ACTIVE'),0) as water_cost,
  coalesce((select count(*)*setting_num('cost.labor_turn', cs.farm_id, 250000) from crop_logs cl where cl.plot_id=cs.plot_id and cl.ts::date between cs.sow_date and coalesce(cs.harvest_end, current_date) and cl.status='ACTIVE'),0) as labor_cost
from crop_seasons cs join plots p on p.id=cs.plot_id where cs.status<>'HUY';
grant select on v_plot_cost to app_user;
insert into settings(farm_id, key, value) select 'GLOBAL', k, v::jsonb from (values ('price.diesel','21000'),('cost.machine_hour','150000'),('price.kwh','2500'),('cost.irrigation_turn','50000'),('cost.labor_turn','250000')) v(k,v) where not exists (select 1 from settings s where s.key=v.k and s.farm_id='GLOBAL');
-- (3) KHO — giá trị tồn kho theo kho / nhóm dự trữ (giá bình quân lô hoặc giá mua gần nhất)
create or replace view v_stock_value as
select a.farm_id, a.warehouse_code, w.block, p.stock_group, g.name as group_name, a.sku, a.product_name, sum(a.available) as qty, p.unit,
  round(sum(a.available * coalesce(a.avg_cost, (select avg(m.unit_cost) from inventory_moves m where m.sku=a.sku and m.reason='NHAP_MUA' and m.unit_cost>0), p.ref_price, 0))) as value
from v_stock_available a join products p on p.sku=a.sku left join stock_groups g on g.code=p.stock_group join warehouses w on w.id=a.warehouse_id where a.available>0 group by 1,2,3,4,5,6,7,9;
grant select on v_stock_value to app_user;
-- (4) DU LỊCH — công suất phòng theo tháng
create or replace view v_occupancy_month as
select r.farm_id, date_trunc('month', d.d)::date as month, count(distinct r.id) as rooms, count(b.id) as room_nights, round(100.0*count(b.id)/nullif(count(distinct r.id)*max(extract(day from (date_trunc('month', d.d) + interval '1 month - 1 day'))),0),1) as occupancy_pct, sum(b.rate) as room_revenue
from generate_series(current_date - interval '13 months', current_date + interval '2 months', '1 day') d(d) cross join hosp_rooms r
left join hosp_bookings b on b.room_id=r.id and b.status in ('DAT','CHECKIN','CHECKOUT') and d.d::date >= b.check_in and d.d::date < b.check_out
where r.active group by 1,2;
grant select on v_occupancy_month to app_user;
