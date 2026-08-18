-- 0062 · ĐỘNG CƠ CUNG–CẦU (Ban kế hoạch): đàn (thật/kịch bản) → định mức ăn theo hạng → công thức → nguyên liệu (kg/kỳ)
--        → cây trồng cần (ha theo năng suất/lứa/hao hụt ủ) so đất đang trồng → so tồn kho + PO đang về + thu hoạch dự kiến → thiếu hụt
--        → BAN HÀNH: việc + thông báo cho Trồng trọt (trồng thêm ha), Mua hàng (PO), D5 (sản xuất/ngày), Kho (dự trữ) — mọi hằng số là dữ liệu (norms, crops, recipes, sku_crop_map)
-- 1) Định mức ăn theo hạng vật nuôi (kg tươi/con/ngày) — norms kind TA_KG_* (chỉnh ở /quan-tri?t=norms). Nguồn tham chiếu: NRC/INRA & thực tế TMR bò thịt VN (3–3.5% VCK/khối lượng)
insert into norms(id, org_id, kind, subject, value, unit, note) select 'NORM-'||v.k||'-'||v.s, 'ITRAN', v.k, v.s, v.v, v.u, v.n from (values
 ('TA_KG_BE','BO',8,'kg tươi/con/ngày','Bê 0–6 th: sữa/thay sữa + TMR khởi động'),('TA_KG_TO','BO',20,'kg tươi/con/ngày','Bò tơ 6–18 th'),('TA_KG_VB','BO',35,'kg tươi/con/ngày','Vỗ béo 3 pha (TMR ~45% VCK)'),
 ('TA_KG_CON_NGAY','DE',3.5,'kg tươi/con/ngày','Dê: lá + phụ phẩm + viên'),('TA_KG_CON_NGAY','GA-DE',0.115,'kg/con/ngày','Gà đẻ viên D5'),('TA_KG_CON_NGAY','GA-THIT',0.09,'kg/con/ngày','Gà thịt'),('TA_KG_CON_NGAY','CA',0.012,'kg/con/ngày','RAS lươn/cá theo % thân')
) v(k,s,v,u,n) where not exists (select 1 from norms n where n.kind=v.k and n.subject=v.s and n.farm_id is null);
update animal_classes set feed_norm_key='TA_KG_CON_NGAY' where feed_norm_key is null;
-- công thức mặc định theo hạng (recipes.species_phase khớp) — bảng map hạng → recipe
create table if not exists class_recipes(class_code text primary key references animal_classes, recipe_id text references recipes, note text);
insert into class_recipes(class_code, recipe_id) values ('BO-BE','RC-TMR-VO'),('BO-TO','RC-TMR-VO'),('BO-CAI-SS','RC-TMR-VO'),('BO-VO-BEO','RC-TMR-VO'),('BO-DUC-GIONG','RC-TMR-VO'),('GA-DE','RC-GA-DE'),('GA-HAU-BI','RC-GA-DE'),('GA-THIT','RC-GA-DE') on conflict do nothing;
grant select, insert, update on class_recipes to app_user;
-- 2) SKU nguyên liệu ↔ cây trồng: 1 kg SKU cần bao nhiêu kg tươi thu hoạch (ủ chua hao ~15% → 1.18), cây nào, mua ngoài hay trồng
create table if not exists sku_crop_map(
  sku text primary key references products, crop_code text references crops, source text not null default 'TRONG' check (source in ('TRONG','MUA','PHU_PHAM','CA_HAI')),
  fresh_per_sku numeric default 1, -- kg tươi thu hoạch / 1 kg SKU
  alt_crops text[], lead_days int default 0, -- ngày từ gieo đến có SKU dùng được (gồm ủ)
  note text);
insert into sku_crop_map(sku, crop_code, source, fresh_per_sku, alt_crops, lead_days, note) values
 ('NL-BAP-U','BAP-SK','TRONG',1.18,'{CAO-LUONG}',85+21,'Bắp sinh khối → ủ chua 21 ngày, hao 15%'),
 ('NL-CO-TUOI','CO-MOMBASA','TRONG',1.0,'{CO-VA06,CO-RUZI}',45,'Cắt tươi luân phiên ô'),
 ('NL-ROM','LUA','CA_HAI',1.0,'{}',0,'Rơm: phụ phẩm lúa (≈1 kg rơm/kg thóc) — mua HTX + tự có'),
 ('NL-BA-BIA',null,'MUA',1,'{}',2,'Mua nhà máy bia (bã tươi 2 ngày)'),
 ('NL-RI-MAT',null,'MUA',1,'{}',7,''),('NL-KHOANG',null,'MUA',1,'{}',10,'')
