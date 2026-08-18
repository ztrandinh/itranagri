-- 0066 · TỰ ĐỘNG & DỰ BÁO: mọi số nhảy theo dữ liệu thật — bê sinh (animal_events DE / animals mới) → đàn theo hạng (hạng suy từ tuổi nếu chưa gán)
--        → khẩu phần/ngày → nguyên liệu → dự trữ/cần bổ sung; dự báo đàn 30/60/90 ngày (đẻ dự kiến từ PHOI/KHAM_THAI + 283 ngày thai; bê lớn lên đổi hạng; xuất bán vỗ béo đủ ngày)
-- 1) hạng suy từ tuổi/giới/mục đích khi class_code trống
create or replace function derive_class(p_species text, p_sex text, p_birth date, p_class text) returns text language sql immutable as $$
  select coalesce(p_class, case p_species
    when 'BO' then case when p_birth is null then 'BO-CAI-SS' when current_date - p_birth <= 180 then 'BO-BE' when current_date - p_birth <= 540 then 'BO-TO' when p_sex='M' then 'BO-VO-BEO' else 'BO-CAI-SS' end
    when 'DE' then case when p_birth is not null and current_date - p_birth <= 120 then 'DE-CON' when p_sex='M' then 'DE-THIT' else 'DE-CAI-SS' end
    else p_species end) $$;
create or replace function herd_by_class(p_farm text) returns table(class_code text, class_name text, species text, head numeric) language sql stable as $$
  with a as (select derive_class(a.species, a.sex, a.birth_date, a.class_code) as cc, count(*)::numeric as n from animals a where a.farm_id=p_farm and a.status not in ('CHET','LOAI','XUAT','DA_BAN') group by 1),
  g as (select case g.kind when 'GA_DE' then 'GA-DE' when 'GA_THIT' then 'GA-THIT' when 'RAS' then 'CA-THIT' when 'DE_NHOM' then 'DE-THIT' else null end as cc, sum(coalesce(g.head_count,0))::numeric as n from animal_groups g where g.farm_id=p_farm and g.status='ACTIVE' and g.kind<>'BO_NHOM' group by 1),
  u as (select cc, sum(n) as n from (select * from a union all select * from g) x where cc is not null group by cc)
  select u.cc, c.name, c.species_code, u.n from u left join animal_classes c on c.code=u.cc where u.n>0 order by 1 $$;
