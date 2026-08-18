-- 0064 · DASHBOARD DỰ TRỮ tách 3 khối: (A) KHO ĐẦU VÀO — nguyên liệu/thức ăn cho vật nuôi, giống, phân/thuốc, bao bì, nhiên liệu;
--        (B) KHO ĐẦU RA — thành phẩm bán; (C) KHO CÔNG CỤ – DỤNG CỤ SẢN XUẤT — từng cái cuốc/xẻng/búa… định nghĩa, nhiều kho theo khu vực, cấp phát – thu hồi – hỏng.
--        Mỗi SKU: còn bao nhiêu / % sức chứa, dùng/ngày, ngày còn lại, đang về (PO/thu hoạch/SX), nhu cầu kế hoạch, DỰ KIẾN TỒN 30–90 ngày, CẦN BỔ SUNG.
-- 1) Phân khối kho + khu vực + sức chứa
alter table warehouses add column if not exists block text check (block in ('DAU_VAO','DAU_RA','CONG_CU','KHAC'));
alter table warehouses add column if not exists area text;           -- khu vực đặt kho (khu A/B/D, nhà D5, cổng…)
alter table warehouses add column if not exists capacity numeric;    -- sức chứa (theo unit_kind: kg / cái / L)
alter table warehouses add column if not exists location_id text references locations;
update warehouses set block = case code when 'K5' then 'DAU_RA' when 'K6' then 'DAU_RA' when 'K8' then 'KHAC' else 'DAU_VAO' end where block is null;
update warehouses set area = case code when 'K1' then 'Khu A – nhà điều hành' when 'K2' then 'Nhà D5' when 'K3' then 'Hào ủ – silo D5' when 'K4' then 'Nhà D5' when 'K5' then 'Nhà chế biến – dock' when 'K6' then 'Nhà chế biến' when 'K7' then 'Trạm dầu cổng' when 'K9' then 'Nhà chế biến' else area end where area is null;
-- kho công cụ theo khu vực (mỗi trại): nhiều kho
insert into warehouses(id, farm_id, code, name, unit_kind, count_cycle, block, area, active)
select f.id||'-KCC-'||v.k, f.id, 'KCC-'||v.k, v.n, 'CAI', 'THANG', 'CONG_CU', v.a, true from farms f, (values ('A','Kho công cụ khu A (chuồng bò)','Khu A'),('D','Kho công cụ khu D (sinh học/D5)','Khu D'),('R','Kho công cụ ruộng (máy nông cụ)','Nhà máy nông nghiệp'),('CB','Kho công cụ chế biến – bảo trì','Nhà chế biến')) v(k,n,a)
where f.status is distinct from 'DONG' and not exists (select 1 from warehouses w where w.farm_id=f.id and w.code='KCC-'||v.k);
-- 2) Loại hàng CONG_CU + danh mục dụng cụ (định nghĩa từng thứ: nhóm, đơn vị, tuổi thọ, giá tham khảo, cần chứng chỉ?)
alter table products drop constraint if exists products_kind_check;
alter table products add constraint products_kind_check check (kind in ('THANH_PHAM','BAN_TP','NGUYEN_LIEU','VAT_TU','THUOC','VACCINE','NHIEN_LIEU','BAO_BI','DICH_VU','GIONG','CONG_CU','PHAN_BON'));
alter table products add column if not exists tool_group text;      -- CAM_TAY|CAT_TIA|DIEN|PHUN_TUOI|VAN_CHUYEN|DO_LUONG|BAO_HO|THU_Y|CHUONG_TRAI|SUA_CHUA
alter table products add column if not exists life_months int;      -- tuổi thọ tham khảo
alter table products add column if not exists ref_price numeric;
alter table products add column if not exists needs_cert bool default false;
insert into products(sku, org_id, name, kind, unit, tool_group, life_months, ref_price, needs_cert, active) select v.sku, 'ITRAN', v.name, 'CONG_CU', v.unit, v.grp, v.life, v.price, v.cert, true from (values
 ('CC-CUOC','Cuốc bàn','cai','CAM_TAY',24,120000,false),('CC-CUOC-CHIM','Cuốc chim','cai','CAM_TAY',36,150000,false),('CC-XENG','Xẻng','cai','CAM_TAY',24,110000,false),('CC-XENG-XUC','Xẻng xúc phân/ủ','cai','CAM_TAY',18,130000,false),
 ('CC-CAO','Cào răng (cào cỏ/phân)','cai','CAM_TAY',18,90000,false),('CC-CHIA','Chĩa 4 răng','cai','CAM_TAY',24,120000,false),('CC-BUA','Búa tạ / búa đinh','cai','SUA_CHUA',60,150000,false),('CC-KIM','Kìm điện / kìm cắt','cai','SUA_CHUA',36,80000,false),
 ('CC-CO-LE','Bộ cờ lê – mỏ lết','bo','SUA_CHUA',60,450000,false),('CC-CUA-TAY','Cưa tay / cưa cành','cai','CAT_TIA',24,120000,false),('CC-DAO-PHAT','Dao phát / rựa','cai','CAT_TIA',24,90000,false),('CC-KEO-CANH','Kéo cắt cành','cai','CAT_TIA',24,150000,false),
 ('CC-MAY-CAT-CO','Máy cắt cỏ cầm tay','cai','DIEN',48,3500000,true),('CC-MAY-KHOAN','Máy khoan pin','cai','DIEN',48,2500000,false),('CC-MAY-BOM-XACH','Máy bơm xách tay','cai','DIEN',48,2800000,false),('CC-MAY-PHUN','Máy phun thuốc/khử trùng đeo vai','cai','PHUN_TUOI',36,1800000,true),
 ('CC-BINH-PHUN','Bình phun tay 16 L','cai','PHUN_TUOI',24,350000,false),('CC-ONG-TUOI','Ống tưới 50 m + béc','bo','PHUN_TUOI',24,600000,false),('CC-XE-RUA','Xe rùa','cai','VAN_CHUYEN',36,650000,false),('CC-XE-DAY','Xe đẩy 4 bánh','cai','VAN_CHUYEN',48,1500000,false),
 ('CC-CAN-DIEN-TU','Cân điện tử 100–300 kg','cai','DO_LUONG',60,2500000,false),('CC-CAN-TREO','Cân treo 50 kg','cai','DO_LUONG',48,400000,false),('CC-NHIET-KE','Nhiệt kế đo luống/thân','cai','DO_LUONG',24,250000,false),('CC-THUOC-DAY','Thước dây 50 m','cai','DO_LUONG',36,150000,false),
 ('CC-UNG','Ủng cao su','doi','BAO_HO',12,120000,false),('CC-GANG','Găng tay (hộp/đôi)','doi','BAO_HO',3,15000,false),('CC-KHAU-TRANG','Khẩu trang N95','cai','BAO_HO',1,8000,false),('CC-MU-BH','Mũ bảo hộ','cai','BAO_HO',24,80000,false),('CC-KINH-BH','Kính bảo hộ','cai','BAO_HO',12,50000,false),
 ('CC-BOC-TAI','Kìm bấm thẻ tai + kim','bo','THU_Y',36,600000,true),('CC-BOM-TIEM','Bơm tiêm tự động 50 ml','cai','THU_Y',24,450000,true),('CC-DAY-DAT','Dây dắt / mũi khoen','cai','CHUONG_TRAI',12,60000,false),('CC-CHOI-CO','Chổi cứng / cây gạt nước','cai','CHUONG_TRAI',6,60000,false),
 ('CC-XO','Xô nhựa 20 L','cai','CHUONG_TRAI',12,40000,false),('CC-DEN-PIN','Đèn pin sạc','cai','DIEN',24,150000,false),('CC-BINH-CC','Bình chữa cháy 4 kg','cai','BAO_HO',60,350000,false)
) v(sku,name,unit,grp,life,price,cert) where not exists (select 1 from products p where p.sku=v.sku);
-- 3) Cấp phát – thu hồi – hỏng/mất công cụ (không trừ tồn kho khi cấp phát; trừ khi hỏng/mất qua inventory_moves reason HONG/MAT)
create table if not exists tool_issues(
  id bigserial primary key, farm_id text not null references farms, warehouse_id text not null references warehouses, sku text not null references products, qty numeric not null default 1,
  staff_id text references staff, dept text, purpose text, issued_at timestamptz default now(), issued_by text default app_staff(), due_back date, returned_at timestamptz, returned_qty numeric, condition text, -- TOT|HAO_MON|HONG|MAT
  note text);