on conflict do nothing;
update sku_crop_map set crop_code=null where sku='NL-BA-BIA';
grant select, insert, update on sku_crop_map to app_user;
-- 3) Kịch bản kế hoạch: đàn theo hạng (đầu con) + kỳ (ngày) + tăng đàn dự kiến; herd null = lấy đàn thật
create table if not exists plan_scenarios(
  id text primary key, farm_id text not null references farms, name text not null, horizon_days int not null default 180, start_date date default current_date,
  herd jsonb, -- [{class_code, head}] ; null = đàn thật (animals + animal_groups)
  safety_pct numeric default 10, status text default 'NHAP' check (status in ('NHAP','BAN_HANH','LUU_TRU')), published_at timestamptz, published_by text, note text,
  created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
alter table plan_scenarios enable row level security; drop policy if exists p_all on plan_scenarios; create policy p_all on plan_scenarios for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on plan_scenarios to app_user;
-- đàn thật theo hạng
create or replace function herd_by_class(p_farm text) returns table(class_code text, class_name text, species text, head numeric) language sql stable as $$
  with a as (select coalesce(a.class_code, case a.species when 'BO' then 'BO-CAI-SS' when 'DE' then 'DE-THIT' else a.species end) as cc, count(*)::numeric as n from animals a where a.farm_id=p_farm and a.status not in ('CHET','LOAI','XUAT') group by 1),
  g as (select case g.kind when 'GA_DE' then 'GA-DE' when 'GA_THIT' then 'GA-THIT' when 'RAS' then 'CA-THIT' when 'DE_NHOM' then 'DE-THIT' else null end as cc, sum(coalesce(g.head_count,0))::numeric as n from animal_groups g where g.farm_id=p_farm and g.status='ACTIVE' and g.kind<>'BO_NHOM' group by 1),
  u as (select cc, sum(n) as n from (select * from a union all select * from g) x where cc is not null group by cc)
  select u.cc, c.name, c.species_code, u.n from u left join animal_classes c on c.code=u.cc where u.n>0 order by 1 $$;
grant execute on function herd_by_class(text) to app_user;
-- 4) NHU CẦU THỨC ĂN theo hạng (kg/ngày, kg/kỳ) từ kịch bản hoặc đàn thật
create or replace function plan_feed_demand(p_farm text, p_scenario text default null) returns table(class_code text, class_name text, head numeric, kg_per_head_day numeric, kg_per_day numeric, days int, kg_period numeric, recipe_id text) language plpgsql stable as $$
declare sc record; begin
  if p_scenario is not null then select * into sc from plan_scenarios where id=p_scenario; end if;
  return query
  with h as (
    select (e->>'class_code') as cc, (e->>'head')::numeric as n from plan_scenarios s, jsonb_array_elements(s.herd) e where p_scenario is not null and s.id=p_scenario and s.herd is not null
    union all
    select hb.class_code, hb.head from herd_by_class(p_farm) hb where p_scenario is null or sc.herd is null)
  select h.cc, c.name, h.n,
    coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (h.cc, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=h.cc) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0) as kph,
    h.n * coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (h.cc, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=h.cc) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0),
    coalesce(sc.horizon_days, 180),
    h.n * coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (h.cc, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=h.cc) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0) * coalesce(sc.horizon_days,180) * (1 + coalesce(sc.safety_pct,10)/100),
    cr.recipe_id
  from h left join animal_classes c on c.code=h.cc left join class_recipes cr on cr.class_code=h.cc where h.n>0; end $$;
grant execute on function plan_feed_demand(text,text) to app_user;
-- 5) NHU CẦU NGUYÊN LIỆU (kg/kỳ) = Σ feed × %recipe; so tồn kho khả dụng + PO đang về + thu hoạch dự kiến (mùa vụ mở: target_yield còn lại / fresh_per_sku); ha cần vs ha đang trồng
create or replace function plan_supply(p_farm text, p_scenario text default null) returns table(
  sku text, sku_name text, source text, crop_code text, crop_name text, demand_kg numeric, per_day_kg numeric, stock_kg numeric, po_kg numeric, harvest_expected_kg numeric, shortage_kg numeric,
  ha_needed numeric, ha_current numeric, ha_gap numeric, yield_kg_ha_period numeric, lead_days int, dept text, action text) language plpgsql stable as $$