-- 2) DỰ BÁO ĐÀN theo hạng tại +N ngày: đẻ dự kiến (PHOI/KHAM_THAI dương gần nhất + 283 ngày ≤ mốc; chưa có sự kiện DE sau đó), bê chuyển hạng theo tuổi tại mốc, vỗ béo đủ 'settings fattening.days' (mặc định 90) → xuất
create or replace function herd_forecast(p_farm text, p_days int) returns table(class_code text, class_name text, head_now numeric, head_forecast numeric, births numeric, exits numeric) language plpgsql stable as $$
declare v_fat_days int := coalesce((select (value#>>'{}')::int from settings where key='fattening.days' and (farm_id=p_farm or farm_id is null) order by (farm_id=p_farm) desc limit 1), 90); begin
  return query
  with base as (select a.id, a.species, a.sex, a.birth_date, a.class_code, a.created_at::date as in_date from animals a where a.farm_id=p_farm and a.status not in ('CHET','LOAI','XUAT','DA_BAN')),
  fut as (select b.id, b.species, derive_class(b.species, b.sex, b.birth_date, case when b.class_code in ('BO-BE','BO-TO','DE-CON') then null else b.class_code end) as cc_now,
             coalesce(b.class_code, '') as fixed, b.birth_date, b.sex,
             -- hạng tại mốc: nếu hạng đang là hạng theo tuổi thì tính lại tuổi tại mốc
             case when b.species='BO' and b.birth_date is not null and (b.class_code is null or b.class_code in ('BO-BE','BO-TO')) then case when (current_date + p_days) - b.birth_date <= 180 then 'BO-BE' when (current_date + p_days) - b.birth_date <= 540 then 'BO-TO' when b.sex='M' then 'BO-VO-BEO' else 'BO-CAI-SS' end
                  else derive_class(b.species, b.sex, b.birth_date, b.class_code) end as cc_fut,
             -- xuất bán: vỗ béo đã ở trại ≥ fat_days tại mốc
             (derive_class(b.species, b.sex, b.birth_date, b.class_code)='BO-VO-BEO' and (current_date + p_days) - b.in_date >= v_fat_days) as will_exit
          from base b),
  preg as (select e.animal_id, max(e.ts)::date + 283 as due from animal_events e join base b on b.id=e.animal_id where e.farm_id=p_farm and e.status='ACTIVE' and ((e.event_type='KHAM_THAI' and coalesce(e.detail->>'result','+') in ('+','CO','DUONG')) or e.event_type='PHOI')
            and not exists (select 1 from animal_events d where d.animal_id=e.animal_id and d.event_type='DE' and d.ts>e.ts) group by e.animal_id),
  births as (select count(*)::numeric as n from preg where due between current_date and current_date + p_days),
  now_c as (select class_code, class_name, species, head from herd_by_class(p_farm)),
  fut_c as (select cc_fut as cc, count(*) filter (where not will_exit)::numeric as n, count(*) filter (where will_exit)::numeric as ex from fut group by cc_fut),
  grp as (select class_code, head from herd_by_class(p_farm) where class_code not like 'BO-%' and class_code not like 'DE-%')
  select coalesce(n.class_code, f.cc) as class_code, coalesce(n.class_name, c.name) as class_name, coalesce(n.head,0) as head_now,
    coalesce(f.n, g.head, 0) + case when coalesce(n.class_code, f.cc)='BO-BE' then (select n from births) else 0 end as head_forecast,
    case when coalesce(n.class_code, f.cc)='BO-BE' then (select n from births) else 0 end as births, coalesce(f.ex,0) as exits
  from now_c n full join fut_c f on f.cc=n.class_code left join grp g on g.class_code=coalesce(n.class_code, f.cc) left join animal_classes c on c.code=coalesce(n.class_code, f.cc)
  where coalesce(n.head,0)>0 or coalesce(f.n,0)>0 or coalesce(f.ex,0)>0 order by 1; end $$;
grant execute on function herd_forecast(text,int) to app_user;
-- nhu cầu thức ăn/ngày tại mốc dự báo (kg/ngày) theo hạng dự báo
create or replace function feed_forecast(p_farm text, p_days int) returns table(class_code text, class_name text, head_now numeric, head_forecast numeric, kg_per_head_day numeric, kg_day_now numeric, kg_day_forecast numeric, recipe_id text) language sql stable as $$
  select f.class_code, f.class_name, f.head_now, f.head_forecast,
    coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (f.class_code, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=f.class_code) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0) as kph,
    f.head_now * coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (f.class_code, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=f.class_code) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0),
    f.head_forecast * coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (f.class_code, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=f.class_code) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0),
    cr.recipe_id
  from herd_forecast(p_farm, p_days) f left join animal_classes c on c.code=f.class_code left join class_recipes cr on cr.class_code=f.class_code $$;
grant execute on function feed_forecast(text,int) to app_user;
-- 3) Nhu cầu nguyên liệu/ngày SỐNG (đàn thật hôm nay) và tại mốc N ngày → dùng cho dashboard dự trữ (không phụ thuộc kế hoạch đã ban hành)
create or replace function live_material_demand(p_farm text, p_days int default 0) returns table(sku text, kg_per_day numeric) language sql stable as $$
  select (c->>'sku') as sku, sum(f.kg_day_forecast * (c->>'pct')::numeric/100) from feed_forecast(p_farm, p_days) f join recipes r on r.id=f.recipe_id, jsonb_array_elements(r.components) c group by 1 $$;