alter table tool_issues enable row level security; drop policy if exists p_all on tool_issues; create policy p_all on tool_issues for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on tool_issues to app_user; grant usage on sequence tool_issues_id_seq to app_user;
create or replace view v_tool_stock as
select w.farm_id, w.id as warehouse_id, w.code as warehouse_code, w.name as warehouse_name, w.area, p.sku, p.name, p.tool_group, p.unit, p.life_months, p.ref_price, p.needs_cert,
  coalesce(s.qty,0) as on_hand, coalesce(i.issued,0) as issued, coalesce(s.qty,0) - coalesce(i.issued,0) as available,
  (select min(pol.min_qty) from stock_policies pol where pol.farm_id=w.farm_id and pol.sku=p.sku and (pol.warehouse_id=w.id or pol.warehouse_id is null)) as min_qty,
  (select sum(m.qty) from inventory_moves m where m.warehouse_id=w.id and m.sku=p.sku and m.status='ACTIVE' and m.direction=-1 and m.reason in ('HONG','MAT') and m.ts>now()-interval '365 days') as lost_broken_12m
from warehouses w join products p on p.kind='CONG_CU' and p.active
left join lateral (select sum(m.direction*m.qty) as qty from inventory_moves m where m.warehouse_id=w.id and m.sku=p.sku and m.status='ACTIVE') s on true
left join lateral (select sum(t.qty - coalesce(t.returned_qty,0)) as issued from tool_issues t where t.warehouse_id=w.id and t.sku=p.sku and t.returned_at is null) i on true
where w.block='CONG_CU' and w.active and (coalesce(s.qty,0)<>0 or coalesce(i.issued,0)<>0);
grant select on v_tool_stock to app_user;
create or replace view v_tool_issued as
select t.*, p.name as tool_name, p.tool_group, s.full_name as staff_name, w.code as warehouse_code, w.area, (t.due_back is not null and t.due_back < current_date and t.returned_at is null) as overdue
from tool_issues t join products p on p.sku=t.sku left join staff s on s.id=t.staff_id join warehouses w on w.id=t.warehouse_id where t.returned_at is null;
grant select on v_tool_issued to app_user;
-- 4) DASHBOARD DỰ TRỮ theo khối: mỗi SKU × khối — còn, % sức chứa, dùng/ngày, ngày còn, đang về, nhu cầu KH, dự kiến tồn 30/60/90, cần bổ sung
create or replace view v_stock_dashboard as
with bal as (select m.farm_id, w.block, m.sku, sum(m.direction*m.qty) as qty, max(m.ts) as last_move from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
use14 as (select m.farm_id, w.block, m.sku, sum(m.qty)/14.0 as per_day from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and m.direction=-1 and m.ts>now()-interval '14 days' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
in14 as (select m.farm_id, w.block, m.sku, sum(m.qty)/14.0 as per_day from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and m.direction=1 and m.ts>now()-interval '14 days' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
po as (select p.farm_id, (l->>'sku') as sku, sum((l->>'qty')::numeric) as kg from purchase_orders p, jsonb_array_elements(p.lines) l where p.po_status in ('DUYET','NHAN') and p.received_at is null group by 1,2),
hv as (select cs.farm_id, m.sku, sum(greatest(coalesce(cs.target_yield_kg,0)-coalesce(cs.actual_yield_kg,0),0)/coalesce(m.fresh_per_sku,1)) as kg from crop_seasons cs join sku_crop_map m on (m.crop_code=cs.crop_code or cs.crop_code=any(m.alt_crops)) where cs.status in ('DANG_TRONG','THU_HOACH') group by 1,2),
pp as (select farm_id, sku, sum(qty_plan-coalesce(qty_done,0)) as qty from production_plans where status in ('KE_HOACH','DANG_SX') group by 1,2),
plan as (select pl.farm_id, pl.sku, pl.per_day_kg from plan_lines pl join plan_scenarios s on s.id=pl.scenario_id where s.status='BAN_HANH' and s.published_at=(select max(published_at) from plan_scenarios x where x.farm_id=pl.farm_id and x.status='BAN_HANH')),
pol as (select farm_id, sku, max(max_qty) as max_qty, max(coalesce(rop_qty,min_qty)) as rop, max(lead_time_days) as lead from stock_policies where active group by 1,2),
demand as (select o.farm_id, (l->>'sku') as sku, sum((l->>'qty')::numeric) as qty from orders o, jsonb_array_elements(o.lines) l where o.status='CHOT' group by 1,2)
select b.farm_id, b.block, b.sku, p.name, p.kind, p.unit, round(b.qty,1) as qty, b.last_move,
  pol.max_qty, case when pol.max_qty>0 then round(b.qty*100/pol.max_qty) end as pct_full,
  round(coalesce(plan.per_day_kg, u.per_day, 0),1) as use_per_day, round(coalesce(i.per_day,0),1) as in_per_day,
  case when coalesce(plan.per_day_kg, u.per_day, 0)>0 then round(b.qty/coalesce(plan.per_day_kg, u.per_day),0) end as days_left,
  round(coalesce(po.kg,0)) as incoming_po, round(coalesce(hv.kg,0)) as incoming_harvest, round(coalesce(pp.qty,0)) as incoming_production, round(coalesce(demand.qty,0)) as committed_orders,
  round(b.qty + coalesce(po.kg,0) + coalesce(pp.qty,0) - coalesce(demand.qty,0) - coalesce(plan.per_day_kg, u.per_day, 0)*30) as proj_30,
  round(b.qty + coalesce(po.kg,0) + coalesce(hv.kg,0)*0.5 + coalesce(pp.qty,0) - coalesce(demand.qty,0) - coalesce(plan.per_day_kg, u.per_day, 0)*60) as proj_60,
  round(b.qty + coalesce(po.kg,0) + coalesce(hv.kg,0) + coalesce(pp.qty,0) - coalesce(demand.qty,0) - coalesce(plan.per_day_kg, u.per_day, 0)*90) as proj_90,
  round(greatest(coalesce(pol.max_qty, coalesce(plan.per_day_kg, u.per_day,0)*60) - (b.qty + coalesce(po.kg,0) + coalesce(hv.kg,0) - coalesce(plan.per_day_kg, u.per_day, 0)*coalesce(pol.lead,14)), 0)) as need_qty,
  pol.rop, pol.lead,
  case when b.qty<=0 then 'HET' when pol.rop is not null and b.qty<=pol.rop then 'CHAM_ROP' when coalesce(plan.per_day_kg, u.per_day,0)>0 and b.qty/coalesce(plan.per_day_kg, u.per_day) < coalesce(pol.lead,14) then 'THIEU_SOM' when b.qty + coalesce(po.kg,0) - coalesce(plan.per_day_kg, u.per_day,0)*30 < 0 then 'AM_30_NGAY' else 'OK' end as flag
from bal b join products p on p.sku=b.sku
left join use14 u on u.farm_id=b.farm_id and u.block=b.block and u.sku=b.sku left join in14 i on i.farm_id=b.farm_id and i.block=b.block and i.sku=b.sku
left join po on po.farm_id=b.farm_id and po.sku=b.sku left join hv on hv.farm_id=b.farm_id and hv.sku=b.sku left join pp on pp.farm_id=b.farm_id and pp.sku=b.sku
left join plan on plan.farm_id=b.farm_id and plan.sku=b.sku left join pol on pol.farm_id=b.farm_id and pol.sku=b.sku left join demand on demand.farm_id=b.farm_id and demand.sku=b.sku
where p.kind<>'CONG_CU';
grant select on v_stock_dashboard to app_user;
-- tổng theo kho (sức chứa)
create or replace view v_warehouse_fill as
select w.farm_id, w.id as warehouse_id, w.code, w.name, w.block, w.area, w.unit_kind, w.capacity,
  coalesce((select sum(m.direction*m.qty) from inventory_moves m where m.warehouse_id=w.id and m.status='ACTIVE'),0) as qty,
  case when w.capacity>0 then round(coalesce((select sum(m.direction*m.qty) from inventory_moves m where m.warehouse_id=w.id and m.status='ACTIVE'),0)*100/w.capacity) end as pct_full,
  (select count(distinct m.sku) from inventory_moves m where m.warehouse_id=w.id and m.status='ACTIVE') as skus,
  (select count(*) from bins b where b.warehouse_id=w.id and b.active) as bins
from warehouses w where w.active and w.block<>'KHAC';
grant select on v_warehouse_fill to app_user;
update warehouses set capacity = case code when 'K2' then 300000 when 'K3' then 800000 when 'K4' then 50000 when 'K5' then 20000 when 'K6' then 5000 when 'K7' then 5000 when 'K1' then 3000 when 'K9' then 20000 else capacity end where capacity is null and farm_id='F01';
-- cảnh báo: dự kiến âm 30 ngày, công cụ cấp phát quá hạn
insert into alert_rules(code, version, farm_id, name, source, expr, level, recipients, channels, cooldown_min, active)
select v.code, 1, 'GLOBAL', v.name, 'custom', v.expr::jsonb, v.level, v.rec::text[], '{app}'::text[], v.cd, true from (values
 ('AL-STOCK-PROJ','Dự trữ dự kiến âm trong 30 ngày','{"type":"sql_rows","sql":"select name as ref, qty as value, use_per_day, proj_30, need_qty from v_stock_dashboard where farm_id=$1 and flag in (''AM_30_NGAY'',''THIEU_SOM'',''HET'')","message":"{ref}: tồn {value}, dùng {use_per_day}/ngày → 30 ngày còn {proj_30}; cần bổ sung ~{need_qty}"}','VANG','{tech_head,accountant,director}',1440),
 ('AL-TOOL-OVERDUE','Công cụ cấp phát quá hạn trả','{"type":"sql_rows","sql":"select tool_name||'' → ''||coalesce(staff_name,'''') as ref, qty as value, due_back::text as d from v_tool_issued where farm_id=$1 and overdue","message":"Công cụ {ref} ({value}) quá hạn trả {d}"}','VANG','{team_lead,tech_head}',1440)
) as v(code, name, expr, level, rec, cd) where not exists (select 1 from alert_rules a where a.code=v.code);
drop trigger if exists tool_issues_audit on tool_issues; create trigger tool_issues_audit after insert or update or delete on tool_issues for each row execute function itran_audit();