declare days int; sc record; begin
  if p_scenario is not null then select * into sc from plan_scenarios where id=p_scenario; end if; days := coalesce(sc.horizon_days, 180);
  return query
  with fd as (select * from plan_feed_demand(p_farm, p_scenario)),
  need as (select (c->>'sku') as sku, sum(fd.kg_period * (c->>'pct')::numeric/100) as kg, sum(fd.kg_per_day * (c->>'pct')::numeric/100) as kgd from fd join recipes r on r.id=fd.recipe_id, jsonb_array_elements(r.components) c group by 1),
  st as (select a.sku, sum(a.available) as kg from v_stock_available a where a.farm_id=p_farm group by a.sku),
  po as (select (l->>'sku') as sku, sum((l->>'qty')::numeric) as kg from purchase_orders p, jsonb_array_elements(p.lines) l where p.farm_id=p_farm and p.po_status in ('DUYET','NHAN') and p.received_at is null group by 1),
  hv as (select m.sku, sum(greatest(coalesce(cs.target_yield_kg,0) - coalesce(cs.actual_yield_kg,0),0) / coalesce(m.fresh_per_sku,1)) as kg from crop_seasons cs join sku_crop_map m on (m.crop_code=cs.crop_code or cs.crop_code = any(m.alt_crops)) where cs.farm_id=p_farm and cs.status in ('DANG_TRONG','THU_HOACH') group by m.sku),
  land as (select m.sku, sum(p.area_ha) as ha from plots p join sku_crop_map m on (m.crop_code=p.crop_code or p.crop_code = any(m.alt_crops)) where p.farm_id=p_farm and p.active group by m.sku)
  select n.sku, pr.name, coalesce(m.source,'MUA'), m.crop_code, cr.name, round(n.kg), round(n.kgd,1), round(coalesce(st.kg,0)), round(coalesce(po.kg,0)), round(coalesce(hv.kg,0)),
    round(greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0)) as short,
    case when cr.yield_norm_kg_ha>0 then round((n.kg * coalesce(m.fresh_per_sku,1)) / (cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0), 2) end as ha_needed,
    coalesce(land.ha,0), case when cr.yield_norm_kg_ha>0 then round((n.kg * coalesce(m.fresh_per_sku,1)) / (cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0) - coalesce(land.ha,0), 2) end,
    case when cr.yield_norm_kg_ha>0 then round(cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0) end, m.lead_days,
    case when coalesce(m.source,'MUA') in ('TRONG') then 'TT' when coalesce(m.source,'MUA')='CA_HAI' then 'TT+CCU' else 'CCU' end,
    case when greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0) = 0 then 'ĐỦ'
         when coalesce(m.source,'MUA')='TRONG' then 'TRỒNG THÊM '||coalesce(round(greatest((n.kg * coalesce(m.fresh_per_sku,1)) / nullif(cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0,0) - coalesce(land.ha,0),0),2)::text,'?')||' ha '||coalesce(cr.name,'')||' (lead '||coalesce(m.lead_days,0)||' ngày) + mua bù ngắn hạn'
         when coalesce(m.source,'MUA')='CA_HAI' then 'MUA '||round(greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0))||' kg + gom phụ phẩm ruộng'
         else 'MUA '||round(greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0))||' kg (PO, lead '||coalesce(m.lead_days,0)||' ngày)' end
  from need n join products pr on pr.sku=n.sku left join sku_crop_map m on m.sku=n.sku left join crops cr on cr.code=m.crop_code left join st on st.sku=n.sku left join po on po.sku=n.sku left join hv on hv.sku=n.sku left join land on land.sku=n.sku
  order by short desc; end $$;