grant execute on function live_material_demand(text,int) to app_user;
drop view if exists v_stock_dashboard;
create view v_stock_dashboard as
with farms_x as (select distinct m.farm_id from inventory_moves m),
bal as (select m.farm_id, w.block, m.sku, sum(m.direction*m.qty) as qty, max(m.ts) as last_move from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
use14 as (select m.farm_id, w.block, m.sku, sum(m.qty)/14.0 as per_day from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and m.direction=-1 and m.ts>now()-interval '14 days' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
in14 as (select m.farm_id, w.block, m.sku, sum(m.qty)/14.0 as per_day from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and m.direction=1 and m.ts>now()-interval '14 days' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
live0 as (select fx.farm_id, d.sku, d.kg_per_day from farms_x fx, lateral live_material_demand(fx.farm_id, 0) d),
live30 as (select fx.farm_id, d.sku, d.kg_per_day from farms_x fx, lateral live_material_demand(fx.farm_id, 30) d),
live90 as (select fx.farm_id, d.sku, d.kg_per_day from farms_x fx, lateral live_material_demand(fx.farm_id, 90) d),
po as (select p.farm_id, (l->>'sku') as sku, sum((l->>'qty')::numeric) as kg from purchase_orders p, jsonb_array_elements(p.lines) l where p.po_status in ('DUYET','NHAN') and p.received_at is null group by 1,2),
hv as (select cs.farm_id, m.sku, sum(greatest(coalesce(cs.target_yield_kg,0)-coalesce(cs.actual_yield_kg,0),0)/coalesce(m.fresh_per_sku,1)) as kg from crop_seasons cs join sku_crop_map m on (m.crop_code=cs.crop_code or cs.crop_code=any(m.alt_crops)) where cs.status in ('DANG_TRONG','THU_HOACH') group by 1,2),
pp as (select farm_id, sku, sum(qty_plan-coalesce(qty_done,0)) as qty from production_plans where status in ('KE_HOACH','DANG_SX') group by 1,2),
pol as (select farm_id, sku, max(max_qty) as max_qty, max(coalesce(rop_qty,min_qty)) as rop, max(lead_time_days) as lead from stock_policies where active group by 1,2),
demand as (select o.farm_id, (l->>'sku') as sku, sum((l->>'qty')::numeric) as qty from orders o, jsonb_array_elements(o.lines) l where o.status='CHOT' group by 1,2)
select b.farm_id, b.block, b.sku, p.name, p.kind, p.unit, round(b.qty,1) as qty, b.last_move,
  pol.max_qty, case when pol.max_qty>0 then round(b.qty*100/pol.max_qty) end as pct_full,
  round(coalesce(l0.kg_per_day, u.per_day, 0),1) as use_per_day, round(coalesce(i.per_day,0),1) as in_per_day,
  round(coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day, 0),1) as use_per_day_30, round(coalesce(l90.kg_per_day, l0.kg_per_day, u.per_day, 0),1) as use_per_day_90,
  case when l0.kg_per_day is not null then 'DAN_THAT' else 'TB_14_NGAY' end as demand_source,
  case when coalesce(l0.kg_per_day, u.per_day, 0)>0 then round(b.qty/coalesce(l0.kg_per_day, u.per_day),0) end as days_left,
  round(coalesce(po.kg,0)) as incoming_po, round(coalesce(hv.kg,0)) as incoming_harvest, round(coalesce(pp.qty,0)) as incoming_production, round(coalesce(demand.qty,0)) as committed_orders,
  round(b.qty + coalesce(po.kg,0) + coalesce(pp.qty,0) - coalesce(demand.qty,0) - (coalesce(l0.kg_per_day, u.per_day, 0)+coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day, 0))/2*30) as proj_30,
  round(b.qty + coalesce(po.kg,0) + coalesce(hv.kg,0)*0.5 + coalesce(pp.qty,0) - coalesce(demand.qty,0) - (coalesce(l0.kg_per_day, u.per_day, 0)+coalesce(l90.kg_per_day, l0.kg_per_day, u.per_day, 0))/2*60) as proj_60,
  round(b.qty + coalesce(po.kg,0) + coalesce(hv.kg,0) + coalesce(pp.qty,0) - coalesce(demand.qty,0) - (coalesce(l0.kg_per_day, u.per_day, 0)+coalesce(l90.kg_per_day, l0.kg_per_day, u.per_day, 0))/2*90) as proj_90,
  round(greatest(coalesce(pol.max_qty, coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day,0)*60) - (b.qty + coalesce(po.kg,0) + coalesce(hv.kg,0) - coalesce(l0.kg_per_day, u.per_day, 0)*coalesce(pol.lead,14)), 0)) as need_qty,
  pol.rop, pol.lead,
  case when b.qty<=0 then 'HET' when pol.rop is not null and b.qty<=pol.rop then 'CHAM_ROP' when coalesce(l0.kg_per_day, u.per_day,0)>0 and b.qty/coalesce(l0.kg_per_day, u.per_day) < coalesce(pol.lead,14) then 'THIEU_SOM' when b.qty + coalesce(po.kg,0) - coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day,0)*30 < 0 then 'AM_30_NGAY' else 'OK' end as flag
