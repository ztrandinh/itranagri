-- 0004 · VIEWS tự sinh (báo cáo = view, không form)
-- Thẻ kho & tồn
create or replace view v_stock_ledger as
select m.farm_id, m.warehouse_id, m.sku, m.lot_id, m.ts, m.direction, m.qty, m.unit_cost, m.reason, m.from_to, m.weigh_point, m.id,
       sum(m.direction*m.qty) over (partition by m.farm_id, m.warehouse_id, m.sku, m.lot_id order by m.ts, m.created_at rows unbounded preceding) as balance_after
from inventory_moves m where m.status='ACTIVE';

create or replace view v_stock_balance as
select m.farm_id, m.warehouse_id, w.code as warehouse_code, m.sku, p.name as product_name, p.unit, m.lot_id, l.expiry_date, l.status as lot_status,
       sum(m.direction*m.qty) as qty,
       case when sum(case when m.direction=1 then m.qty end) > 0
            then sum(case when m.direction=1 then m.qty*coalesce(m.unit_cost,0) end)/nullif(sum(case when m.direction=1 then m.qty end),0) end as avg_cost,
       max(m.ts) as last_move_at
from inventory_moves m
join warehouses w on w.id=m.warehouse_id
left join products p on p.sku=m.sku
left join lots l on l.id=m.lot_id
where m.status='ACTIVE'
group by m.farm_id, m.warehouse_id, w.code, m.sku, p.name, p.unit, m.lot_id, l.expiry_date, l.status;

-- Ngày-tồn ủ chua: tồn K3 / tiêu thụ TB 14 ngày (feed_logs)
create or replace view v_days_silage as
with stock as (
  select b.farm_id, sum(b.qty) as k3_kg from v_stock_balance b where b.warehouse_code='K3' group by b.farm_id),
use14 as (
  select f.farm_id, sum(f.qty_kg)/14.0 as kg_per_day from feed_logs f where f.status='ACTIVE' and f.ts >= now() - interval '14 days' group by f.farm_id)
select fm.id as farm_id, coalesce(s.k3_kg,0) as k3_kg, coalesce(u.kg_per_day,0) as kg_per_day,
       case when coalesce(u.kg_per_day,0)>0 then round(coalesce(s.k3_kg,0)/u.kg_per_day,1) end as days_silage
from farms fm left join stock s on s.farm_id=fm.id left join use14 u on u.farm_id=fm.id;

-- Sổ đàn K8
create or replace view v_herd as
select a.farm_id, a.species, a.status, count(*) as head_count, sum(coalesce(a.last_weight_kg,0)) as est_kg, sum(coalesce(a.unit_value,0)) as value
from animals a where a.status not in ('CHET','XUAT') group by a.farm_id, a.species, a.status;
create or replace view v_herd_value as
select farm_id, sum(head_count) as head_count, sum(est_kg) as est_kg, sum(value) as value from v_herd group by farm_id;

-- KPI: đậu thai / phối (12 tháng)
create or replace view v_kpi_conception as
select farm_id,
  count(*) filter (where event_type='KHAM_THAI' and coalesce(detail->>'result','')='+') as preg_pos,
  count(*) filter (where event_type='PHOI') as services,
  round(100.0*count(*) filter (where event_type='KHAM_THAI' and coalesce(detail->>'result','')='+')/nullif(count(*) filter (where event_type='PHOI'),0),1) as conception_pct
from animal_events where status='ACTIVE' and ts >= now()-interval '12 months' group by farm_id;
-- KPI: bê cai sữa / nái / năm
create or replace view v_kpi_weaned_per_dam as
select e.farm_id,
  count(*) filter (where e.event_type='CAI_SUA') as weaned_12m,
  (select count(*) from animals a where a.farm_id=e.farm_id and a.species='BO' and a.sex='F' and a.status in ('HAU_BI','PHOI','KHAM_THAI','MANG_THAI','DE','NUOI_CON','CAI_SUA','CHO_PHOI')) as dams,
  round(count(*) filter (where e.event_type='CAI_SUA')::numeric / nullif((select count(*) from animals a where a.farm_id=e.farm_id and a.species='BO' and a.sex='F' and a.status in ('HAU_BI','PHOI','KHAM_THAI','MANG_THAI','DE','NUOI_CON','CAI_SUA','CHO_PHOI')),0),2) as weaned_per_dam
from animal_events e where e.status='ACTIVE' and e.ts >= now()-interval '12 months' group by e.farm_id;
-- KPI: sai số mẻ TMR (feed_logs planned vs actual)
create or replace view v_kpi_feed_accuracy as
select farm_id, date_trunc('day', ts)::date as day, round(avg(abs(qty_kg-planned_kg)/nullif(planned_kg,0))*100,2) as err_pct, count(*) as batches
from feed_logs where status='ACTIVE' and planned_kg is not null group by farm_id, date_trunc('day', ts);
-- KPI: chết đàn nhóm (gà) tháng
create or replace view v_kpi_group_mortality as
select e.farm_id, e.group_id, date_trunc('month', e.ts)::date as month, sum(e.value) filter (where e.event_type='CHET') as dead,
  max(g.head_count) as head, round(100.0*sum(e.value) filter (where e.event_type='CHET')/nullif(max(g.head_count),0),2) as pct