grant execute on function plan_supply(text,text) to app_user;
-- 6) BAN HÀNH kế hoạch: lưu bản chốt (plan_lines) + việc cho từng phòng + thông báo + production_plans D5 + event plan.published
create table if not exists plan_lines(id bigserial primary key, scenario_id text not null references plan_scenarios, farm_id text not null, sku text, sku_name text, source text, crop_code text, demand_kg numeric, per_day_kg numeric, stock_kg numeric, po_kg numeric, harvest_expected_kg numeric, shortage_kg numeric, ha_needed numeric, ha_current numeric, ha_gap numeric, dept text, action text, created_at timestamptz default now());
alter table plan_lines enable row level security; drop policy if exists p_all on plan_lines; create policy p_all on plan_lines for all using (can_see_farm(farm_id)) with check (true); grant select, insert on plan_lines to app_user; grant usage on sequence plan_lines_id_seq to app_user;
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values ('plan.published','Ban kế hoạch ban hành kế hoạch cung–cầu (thức ăn/nguyên liệu/đất/mua)','BGD','{TT,CCU,D5,KTCN,TCKT}','plan_scenarios',true) on conflict (topic) do nothing;
create or replace function publish_plan(p_scenario text) returns int language plpgsql as $$
declare sc record; r record; n int := 0; feed_day numeric; begin
  select * into sc from plan_scenarios where id=p_scenario; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  delete from plan_lines where scenario_id=p_scenario;
  for r in select * from plan_supply(sc.farm_id, p_scenario) loop
    insert into plan_lines(scenario_id, farm_id, sku, sku_name, source, crop_code, demand_kg, per_day_kg, stock_kg, po_kg, harvest_expected_kg, shortage_kg, ha_needed, ha_current, ha_gap, dept, action)
    values (p_scenario, sc.farm_id, r.sku, r.sku_name, r.source, r.crop_code, r.demand_kg, r.per_day_kg, r.stock_kg, r.po_kg, r.harvest_expected_kg, r.shortage_kg, r.ha_needed, r.ha_current, r.ha_gap, r.dept, r.action);
    if r.shortage_kg > 0 then
      if r.source='TRONG' and coalesce(r.ha_gap,0) > 0 then
        insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority)
        values (gen_random_uuid(), sc.farm_id, 'KE_HOACH_TRONG', 'KH '||sc.name||': trồng thêm '||r.ha_gap||' ha '||coalesce(r.crop_code,'')||' cho '||r.sku_name, r.action||' — nhu cầu '||r.demand_kg||' kg/'||sc.horizon_days||' ngày, thiếu '||r.shortage_kg||' kg', now()+interval '7 days', 'tech_head', 'sku', r.sku, 'MO', 'PLAN', 2); n := n+1;
      end if;
      if r.source in ('MUA','CA_HAI') or (r.source='TRONG' and r.lead_days > 30) then
        insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority)
        values (gen_random_uuid(), sc.farm_id, 'KE_HOACH_MUA', 'KH '||sc.name||': mua bù '||r.shortage_kg||' kg '||r.sku_name, r.action||' — tồn '||r.stock_kg||', PO về '||r.po_kg||', thu hoạch DK '||r.harvest_expected_kg, now()+interval '5 days', 'accountant', 'sku', r.sku, 'MO', 'PLAN', 2); n := n+1;
      end if;
    end if;
  end loop;
  -- D5: kế hoạch sản xuất TMR/viên theo ngày (kg/ngày × 7) cho tuần tới
  for r in select fd.recipe_id, sum(fd.kg_per_day) as kgd from plan_feed_demand(sc.farm_id, p_scenario) fd where fd.recipe_id is not null group by fd.recipe_id loop
    insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority)
    values (gen_random_uuid(), sc.farm_id, 'KE_HOACH_SX', 'KH '||sc.name||': D5 sản xuất '||round(r.kgd)||' kg/ngày công thức '||r.recipe_id, 'Tuần tới '||round(r.kgd*7)||' kg; kiểm hào ủ/nguyên liệu theo MRP', now()+interval '2 days', 'team_lead', 'recipe', r.recipe_id, 'MO', 'PLAN', 2); n := n+1;
  end loop;
  update plan_scenarios set status='BAN_HANH', published_at=now(), published_by=app_staff() where id=p_scenario;
  perform publish_event(sc.farm_id, 'plan.published', jsonb_build_object('scenario_id', p_scenario, 'name', sc.name, 'horizon_days', sc.horizon_days, 'tasks', n));
  return n; end $$;
grant execute on function publish_plan(text) to app_user;
do $$ declare t text; begin
  foreach t in array array['plan_scenarios','sku_crop_map','class_recipes'] loop
    execute format('drop trigger if exists %s_audit on %I', t, t);
    execute format('create trigger %s_audit after insert or update or delete on %I for each row execute function itran_audit()', t, t);
  end loop; end $$;
-- kịch bản mẫu theo yêu cầu chủ: 100 bò
insert into plan_scenarios(id, farm_id, name, horizon_days, herd, safety_pct, note) values
 ('F01-KB-100BO','F01','Kịch bản 100 bò (60 vỗ béo + 30 cái SS + 10 bê) 180 ngày',180,'[{"class_code":"BO-VO-BEO","head":60},{"class_code":"BO-CAI-SS","head":30},{"class_code":"BO-BE","head":10}]',10,'Ví dụ: chỉnh đầu con/hạng rồi Tính lại → Ban hành')
on conflict do nothing;