from bal b join products p on p.sku=b.sku
left join use14 u on u.farm_id=b.farm_id and u.block=b.block and u.sku=b.sku left join in14 i on i.farm_id=b.farm_id and i.block=b.block and i.sku=b.sku
left join live0 l0 on l0.farm_id=b.farm_id and l0.sku=b.sku and b.block='DAU_VAO' left join live30 l30 on l30.farm_id=b.farm_id and l30.sku=b.sku and b.block='DAU_VAO' left join live90 l90 on l90.farm_id=b.farm_id and l90.sku=b.sku and b.block='DAU_VAO'
left join po on po.farm_id=b.farm_id and po.sku=b.sku left join hv on hv.farm_id=b.farm_id and hv.sku=b.sku left join pp on pp.farm_id=b.farm_id and pp.sku=b.sku
left join pol on pol.farm_id=b.farm_id and pol.sku=b.sku left join demand on demand.farm_id=b.farm_id and demand.sku=b.sku
where p.kind<>'CONG_CU';
grant select on v_stock_dashboard to app_user;
-- 4) Sự kiện đẻ → tự tạo bê (nếu chưa có) để đàn nhảy ngay: trigger trên animal_events DE với detail.calf_sex/calf_tag (tùy chọn) — bê chưa tai vẫn tạo (tag_pending)
create or replace function trg_birth_creates_calf() returns trigger language plpgsql as $$
declare v_id text; v_dam record; begin
  if new.event_type <> 'DE' or new.animal_id is null then return new; end if;
  if coalesce((new.detail->>'create_calf')::bool, true) is false then return new; end if;
  select * into v_dam from animals where id=new.animal_id;
  if v_dam.id is null then return new; end if;
  if exists (select 1 from animals c where c.dam_id=new.animal_id and c.birth_date=new.ts::date) then return new; end if;
  v_id := coalesce(new.detail->>'calf_id', next_code_free(new.farm_id, 'BE', 'animals'));
  insert into animals(id, farm_id, species, breed, sex, birth_date, dam_id, sire_id, source, group_id, status, location_id, class_code, tag_pending, visual_tag, created_at)
  values (v_id, new.farm_id, v_dam.species, v_dam.breed, coalesce(new.detail->>'calf_sex','F'), new.ts::date, new.animal_id, v_dam.sire_id, 'SINH', v_dam.group_id, 'THEO_ME', v_dam.location_id, case v_dam.species when 'BO' then 'BO-BE' when 'DE' then 'DE-CON' else null end, (new.detail->>'calf_tag') is null, new.detail->>'calf_tag', now())
  on conflict do nothing;
  perform publish_event(new.farm_id, 'animal.born', jsonb_build_object('calf_id', v_id, 'dam_id', new.animal_id, 'species', v_dam.species));
  return new; end $$;
drop trigger if exists birth_creates_calf on animal_events; create trigger birth_creates_calf after insert on animal_events for each row execute function trg_birth_creates_calf();
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values ('animal.born','Bê/dê con sinh ra → đàn tăng, khẩu phần & dự trữ tự cập nhật','BO','{D5,KTCN,TCKT,BGD}','animals',true) on conflict (topic) do nothing;