from animal_events e join animal_groups g on g.id=e.group_id where e.status='ACTIVE' group by e.farm_id, e.group_id, date_trunc('month', e.ts);
-- Trứng: tỷ lệ đẻ (nhập K5 trứng / mái)
create or replace view v_kpi_lay_rate as
select m.farm_id, date_trunc('day', m.ts)::date as day, sum(m.qty) as eggs,
  (select sum(head_count) from animal_groups g where g.farm_id=m.farm_id and g.kind='GA_DE' and g.status='ACTIVE') as hens,
  round(100.0*sum(m.qty)/nullif((select sum(head_count) from animal_groups g where g.farm_id=m.farm_id and g.kind='GA_DE' and g.status='ACTIVE'),0),1) as lay_pct
from inventory_moves m join products p on p.sku=m.sku where m.status='ACTIVE' and m.direction=1 and m.reason='NHAP_SX' and p.sku like 'SKU-TRUNG%' group by m.farm_id, date_trunc('day', m.ts);

-- Cân bằng vật chất tuần (6 dòng)
create or replace view v_material_balance_week as
select f.id as farm_id, date_trunc('week', now())::date as week,
 (select coalesce(sum(qty_kg),0) from crop_logs c where c.farm_id=f.id and c.status='ACTIVE' and c.activity in ('THU','CAT') and c.ts>=date_trunc('week',now())) as biomass_in_kg,
 (select coalesce(sum(qty),0) from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.farm_id=f.id and m.status='ACTIVE' and m.direction=1 and w.code='K2' and m.ts>=date_trunc('week',now())) as purchased_in_kg,
 (select coalesce(sum(qty_kg),0) from feed_logs l where l.farm_id=f.id and l.status='ACTIVE' and l.ts>=date_trunc('week',now())) as feed_used_kg,
 (select coalesce(sum((o->>'kg')::numeric),0) from batch_logs b, jsonb_array_elements(b.outputs) o where b.farm_id=f.id and b.status='ACTIVE' and b.line in ('SO_CHE','SAY','DONG_GOI','D5_TMR','D5_VIEN') and b.ts>=date_trunc('week',now())) as products_out_kg,
 (select coalesce(sum(n.value),0) * (select coalesce(sum(head_count),0) from v_herd h where h.farm_id=f.id) * 7 from norms n where n.kind='PHAN_KG_CON_NGAY' and (n.farm_id=f.id or n.farm_id is null) limit 1) as manure_est_kg,
 (select coalesce(sum((i->>'kg')::numeric),0) from batch_logs b, jsonb_array_elements(b.inputs) i where b.farm_id=f.id and b.status='ACTIVE' and b.line in ('TRUN_NAP','BIOGAS','COMPOST') and b.ts>=date_trunc('week',now())) as manure_treated_kg,
 (select coalesce(sum((o->>'kg')::numeric),0) from batch_logs b, jsonb_array_elements(b.outputs) o where b.farm_id=f.id and b.status='ACTIVE' and b.line in ('TRUN_THU','COMPOST') and b.ts>=date_trunc('week',now())) as organic_out_kg
from farms f;

-- Truy xuất 1-lùi-1-tiến theo lot
create or replace view v_trace_links as
select b.farm_id, b.batch_code, (i->>'lot_id') as input_lot, (o->>'lot_id') as output_lot, (o->>'sku') as output_sku, b.ts
from batch_logs b, jsonb_array_elements(b.inputs) i, jsonb_array_elements(b.outputs) o where b.status='ACTIVE';

-- Alerts tồn kho: FEFO đỏ (<20% hạn) & ngày-tồn ủ
create or replace view v_fefo_red as
select b.*, l.mfg_date, round(100.0*(l.expiry_date-current_date)/nullif(l.expiry_date-coalesce(l.mfg_date,(l.expiry_date-365)),0),0) as pct_left
from v_stock_balance b join lots l on l.id=b.lot_id where b.qty>0 and l.expiry_date is not null and (l.expiry_date-current_date) <= 0.2*(l.expiry_date-coalesce(l.mfg_date,(l.expiry_date-365)));

-- Cây phả hệ 3 đời
create or replace view v_pedigree as
select a.id, a.dam_id, d.dam_id as granddam_id, gd.dam_id as ggdam_id, a.sire_code, d.sire_code as grandsire_code
from animals a left join animals d on d.id=a.dam_id left join animals gd on gd.id=d.dam_id;

grant select on all tables in schema public to app_user;
