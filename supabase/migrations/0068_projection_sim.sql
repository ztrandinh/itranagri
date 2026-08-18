-- 0068 · Chuỗi DỰ KIẾN TỒN theo ngày (0..N) cho biểu đồ + mô phỏng dữ liệu (thai kỳ → đẻ dự kiến 20–85 ngày tới, 1 ca đẻ hôm nay → bê tự sinh, PO bã bia đang về)
create or replace function stock_projection(p_farm text, p_sku text, p_days int default 90) returns table(day date, d int, qty numeric, incoming numeric, usage numeric, rop numeric) language plpgsql stable as $$
declare v_qty numeric; v_use0 numeric; v_use30 numeric; v_use90 numeric; v_rop numeric; v_lead int; begin
  select coalesce(sum(m.direction*m.qty),0) into v_qty from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.farm_id=p_farm and m.sku=p_sku and m.status='ACTIVE' and w.block in ('DAU_VAO','DAU_RA');
  select coalesce((select kg_per_day from live_material_demand(p_farm,0) where sku=p_sku), (select sum(m.qty)/14.0 from inventory_moves m where m.farm_id=p_farm and m.sku=p_sku and m.status='ACTIVE' and m.direction=-1 and m.ts>now()-interval '14 days'), 0) into v_use0;
  select coalesce((select kg_per_day from live_material_demand(p_farm,30) where sku=p_sku), v_use0) into v_use30;
  select coalesce((select kg_per_day from live_material_demand(p_farm,90) where sku=p_sku), v_use30) into v_use90;
  select max(coalesce(rop_qty,min_qty)), max(lead_time_days) into v_rop, v_lead from stock_policies where farm_id=p_farm and sku=p_sku and active;
  return query
  with days as (select generate_series(0, p_days) as dd),
  po as (select coalesce(p.expected_at, p.ts::date + coalesce(v_lead,7)) as due, sum((l->>'qty')::numeric) as kg from purchase_orders p, jsonb_array_elements(p.lines) l where p.farm_id=p_farm and (l->>'sku')=p_sku and p.po_status in ('DUYET','NHAN') and p.received_at is null group by 1),
  hv as (select coalesce(cs.expected_harvest, cs.sow_date + coalesce(c.cycle_days,90)) as due, sum(greatest(coalesce(cs.target_yield_kg,0)-coalesce(cs.actual_yield_kg,0),0)/coalesce(m.fresh_per_sku,1)) as kg from crop_seasons cs join sku_crop_map m on m.sku=p_sku and (m.crop_code=cs.crop_code or cs.crop_code=any(m.alt_crops)) left join crops c on c.code=cs.crop_code where cs.farm_id=p_farm and cs.status in ('DANG_TRONG','THU_HOACH') group by 1),
  pp as (select week_start as due, sum(qty_plan-coalesce(qty_done,0)) as kg from production_plans where farm_id=p_farm and sku=p_sku and status in ('KE_HOACH','DANG_SX') group by 1),
  inc as (select due, sum(kg) as kg from (select * from po union all select * from hv union all select * from pp) x group by due),
  ser as (select dd, (current_date + dd)::date as day, case when dd<=30 then v_use0 + (v_use30-v_use0)*dd/30.0 else v_use30 + (v_use90-v_use30)*(dd-30)/60.0 end as usage_d, coalesce((select sum(kg) from inc where inc.due = current_date + dd),0) as inc_d from days)
  select s.day, s.dd, round(v_qty + sum(s.inc_d) over (order by s.dd) - sum(s.usage_d) over (order by s.dd) + s.usage_d, 0), round(s.inc_d), round(s.usage_d,1), v_rop from ser s order by s.dd; end $$;
grant execute on function stock_projection(text,text,int) to app_user;
-- MÔ PHỎNG (F01): 12 bò cái phối 200–265 ngày trước → đẻ dự kiến trong 18–83 ngày; 1 ca đẻ hôm nay → trigger tạo bê; PO bã bia 20 tấn về sau 3 ngày
insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail)
select 'F01', now() - ((200 + (row_number() over ())*5) || ' days')::interval, 'NS-006', 'IMPORT', 'sim-phoi-'||a.id, a.id, 'PHOI', '{"semen_lot":"TINH-BRAHMAN/LOT-24","sim":true}'::jsonb
from (select id from animals where farm_id='F01' and species='BO' and sex='F' and status not in ('CHET','LOAI','XUAT') and (birth_date is null or current_date-birth_date>540) order by id limit 12) a
where not exists (select 1 from animal_events e where e.client_ref='sim-phoi-'||a.id);
insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail)
select 'F01', now(), 'NS-006', 'IMPORT', 'sim-de-demo', a.id, 'DE', '{"calf_sex":"F","note":"mô phỏng: bê sinh hôm nay → đàn +1, khẩu phần & dự trữ tự nhảy"}'::jsonb
from (select id from animals where farm_id='F01' and species='BO' and sex='F' and status not in ('CHET','LOAI','XUAT') order by id limit 1) a where not exists (select 1 from animal_events e where e.client_ref='sim-de-demo');
insert into purchase_orders(id, farm_id, supplier_id, ts, created_by, lines, total, po_status, approved_by, approved_at, expected_at, note)
select 'F01-PO-SIM-BABIA', 'F01', 'NCC-0002', now(), 'NS-001', '[{"sku":"NL-BA-BIA","qty":20000,"price":1200}]', 24000000, 'DUYET', 'NS-002', now(), current_date+3, 'Mô phỏng: PO đang về' where not exists (select 1 from purchase_orders where id='F01-PO-SIM-BABIA');
